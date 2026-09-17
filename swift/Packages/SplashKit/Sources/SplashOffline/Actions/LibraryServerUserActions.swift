import Foundation
import KomgaAPI

// Ports of .../library/actions, .../server/actions and .../user/actions. Not ported (Kotlin `TODO()` / no-op):
// LibraryAddAction, LibraryAnalyzeAction, LibraryEmptyTrashAction, LibraryPatchAction,
// LibraryRefreshMetadataAction, LibraryScanAction.

/// Port of `LibraryKomgaImportAction`.
public struct LibraryKomgaImportAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(_ library: KomgaLibrary, serverId: OfflineMediaServerId) async throws {
        do {
            try await env.store.write { repos in
                let server = try repos.mediaServers.get(serverId)
                try repos.libraries.save(library.toOfflineLibrary(serverId: server.id))
                try repos.logJournal.save(.info("Library updated '\(library.name)'"))
            }
        } catch {
            await env.store.log(.error("Library update error '\(library.name)'", error))
            throw error
        }
    }
}

/// Port of `LibraryDeleteAction`.
public struct LibraryDeleteAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(_ libraryId: KomgaLibraryId) async throws {
        let outcome = try await env.store.write { try Self.delete(libraryId, in: $0) }
        try await outcome.publish(events: env.events, taskEmitter: env.taskEmitter)
    }

    static func delete(_ libraryId: KomgaLibraryId, in repos: any OfflineRepositories) throws -> DeletionOutcome {
        var outcome = try SeriesDeleteManyAction.delete(try repos.series.findAllByLibraryId(libraryId), in: repos)
        // Books whose series row is missing (should not happen, but the FK would block the library delete).
        let orphans = try repos.books.findIn(try repos.books.findAllIdsByLibraryId(libraryId))
        outcome.merge(try BookDeleteManyAction.delete(orphans, in: repos))
        try repos.libraries.delete(libraryId)
        outcome.events.append(OfflineEvents.libraryDeleted(libraryId))
        return outcome
    }
}

/// Port of `MediaServerSaveAction` — find-or-create by URL.
public struct MediaServerSaveAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(serverUrl: String) async throws -> OfflineMediaServer {
        try await env.store.write { repos in
            if let existing = try repos.mediaServers.findByUrl(serverUrl) { return existing }
            let server = OfflineMediaServer(url: serverUrl)
            try repos.mediaServers.save(server)
            return server
        }
    }
}

/// Port of `MediaServerDeleteAction`.
public struct MediaServerDeleteAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(_ serverId: OfflineMediaServerId) async throws {
        // SETTINGS.user_id / server_id reference these rows, so the settings are reset *before* deleting them
        // (Kotlin did it inside the same transaction; the settings store uses its own write here).
        let serverUserIds = try await env.store.read { repos in try repos.users.findAllByServer(serverId).map(\.id) }
        if serverUserIds.contains(env.settings.userId) { try await env.settings.putUserId(OfflineUser.root) }
        if env.settings.serverId == serverId { try await env.settings.putServerId(nil) }

        let outcome = try await env.store.write { repos -> DeletionOutcome in
            guard try repos.mediaServers.find(serverId) != nil else { return DeletionOutcome() }
            var outcome = DeletionOutcome()
            for library in try repos.libraries.findAllByMediaServer(serverId) {
                outcome.merge(try LibraryDeleteAction.delete(library.id, in: repos))
            }
            for user in try repos.users.findAllByServer(serverId) {
                outcome.merge(try UserDeleteAction.delete(user.id, in: repos))
            }
            try repos.mediaServers.delete(serverId)
            return outcome
        }
        try await outcome.publish(events: env.events, taskEmitter: env.taskEmitter)
    }
}

/// Port of `UserKomgaImportAction`.
public struct UserKomgaImportAction: Sendable {
    let env: OfflineActionEnvironment

    @discardableResult
    public func execute(_ user: KomgaUser, serverId: OfflineMediaServerId) async throws -> OfflineUser {
        let offlineUser = user.toOfflineUser(serverId: serverId)
        try await env.store.write { try $0.users.save(offlineUser) }
        return offlineUser
    }
}

/// Port of `UserDeleteAction`.
public struct UserDeleteAction: Sendable {
    let env: OfflineActionEnvironment

    public func execute(_ userId: KomgaUserId) async throws {
        // Reset first: SETTINGS.user_id references the USER row.
        if env.settings.userId == userId { try await env.settings.putUserId(OfflineUser.root) }
        let outcome = try await env.store.write { try Self.delete(userId, in: $0) }
        try await outcome.publish(events: env.events, taskEmitter: env.taskEmitter)
    }

    static func delete(_ userId: KomgaUserId, in repos: any OfflineRepositories) throws -> DeletionOutcome {
        guard try repos.users.find(userId) != nil else { return DeletionOutcome() }
        try repos.readProgress.deleteByUserId(userId)
        try repos.users.delete(userId)
        return DeletionOutcome(events: [OfflineEvents.sessionExpired(userId)])
    }
}
