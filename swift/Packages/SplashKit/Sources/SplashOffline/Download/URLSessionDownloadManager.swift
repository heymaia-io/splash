import Foundation
import SplashCore
import KomgaAPI
import Synchronization

/// Configuration of `URLSessionDownloadManager`.
public struct DownloadManagerConfiguration: Sendable {
    /// Downloads transferring at the same time (Kotlin desktop: `Semaphore(4)`; iOS default 3).
    public var maxConcurrentDownloads: Int
    /// Evaluated for every request, so a "Wi-Fi only" setting applies without recreating the session.
    public var allowsCellularAccess: @Sendable () -> Bool
    /// Builds the session configuration once, when the manager is created.
    public var makeSessionConfiguration: @Sendable () -> URLSessionConfiguration
    /// Minimum interval between progress events per book.
    public var progressEventInterval: Duration
    /// Minimum interval between progress writes to `BOOK_DOWNLOAD` per book.
    public var progressPersistInterval: Duration

    public init(
        maxConcurrentDownloads: Int = 3,
        allowsCellularAccess: @escaping @Sendable () -> Bool = { true },
        progressEventInterval: Duration = .milliseconds(250),
        progressPersistInterval: Duration = .seconds(2),
        makeSessionConfiguration: @escaping @Sendable () -> URLSessionConfiguration = {
            DownloadManagerConfiguration.withoutCookieHandling(.default)
        }
    ) {
        self.maxConcurrentDownloads = max(1, maxConcurrentDownloads)
        self.allowsCellularAccess = allowsCellularAccess
        self.progressEventInterval = progressEventInterval
        self.progressPersistInterval = progressPersistInterval
        self.makeSessionConfiguration = makeSessionConfiguration
    }

    /// Background session: transfers continue while the app is suspended and relaunch it on completion.
    /// Create exactly ONE manager per identifier per process.
    public static func background(
        identifier: String, maxConcurrentDownloads: Int = 3,
        allowsCellularAccess: @escaping @Sendable () -> Bool = { true }
    ) -> DownloadManagerConfiguration {
        DownloadManagerConfiguration(
            maxConcurrentDownloads: maxConcurrentDownloads, allowsCellularAccess: allowsCellularAccess
        ) {
            let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
            configuration.isDiscretionary = false
            configuration.sessionSendsLaunchEvents = true
            configuration.httpMaximumConnectionsPerHost = max(1, maxConcurrentDownloads)
            return withoutCookieHandling(configuration)
        }
    }

    /// Authentication travels in the request's explicit `Cookie` / `X-API-Key` headers (built by `KomgaHTTPClient`),
    /// so Foundation's cookie storage must not interfere (same policy as `KomgaHTTPClient.makeSession`).
    public static func withoutCookieHandling(_ configuration: URLSessionConfiguration) -> URLSessionConfiguration {
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        return configuration
    }
}

