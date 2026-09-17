import Foundation
import KomgaAPI

/// Port of `snd.komelia.offline.api.OfflineLibraryApi`.
public struct OfflineLibraryApi: KomgaLibraryApi {
    private let store: any OfflineDataStore
    private let actions: OfflineActions
    private let settings: any OfflineSettingsRepository

    public init(store: any OfflineDataStore, actions: OfflineActions, settings: any OfflineSettingsRepository) {
        self.store = store
        self.actions = actions
        self.settings = settings
    }

    /// Root user (or a user without server) sees every downloaded library, others only their server's.
    public func getLibraries() async throws -> [KomgaLibrary] {
        let userId = settings.userId
        return try await store.read { repos in
            let server = userId == OfflineUser.root ? nil : try repos.mediaServers.findByUserId(userId)
            let libraries = try server.map { try repos.libraries.findAllByMediaServer($0.id) } ?? repos.libraries.findAll()
            return libraries.map(\.library)
        }
    }

    public func getLibrary(_ libraryId: KomgaLibraryId) async throws -> KomgaLibrary {
        try await store.read { try $0.libraries.get(libraryId).library }
    }

    public func addOne(_ request: KomgaLibraryCreateRequest) async throws -> KomgaLibrary {
        throw KomgaAPIError.unsupported("Libraries cannot be created offline")
    }

    public func patchOne(_ libraryId: KomgaLibraryId, request: KomgaLibraryUpdateRequest) async throws {
        throw KomgaAPIError.unsupported("Libraries cannot be edited offline")
    }

    /// Removes the downloaded copy of the library.
    public func deleteOne(_ libraryId: KomgaLibraryId) async throws {
        try await actions.libraryDelete.execute(libraryId)
    }

    public func scan(_ libraryId: KomgaLibraryId, deep: Bool) async throws {
        throw KomgaAPIError.unsupported("Library scan is not available offline")
    }

    public func analyze(_ libraryId: KomgaLibraryId) async throws {
        throw KomgaAPIError.unsupported("Library analysis is not available offline")
    }

    public func refreshMetadata(_ libraryId: KomgaLibraryId) async throws {
        throw KomgaAPIError.unsupported("Metadata refresh is not available offline")
    }

    public func emptyTrash(_ libraryId: KomgaLibraryId) async throws {
        throw KomgaAPIError.unsupported("Empty trash is not available offline")
    }
}

/// Port of `snd.komelia.offline.api.OfflineUserApi` — the offline user is whoever `OfflineSettings.userId` names.
public struct OfflineUserApi: KomgaUserApi {
    private let store: any OfflineDataStore
    private let settings: any OfflineSettingsRepository

    public init(store: any OfflineDataStore, settings: any OfflineSettingsRepository) {
        self.store = store
        self.settings = settings
    }

    public func logout() async throws {}

    public func getMe() async throws -> KomgaUser {
        let userId = settings.userId
        return try await store.read { try $0.users.get(userId).toKomgaUser() }
    }

    public func getMe(username: String, password: String, rememberMe: Bool) async throws -> KomgaUser {
        try await getMe()
    }

    public func updateMyPassword(_ newPassword: String) async throws {
        throw KomgaAPIError.unsupported("Password change is not available offline")
    }

    public func getAllUsers() async throws -> [KomgaUser] { [try await getMe()] }

    public func addUser(_ user: KomgaUserCreateRequest) async throws -> KomgaUser {
        throw KomgaAPIError.unsupported("User management is not available offline")
    }

    public func deleteUser(_ userId: KomgaUserId) async throws {
        throw KomgaAPIError.unsupported("User management is not available offline")
    }

    public func updateUser(_ userId: KomgaUserId, request: KomgaUserUpdateRequest) async throws {
        throw KomgaAPIError.unsupported("User management is not available offline")
    }

    public func updatePassword(_ userId: KomgaUserId, password: String) async throws {
        throw KomgaAPIError.unsupported("User management is not available offline")
    }

    public func getMeAuthenticationActivity(pageRequest: KomgaPageRequest?, unpaged: Bool) async throws
        -> Page<KomgaAuthenticationActivity>
    { .empty() }

