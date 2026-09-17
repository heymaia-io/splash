import Foundation
import KomgaAPI

/// Port of `snd.komelia.offline.OfflineModule.initDependencies()` + `OfflineDependencies`: builds the offline
/// object graph from its storage (SplashDB) and online (KomgaRemote) seams. The app's composition root creates it
/// once and wires the hooks (see the integration notes).
public final class OfflineModule: Sendable {
    public let store: any OfflineDataStore
    public let settings: any OfflineSettingsRepository
    /// Offline `KomgaEvent`s (Kotlin `komgaEvents`). Also pass it to `RemoteKomgaApi(offlineEvents:)`.
    public let events: KomgaEventBroadcaster
    public let taskEmitter: OfflineTaskEmitter
    public let actions: OfflineActions
    public let api: OfflineKomgaApi
    public let bookStates: DatabaseOfflineBookStateProvider
    public let downloadManager: URLSessionDownloadManager
    public let downloads: OfflineDownloads
    public let taskProcessor: TaskProcessor
    public let syncManager: SyncManager
    public let fileLocator: OfflineFileLocator

    /// - Parameters:
    ///   - remote: current online API + server URL; throw when not logged in.
    ///   - bookFileRequest: authenticated `GET /api/v1/books/{id}/file` (`RemoteBookApi.bookFileRequest`).
    ///   - downloadRoot: the download folder; re-evaluated on every use (defaults to `settings.downloadDirectory`).
    public init(
        store: any OfflineDataStore,
        tasksRepository: any OfflineTasksRepository,
        settings: any OfflineSettingsRepository,
        events: KomgaEventBroadcaster = KomgaEventBroadcaster(),
        remote: @escaping @Sendable () async throws -> OfflineRemoteContext,
        bookFileRequest: @escaping URLSessionDownloadManager.RequestProvider,
        downloadConfiguration: DownloadManagerConfiguration = DownloadManagerConfiguration(),
        downloadRoot: (@Sendable () -> URL)? = nil,
        verifyDownloadHash: Bool = true
    ) {
        self.store = store
        self.settings = settings
        self.events = events
        fileLocator = OfflineFileLocator(downloadRoot: downloadRoot ?? { settings.downloadDirectory })
        taskEmitter = OfflineTaskEmitter(tasksRepository: tasksRepository)
        actions = OfflineActions(
            environment: OfflineActionEnvironment(
                store: store, events: events, taskEmitter: taskEmitter, settings: settings, fileLocator: fileLocator))
        api = OfflineKomgaApi(
            store: store, actions: actions, extractors: .standard(fileLocator: fileLocator), settings: settings,
            events: events)
        bookStates = DatabaseOfflineBookStateProvider(store: store)

        let service = BookDownloadService(actions: actions, remote: remote, verifyHash: verifyDownloadHash)
        downloadManager = URLSessionDownloadManager(
            service: service, store: store, requestProvider: bookFileRequest, configuration: downloadConfiguration)
        downloads = OfflineDownloads(
            store: store, taskEmitter: taskEmitter, fileLocator: fileLocator, manager: downloadManager)

        let handler = TaskHandler(
            actions: actions, tasksRepository: tasksRepository, downloadManager: downloadManager,
            seriesBookIds: { seriesId in
                let api = try await remote().api
                return try await api.bookApi.getBookList(
                    condition: .anyOfBooks(.seriesId(.isEqualTo(seriesId))),
                    pageRequest: KomgaPageRequest(unpaged: true)
                ).content.map(\.id)
            })
        taskProcessor = TaskProcessor(
            tasksRepository: tasksRepository, handler: handler, taskEmitter: taskEmitter, store: store)
        syncManager = SyncManager(actions: actions)
    }

    /// Starts the persistent task queue (Kotlin: `taskProcessor.initialize()`).
    public func start() async {
        await taskProcessor.start()
    }
}