/// `PlatformDownloadManager` over `URLSession` download tasks (port of `DesktopDownloadManager` /
/// `AndroidDownloadManager` + the transfer half of `BookDownloadService`).
///
/// - The `URLRequest` comes from the injected provider (the app passes `RemoteBookApi.bookFileRequest`).
/// - Delegate-based, so it works with `.background(withIdentifier:)`: the finished temp file is moved
///   synchronously inside `didFinishDownloadingTo` to `<destination>.download`, verified, then atomically moved
///   into place by `BookDownloadService.finish`.
/// - Komga ignores `Range`, so a failed transfer is not resumed: the partial file is dropped, the row becomes
///   FAILED with the error, and `OfflineDownloads.retry` re-queues it. [NUEVO: persisted state]
/// - Each task's `taskDescription` carries the book id + destination, so transfers finished while the app was not
///   running are picked up when the re-queued `DownloadBook` task relaunches.
public final class URLSessionDownloadManager: NSObject, PlatformDownloadManager, URLSessionDownloadDelegate,
    @unchecked Sendable
{
    public typealias RequestProvider = @Sendable (KomgaBookId) async throws -> URLRequest

    private struct TaskInfo: Codable {
        var bookId: String
        var storedPath: String
    }

    private struct Job {
        var download: BookDownload
        var storedPath: String?
        var task: URLSessionDownloadTask?
        var completion: CheckedContinuation<URL, any Error>?
        var pendingResult: Result<URL, any Error>?
        var waiters: [CheckedContinuation<Void, any Error>] = []
        var cancelled = false
        var holdsSlot = false
        var lastEvent: ContinuousClock.Instant = .now
        var lastPersist: ContinuousClock.Instant = .now
    }

    private struct State {
        var jobs: [KomgaBookId: Job] = [:]
        var activeTransfers = 0
        var slotWaiters: [(bookId: KomgaBookId, continuation: CheckedContinuation<Void, any Error>)] = []
        /// Transfers that finished while no job was waiting (background relaunch).
        var orphanResults: [KomgaBookId: Result<URL, any Error>] = [:]
        /// System tasks still running from a previous process.
        var liveTasks: [KomgaBookId: URLSessionDownloadTask] = [:]
        var stagedFiles: [Int: Result<URL, any Error>] = [:]
        /// Cancels that arrived while the download task was claimed but not launched yet.
        var earlyCancels: [KomgaBookId: ContinuousClock.Instant] = [:]
        var restored = false
        var restoreWaiters: [CheckedContinuation<Void, Never>] = []
        var backgroundCompletion: (@Sendable () -> Void)?
    }

    private let state = Mutex(State())
    private let service: BookDownloadService
    private let requestProvider: RequestProvider
    private let configuration: DownloadManagerConfiguration
    private let store: any OfflineDataStore
    private let fileLocator: OfflineFileLocator
    private let broadcaster = AsyncBroadcaster<DownloadEvent>()
    private let persistLock = AsyncSerialLock()
    private let delegateQueue: OperationQueue
    private var session: URLSession!  // set once in init

    public init(
        service: BookDownloadService, store: any OfflineDataStore, requestProvider: @escaping RequestProvider,
        configuration: DownloadManagerConfiguration = DownloadManagerConfiguration()
    ) {
        self.service = service
        self.store = store
        self.fileLocator = service.fileLocator
        self.requestProvider = requestProvider
        self.configuration = configuration
        delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.name = "komelia.downloads"
        super.init()
        session = URLSession(
            configuration: configuration.makeSessionConfiguration(), delegate: self, delegateQueue: delegateQueue)
        restoreSystemTasks()
    }

    /// Progress / completion / error events (`bookDownloadEvents` in Kotlin).
    public func events() -> AsyncStream<DownloadEvent> { broadcaster.subscribe() }

    /// Background session identifier, if any.
    public var sessionIdentifier: String? { session.configuration.identifier }

    /// Forward `application(_:handleEventsForBackgroundURLSession:completionHandler:)` here.
    public func handleEventsForBackgroundURLSession(
        identifier: String, completionHandler: @escaping @Sendable () -> Void
    ) {
        guard identifier == sessionIdentifier else { return }
        state.withLock { $0.backgroundCompletion = completionHandler }
    }

    /// Cancels every transfer and invalidates the session (tests / teardown).
    public func invalidate() {
        session.invalidateAndCancel()
    }

    // MARK: PlatformDownloadManager

    public func launchBookDownload(_ bookId: KomgaBookId) async throws {
        await waitUntilRestored()
        let now = ContinuousClock.now
        let (isNew, cancelledEarly) = state.withLock { state -> (Bool, Bool) in
            if let cancelledAt = state.earlyCancels.removeValue(forKey: bookId), now - cancelledAt < .seconds(2) {
                return (false, true)
            }
            guard state.jobs[bookId] == nil else { return (false, false) }
            state.jobs[bookId] = Job(download: BookDownload(bookId: bookId, status: .queued))
            return (true, false)
        }
        if cancelledEarly {
            broadcaster.emit(.bookDownloadCancelled(bookId))
            return
        }
        guard isNew else {
            try await joinExistingJob(bookId)  // Kotlin returned immediately; waiting keeps the task persisted
            return
        }

        var prepared: BookDownloadService.PreparedDownload?
        do {
            await persist(bookId) { $0.status = .queued; $0.error = nil; $0.completedBytes = 0 }
            try await acquireSlot(bookId)
            let ready = try await service.prepare(bookId)
            prepared = ready
            await persist(bookId) { download in
                download.status = .downloading
                download.totalBytes = ready.book.sizeBytes
                download.bookTitle = ready.book.metadata.title
                download.seriesId = ready.book.seriesId
            }
            let staged = try await transfer(bookId, prepared: ready)
            try await service.finish(ready, stagedFile: staged)
            await persist(bookId) { $0.status = .complete; $0.completedBytes = $0.totalBytes }
            await store.log(.info("Book downloaded \(ready.book.metadata.title)"))
            completeJob(bookId, error: nil) { self.broadcaster.emit(.bookDownloadCompleted($0)) }
        } catch {
            if let prepared { removeStagingFile(prepared.storedPath) }
            if isUserCancelled(bookId) {
                _ = try? await store.write { try $0.downloads.delete([bookId]) }
                completeJob(bookId, error: nil) { _ in self.broadcaster.emit(.bookDownloadCancelled(bookId)) }
                return
            }
            if Task.isCancelled {  // processor stopped: the task row is re-queued on the next start
                completeJob(bookId, error: CancellationError(), emit: nil)
                throw CancellationError()
            }
            let message = Self.describe(error)
            await persist(bookId) { $0.status = .failed; $0.error = message }
            await store.log(.error("Book download error \(prepared?.book.metadata.title ?? bookId.rawValue)", error))
            completeJob(bookId, error: error) { self.broadcaster.emit(.bookDownloadError($0)) }
            throw error
        }
    }

    public func cancelBookDownload(_ bookId: KomgaBookId) async {
        let cancelled = state.withLock { state -> Bool in
            guard var job = state.jobs[bookId] else {
                // Not running here, but maybe a system task from a previous process, or a download task that was
                // claimed and is about to launch.
                state.liveTasks.removeValue(forKey: bookId)?.cancel()
                state.orphanResults.removeValue(forKey: bookId)
                state.earlyCancels[bookId] = .now
                return false
            }
            job.cancelled = true
            job.task?.cancel()
            if let index = state.slotWaiters.firstIndex(where: { $0.bookId == bookId }) {
                state.slotWaiters.remove(at: index).continuation.resume(throwing: CancellationError())
            }
            // With a live task, `didCompleteWithError` resumes the waiting transfer; without one, resume it now.
            if job.task == nil, let completion = job.completion {
                job.completion = nil
                completion.resume(throwing: CancellationError())
            }
            state.jobs[bookId] = job
            return true
        }
        if !cancelled {
            _ = try? await store.write { try $0.downloads.delete([bookId]) }
            broadcaster.emit(.bookDownloadCancelled(bookId))
        }
    }

    // MARK: Job bookkeeping

    private func joinExistingJob(_ bookId: KomgaBookId) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            state.withLock { state in
                if state.jobs[bookId] != nil {
                    state.jobs[bookId]!.waiters.append(continuation)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func isUserCancelled(_ bookId: KomgaBookId) -> Bool {
        state.withLock { $0.jobs[bookId]?.cancelled ?? false }
    }

    /// Removes the job, frees its slot, resumes joined callers and emits the final event with the last state.
    private func completeJob(
        _ bookId: KomgaBookId, error: (any Error)?, emit: (@Sendable (BookDownload) -> Void)?
    ) {
        let download = state.withLock { state -> BookDownload? in
            guard let job = state.jobs.removeValue(forKey: bookId) else { return nil }
            state.orphanResults.removeValue(forKey: bookId)  // never reuse a stale transfer for a later download
            if job.holdsSlot { releaseSlot(&state) }
            for waiter in job.waiters {
                if let error { waiter.resume(throwing: error) } else { waiter.resume() }
            }
            return job.download
        }
        if let download { emit?(download) }
    }

    private func acquireSlot(_ bookId: KomgaBookId) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                state.withLock { state in
                    guard let job = state.jobs[bookId], !job.cancelled else {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    if state.activeTransfers < configuration.maxConcurrentDownloads {
                        state.activeTransfers += 1
                        state.jobs[bookId]!.holdsSlot = true
                        continuation.resume()
                    } else {
                        state.slotWaiters.append((bookId, continuation))
                    }
                }
            }
        } onCancel: {
            state.withLock { state in
                if let index = state.slotWaiters.firstIndex(where: { $0.bookId == bookId }) {
                    state.slotWaiters.remove(at: index).continuation.resume(throwing: CancellationError())
                }
            }
        }
    }

    /// Hands the freed slot to the next waiter (or decrements the counter).
    private func releaseSlot(_ state: inout State) {
        while !state.slotWaiters.isEmpty {
            let next = state.slotWaiters.removeFirst()
            guard state.jobs[next.bookId] != nil else { continue }
            state.jobs[next.bookId]!.holdsSlot = true
            next.continuation.resume()
            return
        }
        state.activeTransfers -= 1
    }

    // MARK: Transfer

    private func transfer(_ bookId: KomgaBookId, prepared: BookDownloadService.PreparedDownload) async throws -> URL {
        if let orphan = state.withLock({ $0.orphanResults.removeValue(forKey: bookId) }) {
            return try orphan.get()
        }
        var request = try await requestProvider(bookId)
        request.allowsCellularAccess = configuration.allowsCellularAccess()
        let finalRequest = request
        let description = String(
            decoding: try JSONEncoder().encode(TaskInfo(bookId: bookId.rawValue, storedPath: prepared.storedPath)),
            as: UTF8.self)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, any Error>) in
                state.withLock { state in
                    guard var job = state.jobs[bookId], !job.cancelled else {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    job.storedPath = prepared.storedPath
                    if let pending = job.pendingResult {
                        job.pendingResult = nil
                        continuation.resume(with: pending)
                    } else if let live = state.liveTasks.removeValue(forKey: bookId) {
                        job.task = live  // still transferring from a previous process: attach
                        job.completion = continuation
                        if live.state == .suspended { live.resume() }
                    } else {
                        let task = session.downloadTask(with: finalRequest)
                        task.taskDescription = description
                        if prepared.book.sizeBytes > 0 { task.countOfBytesClientExpectsToReceive = prepared.book.sizeBytes }
                        job.task = task
                        job.completion = continuation
                        task.resume()
                    }
                    state.jobs[bookId] = job
                }
            }
        } onCancel: {
            state.withLock { $0.jobs[bookId]?.task?.cancel() }
        }
    }

    private func stagingURL(for storedPath: String) -> URL {
        let destination = fileLocator.fileURL(for: storedPath)
        return destination.deletingLastPathComponent().appending(path: destination.lastPathComponent + ".download")
    }

    private func removeStagingFile(_ storedPath: String) {
        try? FileManager.default.removeItem(at: stagingURL(for: storedPath))
    }

    // MARK: URLSessionDownloadDelegate

    public func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL
    ) {
        let result: Result<URL, any Error>
        if let status = (downloadTask.response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(status) {
            let body = (try? Data(contentsOf: location)) ?? Data()
            result = .failure(KomgaAPIError.httpStatus(code: status, body: body))
        } else if let info = Self.taskInfo(downloadTask) {
            // The temp file is deleted when this method returns: move it synchronously.
            let staging = stagingURL(for: info.storedPath)
            result = Result {
                try FileManager.default.createDirectory(
                    at: staging.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? FileManager.default.removeItem(at: staging)
                try FileManager.default.moveItem(at: location, to: staging)
                return staging
            }
        } else {
            result = .failure(OfflineError.invalidState("Download task without book information"))
        }
        let identifier = downloadTask.taskIdentifier
        state.withLock { $0.stagedFiles[identifier] = result }
    }

    public func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        guard let info = Self.taskInfo(downloadTask) else { return }
        let bookId = KomgaBookId(info.bookId)
        let now = ContinuousClock.now
        let update = state.withLock { state -> (event: BookDownload?, persist: Bool)? in
            guard var job = state.jobs[bookId] else { return nil }
            job.download.completedBytes = totalBytesWritten
            if totalBytesExpectedToWrite > 0 { job.download.totalBytes = totalBytesExpectedToWrite }
            job.download.status = .downloading
            var event: BookDownload?
            if now - job.lastEvent >= configuration.progressEventInterval || totalBytesWritten == totalBytesExpectedToWrite {
                job.lastEvent = now
                event = job.download
            }
            let persist = now - job.lastPersist >= configuration.progressPersistInterval
            if persist { job.lastPersist = now }
            state.jobs[bookId] = job
            return (event, persist)
        }
        guard let update else { return }
        if let event = update.event { broadcaster.emit(.bookDownloadProgress(event)) }
        if update.persist {
            let completed = totalBytesWritten
            let total = totalBytesExpectedToWrite
            Task { await self.persistProgress(bookId, completed: completed, total: total) }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let info = Self.taskInfo(task) else { return }
        let bookId = KomgaBookId(info.bookId)
        let identifier = task.taskIdentifier
        state.withLock { state in
            if state.liveTasks[bookId]?.taskIdentifier == identifier { state.liveTasks.removeValue(forKey: bookId) }
            let staged = state.stagedFiles.removeValue(forKey: identifier)
            let result: Result<URL, any Error> =
                if let error { .failure(error) } else { staged ?? .failure(KomgaAPIError.invalidResponse) }
            if case .failure = result, case .success(let url)? = staged { try? FileManager.default.removeItem(at: url) }

            // A job still preparing (no task yet) adopts the result of a transfer from a previous process.
            guard var job = state.jobs[bookId], job.task == nil || job.task?.taskIdentifier == identifier else {
                state.orphanResults[bookId] = result
                return
            }
            job.task = nil
            if job.cancelled {
                job.completion?.resume(throwing: CancellationError())
                job.completion = nil
            } else if let completion = job.completion {
                job.completion = nil
                completion.resume(with: result)
            } else {
                job.pendingResult = result
            }
            state.jobs[bookId] = job
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        guard let completion = state.withLock({ state -> (@Sendable () -> Void)? in
            defer { state.backgroundCompletion = nil }
            return state.backgroundCompletion
        }) else { return }
        DispatchQueue.main.async { completion() }
    }

    // MARK: Restore + persistence

    private func restoreSystemTasks() {
        session.getAllTasks { [weak self] tasks in
            guard let self else { return }
            let waiters = self.state.withLock { state -> [CheckedContinuation<Void, Never>] in
                for case let task as URLSessionDownloadTask in tasks {
                    guard let info = Self.taskInfo(task) else { continue }
                    if task.state == .running || task.state == .suspended {
                        state.liveTasks[KomgaBookId(info.bookId)] = task
                    }
                }
                state.restored = true
                defer { state.restoreWaiters.removeAll() }
                return state.restoreWaiters
            }
            for waiter in waiters { waiter.resume() }
        }
    }

    private func waitUntilRestored() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            state.withLock { state in
                if state.restored { continuation.resume() } else { state.restoreWaiters.append(continuation) }
            }
        }
    }

    /// Applies `change` to the in-memory state and writes it to `BOOK_DOWNLOAD` (serialized; emits a progress
    /// event for status changes).
    private func persist(_ bookId: KomgaBookId, _ change: @escaping @Sendable (inout BookDownload) -> Void) async {
        let snapshot = state.withLock { state -> BookDownload? in
            guard var job = state.jobs[bookId] else { return nil }
            change(&job.download)
            job.download.lastModifiedDate = Date()
            state.jobs[bookId] = job
            return job.download
        }
        guard let snapshot else { return }
        _ = try? await persistLock.run { [store] in
            try await store.write { repos in
                var row = snapshot
                if let existing = try repos.downloads.find(bookId) { row.createdDate = existing.createdDate }
                try repos.downloads.save(row)
            }
        }
        if snapshot.status == .queued || snapshot.status == .downloading {
            broadcaster.emit(.bookDownloadProgress(snapshot))
        }
    }

    private func persistProgress(_ bookId: KomgaBookId, completed: Int64, total: Int64) async {
        _ = try? await persistLock.run { [store] in
            try await store.write { repos in
                guard var row = try repos.downloads.find(bookId), row.status == .downloading else { return }
                row.completedBytes = completed
                if total > 0 { row.totalBytes = total }
                row.lastModifiedDate = Date()
                try repos.downloads.save(row)
            }
        }
    }

    private static func taskInfo(_ task: URLSessionTask) -> TaskInfo? {
        guard let description = task.taskDescription else { return nil }
        return try? JSONDecoder().decode(TaskInfo.self, from: Data(description.utf8))
    }

    static func describe(_ error: any Error) -> String {
        switch error {
        case let api as KomgaAPIError:
            if let code = api.statusCode { return "HTTP \(code)" }
            return String(describing: api)
        case let offline as OfflineError:
            return offline.description
        default:
            return (error as NSError).localizedDescription
        }
    }
}
