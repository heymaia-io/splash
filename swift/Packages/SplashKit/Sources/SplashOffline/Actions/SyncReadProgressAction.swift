import Foundation
import KomgaAPI

/// Port of `snd.komelia.offline.sync.actions.SyncReadProgressAction`: pushes local read progress that changed since
/// the last sync to the server, last-write-wins on `lastModified`.
///
/// Fix: `readProgressSyncDate` is only advanced when every push succeeded. Kotlin advanced it unconditionally,
/// so a progress that failed to sync once was never retried (the next run only looks at newer changes).
public struct SyncReadProgressAction: Sendable {
    let env: OfflineActionEnvironment

    /// Returns `true` when every candidate progress was handled without error.
    @discardableResult
    public func execute(user: KomgaUser, api: any KomgaApi) async throws -> Bool {
        let syncStart = Date()
        let lastSync = env.settings.readProgressSyncDate
        let candidates = try await env.store.read { repos -> [OfflineReadProgress] in
            guard let offlineUser = try repos.users.find(user.id),
                let server = try repos.mediaServers.findByUserId(user.id)
            else { return [] }
            if let lastSync {
                return try repos.readProgress.findAllModifiedAfter(lastSync, userId: offlineUser.id, serverId: server.id)
            }
            return try repos.readProgress.findAllByServer(userId: offlineUser.id, serverId: server.id)
        }

        var allSucceeded = true
        for progress in candidates {
            try Task.checkCancellation()
            if await !sync(progress, api: api) { allSucceeded = false }
        }
        if allSucceeded { try await env.settings.putReadProgressSyncDate(syncStart) }
        return allSucceeded
    }

    private func sync(_ local: OfflineReadProgress, api: any KomgaApi) async -> Bool {
        do {
            let remoteBook = try await api.bookApi.getOne(local.bookId)
            let remoteProgress = remoteBook.readProgress
            guard remoteProgress == nil || local.lastModifiedDate > remoteProgress!.lastModified else { return true }

            let media = remoteBook.media
            if media.mediaProfile == .divina || media.mediaProfile == .pdf || media.epubDivinaCompatible {
                try await pushDivina(remoteBook.id, local, api: api)
            } else if media.mediaProfile == .epub {
                try await pushEpub(remoteBook.id, local, api: api)
            }
            await env.store.log(.info("Read progress sync \(remoteBook.metadata.title)"))
            return true
        } catch {
            let title = (try? await env.store.read { try $0.bookMetadata.find(local.bookId)?.metadata.title }) ?? nil
            await env.store.log(
                .error("Read progress sync error for book \(title ?? "") id:\(local.bookId)", error))
            return false
        }
    }

    private func pushDivina(_ bookId: KomgaBookId, _ progress: OfflineReadProgress, api: any KomgaApi) async throws {
        let request =
            progress.completed
            ? KomgaBookReadProgressUpdateRequest(completed: true)
            : KomgaBookReadProgressUpdateRequest(page: progress.page)
        try await api.bookApi.markReadProgress(bookId, request: request)
    }

    private func pushEpub(_ bookId: KomgaBookId, _ progress: OfflineReadProgress, api: any KomgaApi) async throws {
        guard !progress.completed, let locator = progress.locator else {
            try await api.bookApi.markReadProgress(bookId, request: KomgaBookReadProgressUpdateRequest(completed: true))
            return
        }
        try await api.bookApi.updateReadiumProgression(
            bookId,
            progression: R2Progression(
                modified: progress.lastModifiedDate,
                device: R2Device(id: progress.deviceId, name: progress.deviceName), locator: locator))
    }
}

/// Port of `OfflineActions`. Kotlin looked actions up by `KClass` at runtime; a struct of typed properties gives
/// the same single registry with compile-time checking (one type per write operation is preserved).
public struct OfflineActions: Sendable {
    public let environment: OfflineActionEnvironment

    public let bookDelete: BookDeleteAction
    public let bookDeleteMany: BookDeleteManyAction
    public let bookDeleteFiles: BookDeleteFilesAction
    public let bookImport: BookKomgaImportAction
    public let bookMarkRemoteDeleted: BookMarkRemoteDeletedAction

    public let seriesImport: SeriesKomgaImportAction
    public let seriesDelete: SeriesDeleteAction
    public let seriesDeleteMany: SeriesDeleteManyAction
    public let seriesAggregateBookMetadata: SeriesAggregateBookMetadataAction

    public let libraryImport: LibraryKomgaImportAction
    public let libraryDelete: LibraryDeleteAction
    public let mediaServerSave: MediaServerSaveAction
    public let mediaServerDelete: MediaServerDeleteAction
    public let userImport: UserKomgaImportAction
    public let userDelete: UserDeleteAction

    public let progressCompleteForBook: ProgressCompleteForBookAction
    public let progressCompleteForSeries: ProgressCompleteForSeriesAction
    public let progressDeleteForBook: ProgressDeleteForBookAction
    public let progressDeleteForSeries: ProgressDeleteForSeriesAction
    public let progressMark: ProgressMarkAction
    public let progressMarkProgression: ProgressMarkProgressionAction

    public let syncReadProgress: SyncReadProgressAction

    public init(environment env: OfflineActionEnvironment) {
        environment = env
        bookDelete = BookDeleteAction(env: env)
        bookDeleteMany = BookDeleteManyAction(env: env)
        bookDeleteFiles = BookDeleteFilesAction(fileLocator: env.fileLocator)
        bookImport = BookKomgaImportAction(env: env)
        bookMarkRemoteDeleted = BookMarkRemoteDeletedAction(env: env)
        seriesImport = SeriesKomgaImportAction(env: env)
        seriesDelete = SeriesDeleteAction(env: env)
        seriesDeleteMany = SeriesDeleteManyAction(env: env)
        seriesAggregateBookMetadata = SeriesAggregateBookMetadataAction(env: env)
        libraryImport = LibraryKomgaImportAction(env: env)
        libraryDelete = LibraryDeleteAction(env: env)
        mediaServerSave = MediaServerSaveAction(env: env)
        mediaServerDelete = MediaServerDeleteAction(env: env)
        userImport = UserKomgaImportAction(env: env)
        userDelete = UserDeleteAction(env: env)
        progressCompleteForBook = ProgressCompleteForBookAction(env: env)
        progressCompleteForSeries = ProgressCompleteForSeriesAction(env: env)
        progressDeleteForBook = ProgressDeleteForBookAction(env: env)
        progressDeleteForSeries = ProgressDeleteForSeriesAction(env: env)
        progressMark = ProgressMarkAction(env: env)
        progressMarkProgression = ProgressMarkProgressionAction(env: env)
        syncReadProgress = SyncReadProgressAction(env: env)
    }
}
