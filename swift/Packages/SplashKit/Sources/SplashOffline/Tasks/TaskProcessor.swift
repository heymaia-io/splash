import Foundation
import KomgaAPI

/// Port of `snd.komelia.offline.tasks.TaskHandler` (strategy per `TaskData` case).
public struct TaskHandler: Sendable {
    private let actions: OfflineActions
    private let tasksRepository: any OfflineTasksRepository
    private let downloadManager: any PlatformDownloadManager
    /// `komgaBookClient.getBookList(anyOfBooks { seriesId == … }, unpaged)` — injected so the fan-out does not
    /// depend on a concrete API (and is testable).
    private let seriesBookIds: @Sendable (KomgaSeriesId) async throws -> [KomgaBookId]

    public init(
        actions: OfflineActions, tasksRepository: any OfflineTasksRepository,
        downloadManager: any PlatformDownloadManager,
        seriesBookIds: @escaping @Sendable (KomgaSeriesId) async throws -> [KomgaBookId]
    ) {
        self.actions = actions
        self.tasksRepository = tasksRepository
        self.downloadManager = downloadManager
        self.seriesBookIds = seriesBookIds
    }

    public func handle(_ entry: TaskEntry) async throws {
        let store = actions.environment.store
        switch entry.task {
        case .aggregateSeriesMetadata(let seriesId):
            try await actions.seriesAggregateBookMetadata.execute(seriesId)
        case .deleteBook(let bookId):
            guard let book = try await store.read({ try $0.books.find(bookId) }) else { return }
            if book.oneshot {
                try await actions.seriesDelete.execute(book.seriesId)
            } else {
                try await actions.bookDelete.execute(book.id)
            }
        case .deleteBookFiles(let path):
            try await actions.bookDeleteFiles.execute(path)
        case .deleteSeries(let seriesId):
            guard try await store.read({ try $0.series.find(seriesId) }) != nil else { return }
            try await actions.seriesDelete.execute(seriesId)
        case .deleteLibrary(let libraryId):
            try await actions.libraryDelete.execute(libraryId)
        case .downloadBook(let bookId):
            try await downloadManager.launchBookDownload(bookId)
        case .downloadSeries(let seriesId):
            let bookIds = try await seriesBookIds(seriesId)
            try await actions.environment.taskEmitter.downloadBooks(bookIds, priority: entry.priority)
        case .downloadBookCancel(let bookId):
            // The emitter already dequeued a pending download; also cover one re-queued since then.
            _ = try await tasksRepository.deletePending(uniqueName: TaskData.downloadBook(bookId).uniqueName)
            await downloadManager.cancelBookDownload(bookId)
        }
    }
}

/// Port of `snd.komelia.offline.tasks.TaskProcessor`: claims queued tasks and runs each in its own child task.
/// Tasks are deleted when they finish or fail (errors go to the log journal), exactly like Kotlin; tasks left
/// RUNNING by a killed process are reset to NEW on `start()`, which is what makes downloads resumable.
public actor TaskProcessor {
    private let tasksRepository: any OfflineTasksRepository
    private let handler: TaskHandler
    private let taskAdded: AsyncBroadcaster<Void>
    private let store: any OfflineDataStore

    private var jobs: [Int: Task<Void, Never>] = [:]
    private var jobCounter = 0
    private var listener: Task<Void, Never>?
    private var draining = false
    private var drainRequested = false
    private var idleWaiters: [CheckedContinuation<Void, Never>] = []

    public init(
        tasksRepository: any OfflineTasksRepository, handler: TaskHandler, taskEmitter: OfflineTaskEmitter,
        store: any OfflineDataStore
    ) {
        self.tasksRepository = tasksRepository
        self.handler = handler
        self.taskAdded = taskEmitter.taskAdded
        self.store = store
    }

    private var starting = false

    /// `initialize()` — idempotent. Resets tasks left RUNNING by a previous process *before* anything is claimed,
    /// then drains the queue and keeps listening for new tasks.
    public func start() async {
        guard listener == nil, !starting else { return }
        starting = true
        defer { starting = false }
        let wakeUps = taskAdded.subscribe()  // subscribe first: submissions during the reset are not lost
        do {
            let reset = try await tasksRepository.resetAllRunning()
            if reset > 0 { await store.log(.info("Reset \(reset) tasks that were not finished")) }
        } catch {
            await store.log(.error("Task queue reset error", error))
        }
        listener = Task { [weak self] in
            for await _ in wakeUps {
                guard let self else { return }
                await self.drain()
            }
        }
        await drain()
    }

    /// Stops listening and cancels running tasks (their rows stay RUNNING and are reset on the next start).
    public func stop() {
        listener?.cancel()
        listener = nil
        for job in jobs.values { job.cancel() }
        jobs.removeAll()
        resumeIdleWaitersIfIdle()
    }

    /// Suspends until the queue is drained and no task is running (tests / diagnostics).
    public func waitUntilIdle() async {
        await drain()
        if jobs.isEmpty && !draining { return }
        await withCheckedContinuation { idleWaiters.append($0) }
    }

    private func drain() async {
        guard listener != nil else { return }  // stopped
        if draining {
            drainRequested = true
            return
        }
        draining = true
        defer {
            draining = false
            resumeIdleWaitersIfIdle()
        }
        repeat {
            drainRequested = false
            while let entry = await claimNext() {
                launch(entry)
            }
        } while drainRequested
    }

    private func claimNext() async -> TaskEntry? {
        do {
            return try await tasksRepository.takeNew()
        } catch {
            await store.log(.error("Task queue read error", error))
            return nil
        }
    }

    private func launch(_ entry: TaskEntry) {
        jobCounter += 1
        let id = jobCounter
        let handler = handler
        let repository = tasksRepository
        let store = store
        jobs[id] = Task { [weak self] in
            do {
                try await handler.handle(entry)
            } catch where Task.isCancelled {
                // Processor stopped: leave the row RUNNING so the next start() re-queues it.
                await self?.finish(id)
                return
            } catch {
                await store.log(.error("Task processing error \(entry.uniqueName)", error))
            }
            try? await repository.delete(uniqueName: entry.uniqueName)
            await self?.finish(id)
        }
    }

    private func finish(_ id: Int) async {
        jobs.removeValue(forKey: id)
        await drain()
    }

    private func resumeIdleWaitersIfIdle() {
        guard jobs.isEmpty, !draining else { return }
        let waiters = idleWaiters
        idleWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }
}
