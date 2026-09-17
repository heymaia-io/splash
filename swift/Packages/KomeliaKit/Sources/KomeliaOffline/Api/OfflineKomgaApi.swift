import Foundation
import KomgaAPI

/// Port of `snd.komelia.offline.api.OfflineKomgaApi` — the SQLite-backed `KomgaApi` used in offline mode.
/// Screens use it through the same protocol as `RemoteKomgaApi` (never downcast).
public struct OfflineKomgaApi: KomgaApi {
    public let actuatorApi: any KomgaActuatorApi
    public let announcementsApi: any KomgaAnnouncementsApi
    public let bookApi: any KomgaBookApi
    public let collectionsApi: any KomgaCollectionsApi
    public let fileSystemApi: any KomgaFileSystemApi
    public let libraryApi: any KomgaLibraryApi
    public let readListApi: any KomgaReadListApi
    public let referentialApi: any KomgaReferentialApi
    public let seriesApi: any KomgaSeriesApi
    public let settingsApi: any KomgaSettingsApi
    public let tasksApi: any KomgaTaskApi
    public let userApi: any KomgaUserApi

    private let events: KomgaEventBroadcaster

    public init(
        store: any OfflineDataStore, actions: OfflineActions, extractors: BookContentExtractors,
        settings: any OfflineSettingsRepository, events: KomgaEventBroadcaster
    ) {
        actuatorApi = OfflineActuatorApi()
        announcementsApi = OfflineAnnouncementsApi()
        bookApi = OfflineBookApi(store: store, actions: actions, extractors: extractors, settings: settings)
        collectionsApi = OfflineCollectionsApi()
        fileSystemApi = OfflineFileSystemApi()
        libraryApi = OfflineLibraryApi(store: store, actions: actions, settings: settings)
        readListApi = OfflineReadListApi()
        referentialApi = OfflineReferentialApi(store: store)
        seriesApi = OfflineSeriesApi(store: store, actions: actions, settings: settings)
        settingsApi = OfflineSettingsApi()
        tasksApi = OfflineTaskApi()
        userApi = OfflineUserApi(store: store, settings: settings)
        self.events = events
    }

    /// Kotlin: `object : KomgaSSESession { incoming = komgaEvents }` — local action events stand in for SSE.
    public func createSSESession() async throws -> any KomgaSSESession {
        OfflineSSESession(stream: events.subscribe())
    }
}

/// Fake SSE session over the offline `KomgaEventBroadcaster`.
final class OfflineSSESession: KomgaSSESession {
    let incoming: AsyncStream<KomgaEvent>

    init(stream: AsyncStream<KomgaEvent>) { incoming = stream }

    /// Kotlin's `cancel()` is a no-op; the subscription ends when the consumer stops iterating.
    func cancel() {}
}

// MARK: - Trivial sub-APIs (OfflineActuatorApi.kt, OfflineAnnouncementsApi.kt, …)

public struct OfflineActuatorApi: KomgaActuatorApi {
    public init() {}
    public func shutdown() async throws {}
}

public struct OfflineAnnouncementsApi: KomgaAnnouncementsApi {
    public init() {}

    public func getAnnouncements() async throws -> KomgaJsonFeed {
        try WireValues.decode(KomgaJsonFeed.self, from: ["version": "", "title": ""])
    }

    public func markAnnouncementsRead(_ announcements: [KomgaAnnouncementId]) async throws {}
}

public struct OfflineFileSystemApi: KomgaFileSystemApi {
    public init() {}

    public func getDirectoryListing(_ request: DirectoryRequest) async throws -> DirectoryListing {
        try WireValues.decode(DirectoryListing.self, from: ["directories": [String]()])
    }
}

public struct OfflineSettingsApi: KomgaSettingsApi {
    public init() {}

    public func getSettings() async throws -> KomgaSettings {
        try WireValues.decode(
            KomgaSettings.self,
            from: [
                "deleteEmptyCollections": false, "deleteEmptyReadLists": false, "rememberMeDurationDays": 0,
                "thumbnailSize": KomgaThumbnailSize.default.rawValue, "taskPoolSize": 0,
                "serverPort": ["configurationSource": 0, "databaseSource": 0, "effectiveValue": 0],
                "serverContextPath": ["configurationSource": "", "databaseSource": "", "effectiveValue": ""],
            ])
    }

    public func updateSettings(_ request: KomgaSettingsUpdateRequest) async throws {
        throw KomgaAPIError.unsupported("Server settings are not available offline")
    }
}

public struct OfflineTaskApi: KomgaTaskApi {
    public init() {}
    public func emptyTaskQueue() async throws -> Int { 0 }
}