    public func getAuthenticationActivity(pageRequest: KomgaPageRequest?, unpaged: Bool) async throws
        -> Page<KomgaAuthenticationActivity>
    { .empty() }

    public func getLatestAuthenticationActivityForUser(_ userId: KomgaUserId) async throws
        -> KomgaAuthenticationActivity?
    { nil }
}

/// Port of `snd.komelia.offline.api.OfflineReferentialApi`.
public struct OfflineReferentialApi: KomgaReferentialApi {
    private let store: any OfflineDataStore

    public init(store: any OfflineDataStore) { self.store = store }

    public func getAuthors(
        search: String?, role: String?, libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?,
        seriesId: KomgaSeriesId?, readListId: KomgaReadListId?, pageRequest: KomgaPageRequest?
    ) async throws -> Page<KomgaAuthor> {
        // Collections / read lists are not stored offline → no authors.
        if libraryIds.isEmpty, seriesId == nil, collectionId != nil || readListId != nil { return .empty() }
        return try await store.read {
            try $0.referential.authors(
                search: search, role: role, libraryIds: libraryIds, seriesId: libraryIds.isEmpty ? seriesId : nil,
                pageRequest: pageRequest ?? KomgaPageRequest())
        }
    }

    public func getAuthorsNames(search: String?) async throws -> [String] {
        try await store.read { try $0.referential.authorNames(search: search ?? "") }
    }

    public func getAuthorsRoles() async throws -> [String] {
        try await store.read { try $0.referential.authorRoles() }
    }

    public func getGenres(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws -> [String] {
        if libraryIds.isEmpty, collectionId != nil { return [] }
        return try await store.read { try $0.referential.genres(libraryIds: libraryIds) }
    }

    public func getSharingLabels(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws
        -> [String]
    {
        if libraryIds.isEmpty, collectionId != nil { return [] }
        return try await store.read { try $0.referential.sharingLabels(libraryIds: libraryIds) }
    }

    public func getTags(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws -> [String] {
        if libraryIds.isEmpty, collectionId != nil { return [] }
        return try await store.read { try $0.referential.seriesAndBookTags(libraryIds: libraryIds) }
    }

    public func getBookTags(seriesId: KomgaSeriesId?, readListId: KomgaReadListId?, libraryIds: [KomgaLibraryId])
        async throws -> [String]
    {
        if seriesId == nil, readListId != nil { return [] }
        // Kotlin ignored `libraryIds` here (both branches called findAllBookTags()); the filter is applied now.
        return try await store.read { try $0.referential.bookTags(seriesId: seriesId, libraryIds: libraryIds) }
    }

    public func getSeriesTags(libraryId: KomgaLibraryId?, collectionId: KomgaCollectionId?) async throws -> [String] {
        if libraryId == nil, collectionId != nil { return [] }
        return try await store.read { try $0.referential.seriesTags(libraryId: libraryId) }
    }

    public func getLanguages(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws -> [String] {
        if libraryIds.isEmpty, collectionId != nil { return [] }
        return try await store.read { try $0.referential.languages(libraryIds: libraryIds) }
    }

    public func getPublishers(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws
        -> [String]
    {
        if libraryIds.isEmpty, collectionId != nil { return [] }
        return try await store.read { try $0.referential.publishers(libraryIds: libraryIds) }
    }

    /// Kotlin maps `null` to `"None"`.
    public func getAgeRatings(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws
        -> [String]
    {
        if libraryIds.isEmpty, collectionId != nil { return [] }
        let ratings = try await store.read { try $0.referential.ageRatings(libraryIds: libraryIds) }
        return ratings.map { $0.map(String.init) ?? "None" }
    }

    /// Release years, like the server endpoint.
    public func getSeriesReleaseDates(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws
        -> [String]
    {
        if libraryIds.isEmpty, collectionId != nil { return [] }
        let dates = try await store.read { try $0.referential.seriesReleaseDates(libraryIds: libraryIds) }
        var seen = Set<Int>()
        return dates.map(\.year).filter { seen.insert($0).inserted }.map(String.init)
    }
}
