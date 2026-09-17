import Foundation
import KomgaAPI

/// Port of `snd.komelia.offline.sync.SyncManager`. Whenever an online user becomes available, it:
/// 1. pushes local read progress (`SyncReadProgressAction`, last-write-wins), then
/// 2. pulls metadata for everything downloaded (`syncDataToLocal`, at most every 6 h), walking
///    library → series → book. A 404 marks the affected books `remoteUnavailable`.
///
/// Fix: `dataSyncDate` is only advanced when the whole pull succeeded (Kotlin advanced it even after per-item
/// errors, so failed items waited 6 h for another chance). Non-HTTP errors (network down) abort the pull.
public actor SyncManager {
    public struct Result: Sendable, Equatable {
        public var progressPushed: Bool
        /// `nil` when the data pull was skipped (throttled or no server).
        public var dataSynced: Bool?
    }

    private let actions: OfflineActions
    private let dataSyncInterval: TimeInterval
    private var current: Task<Result?, Never>?

    public init(actions: OfflineActions, dataSyncInterval: TimeInterval = 6 * 60 * 60) {
        self.actions = actions
        self.dataSyncInterval = dataSyncInterval
    }

    private var settings: any OfflineSettingsRepository { actions.environment.settings }
    private var store: any OfflineDataStore { actions.environment.store }

    /// Hook for the composition root (Kotlin collected `authenticatedUser.filterNotNull()`). Runs are serialized.
    public func onlineUserChanged(_ user: KomgaUser?, api: any KomgaApi) {
        guard let user else { return }
        _ = enqueue(user: user, api: api, force: false)
    }

    /// Runs a sync now and waits for it. `force` ignores the 6 h throttle of the data pull.
    @discardableResult
    public func sync(user: KomgaUser, api: any KomgaApi, force: Bool = false) async -> Result? {
        await enqueue(user: user, api: api, force: force).value
    }

    /// Waits for the sync in flight, if any (tests).
    public func waitForCurrentSync() async { _ = await current?.value }

    private func enqueue(user: KomgaUser, api: any KomgaApi, force: Bool) -> Task<Result?, Never> {
        let previous = current
        let task = Task<Result?, Never> {
            _ = await previous?.value
            return await self.run(user: user, api: api, force: force)
        }
        current = task
        return task
    }

    private func run(user: KomgaUser, api: any KomgaApi, force: Bool) async -> Result? {
        let pushed: Bool
        do {
            pushed = try await actions.syncReadProgress.execute(user: user, api: api)
        } catch {
            await store.log(.error("Read progress sync error", error))
            pushed = false
        }
        do {
            let synced = try await syncDataToLocal(user: user, api: api, force: force)
            return Result(progressPushed: pushed, dataSynced: synced)
        } catch {
            await store.log(.error("Offline data sync error", error))
            return Result(progressPushed: pushed, dataSynced: false)
        }
    }

    /// Returns `nil` when skipped, otherwise whether every item synced.
    private func syncDataToLocal(user: KomgaUser, api: any KomgaApi, force: Bool) async throws -> Bool? {
        let syncStart = Date()
        if !force, let last = settings.dataSyncDate, last.addingTimeInterval(dataSyncInterval) > syncStart {
            return nil
        }
        guard let server = try await store.read({ try $0.mediaServers.findByUserId(user.id) }) else { return nil }

        if user.id != OfflineUser.root {
            try await actions.userImport.execute(user, serverId: server.id)
        }

        let source = RemoteImportSource(api: api)
        var succeeded = true
        let libraries = try await store.read { try $0.libraries.findAllByMediaServer(server.id) }
        for library in libraries {
            try Task.checkCancellation()
            do {
                let remoteLibrary = try await api.libraryApi.getLibrary(library.id)
                try await actions.libraryImport.execute(remoteLibrary, serverId: server.id)
                succeeded = try await syncSeries(of: library.id, userId: user.id, api: api, source: source) && succeeded
            } catch let error as KomgaAPIError where error.statusCode != nil {
                succeeded = false
                if error.isNotFound {
                    try await markUnavailable(try await store.read { try $0.books.findAllIdsByLibraryId(library.id) })
                }
                await store.log(.error("Library import error '\(library.name)'", error))
            }
        }

        if succeeded { try await settings.putDataSyncDate(syncStart) }
        return succeeded
    }

    private func syncSeries(
        of libraryId: KomgaLibraryId, userId: KomgaUserId, api: any KomgaApi, source: any OfflineImportSource
    ) async throws -> Bool {
        var succeeded = true
        for series in try await store.read({ try $0.series.findAllByLibraryId(libraryId) }) {
            try Task.checkCancellation()
            do {
                let remoteSeries = try await api.seriesApi.getOneSeries(series.id)
                try await actions.seriesImport.execute(remoteSeries, source: source)
                succeeded = try await syncBooks(of: series.id, userId: userId, api: api, source: source) && succeeded
            } catch let error as KomgaAPIError where error.statusCode != nil {
                succeeded = false
                if error.isNotFound {
                    try await markUnavailable(try await store.read { try $0.books.findAllIdsBySeriesId(series.id) })
                }
                await store.log(.error("Series import error '\(series.name)'", error))
            }
        }
        return succeeded
    }

    private func syncBooks(
        of seriesId: KomgaSeriesId, userId: KomgaUserId, api: any KomgaApi, source: any OfflineImportSource
    ) async throws -> Bool {
        var succeeded = true
        for localBook in try await store.read({ try $0.books.findAllNotDeleted(seriesId) }) {
            try Task.checkCancellation()
            do {
                let remoteBook = try await api.bookApi.getOne(localBook.id).book
                try await actions.bookImport.execute(
                    book: remoteBook, fileDownloadPath: localBook.fileDownloadPath, userId: userId,
                    localFileModifiedDate: localBook.localFileLastModified, source: source)
            } catch let error as KomgaAPIError where error.statusCode != nil {
                succeeded = false
                await store.log(.error("Book import error '\(localBook.name)'", error))
                if error.isNotFound { try await markUnavailable([localBook.id]) }
            }
        }
        return succeeded
    }

    private func markUnavailable(_ bookIds: [KomgaBookId]) async throws {
        for bookId in bookIds { try await actions.bookMarkRemoteDeleted.execute(bookId) }
    }
}