/// Collections are not downloaded: listings are empty, everything else is unsupported (Kotlin: `TODO()`).
public struct OfflineCollectionsApi: KomgaCollectionsApi {
    public init() {}

    private static func unsupported() -> KomgaAPIError { .unsupported("Collections are not available offline") }

    public func getAll(search: String?, libraryIds: [KomgaLibraryId]?, pageRequest: KomgaPageRequest?) async throws
        -> Page<KomgaCollection>
    { .empty() }
    public func getOne(_ id: KomgaCollectionId) async throws -> KomgaCollection { throw Self.unsupported() }
    public func addOne(_ request: KomgaCollectionCreateRequest) async throws -> KomgaCollection {
        throw Self.unsupported()
    }
    public func updateOne(_ id: KomgaCollectionId, request: KomgaCollectionUpdateRequest) async throws {
        throw Self.unsupported()
    }
    public func deleteOne(_ id: KomgaCollectionId) async throws { throw Self.unsupported() }
    public func getSeriesForCollection(
        _ id: KomgaCollectionId, query: KomgaCollectionQuery?, pageRequest: KomgaPageRequest?
    ) async throws -> Page<KomgaSeries> { .empty() }
    public func getDefaultThumbnail(_ collectionId: KomgaCollectionId) async throws -> Data? { nil }
    public func getThumbnail(_ collectionId: KomgaCollectionId, thumbnailId: KomgaThumbnailId) async throws -> Data {
        throw Self.unsupported()
    }
    public func getThumbnails(_ collectionId: KomgaCollectionId) async throws -> [KomgaCollectionThumbnail] { [] }
    public func uploadThumbnail(_ collectionId: KomgaCollectionId, file: Data, filename: String, selected: Bool)
        async throws -> KomgaCollectionThumbnail
    { throw Self.unsupported() }
    public func selectThumbnail(_ collectionId: KomgaCollectionId, thumbnailId: KomgaThumbnailId) async throws {
        throw Self.unsupported()
    }
    public func deleteThumbnail(_ collectionId: KomgaCollectionId, thumbnailId: KomgaThumbnailId) async throws {
        throw Self.unsupported()
    }
}

/// Read lists are not downloaded (Kotlin: empty pages / `TODO()`).
public struct OfflineReadListApi: KomgaReadListApi {
    public init() {}

    private static func unsupported() -> KomgaAPIError { .unsupported("Read lists are not available offline") }

    public func getAll(search: String?, libraryIds: [KomgaLibraryId]?, pageRequest: KomgaPageRequest?) async throws
        -> Page<KomgaReadList>
    { .empty() }
    public func getOne(_ id: KomgaReadListId) async throws -> KomgaReadList { throw Self.unsupported() }
    public func addOne(_ request: KomgaReadListCreateRequest) async throws -> KomgaReadList {
        throw Self.unsupported()
    }
    public func updateOne(_ id: KomgaReadListId, request: KomgaReadListUpdateRequest) async throws {
        throw Self.unsupported()
    }
    public func deleteOne(_ id: KomgaReadListId) async throws { throw Self.unsupported() }
    public func getBooksForReadList(_ id: KomgaReadListId, query: KomgaReadListQuery?, pageRequest: KomgaPageRequest?)
        async throws -> Page<KomeliaBook>
    { .empty() }
    public func getDefaultThumbnail(_ readListId: KomgaReadListId) async throws -> Data? { nil }
    public func getThumbnail(_ readListId: KomgaReadListId, thumbnailId: KomgaThumbnailId) async throws -> Data {
        throw Self.unsupported()
    }
    public func getThumbnails(_ readListId: KomgaReadListId) async throws -> [KomgaReadListThumbnail] { [] }
    public func uploadThumbnail(_ readListId: KomgaReadListId, file: Data, filename: String, selected: Bool)
        async throws -> KomgaReadListThumbnail
    { throw Self.unsupported() }
    public func selectThumbnail(_ readListId: KomgaReadListId, thumbnailId: KomgaThumbnailId) async throws {
        throw Self.unsupported()
    }
    public func deleteThumbnail(_ readListId: KomgaReadListId, thumbnailId: KomgaThumbnailId) async throws {
        throw Self.unsupported()
    }
    public func getBookSiblingNext(_ readListId: KomgaReadListId, bookId: KomgaBookId) async throws -> KomeliaBook? {
        nil
    }
    public func getBookSiblingPrevious(_ readListId: KomgaReadListId, bookId: KomgaBookId) async throws
        -> KomeliaBook?
    { nil }
}
