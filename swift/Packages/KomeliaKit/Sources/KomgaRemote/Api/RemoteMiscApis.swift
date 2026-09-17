import Foundation
import KomgaAPI

/// Port of `RemoteLibraryApi.kt` + `HttpLibraryClient.kt`.
public struct RemoteLibraryApi: KomgaLibraryApi {
    let http: KomgaHTTPClient
    public init(http: KomgaHTTPClient) { self.http = http }

    public func getLibraries() async throws -> [KomgaLibrary] {
        try await http.fetch(http.request(.get, "api/v1/libraries"))
    }

    public func getLibrary(_ libraryId: KomgaLibraryId) async throws -> KomgaLibrary {
        try await http.fetch(http.request(.get, "api/v1/libraries/\(libraryId)"))
    }

    public func addOne(_ request: KomgaLibraryCreateRequest) async throws -> KomgaLibrary {
        try await http.fetch(http.jsonRequest(.post, "api/v1/libraries", body: request))
    }

    public func patchOne(_ libraryId: KomgaLibraryId, request: KomgaLibraryUpdateRequest) async throws {
        try await http.send(http.jsonRequest(.patch, "api/v1/libraries/\(libraryId)", body: request))
    }

    public func deleteOne(_ libraryId: KomgaLibraryId) async throws {
        try await http.send(http.request(.delete, "api/v1/libraries/\(libraryId)"))
    }

    public func scan(_ libraryId: KomgaLibraryId, deep: Bool) async throws {
        var query: [URLQueryItem] = []
        query.append("deep", deep)
        try await http.send(http.request(.post, "api/v1/libraries/\(libraryId)/scan", query: query))
    }

    public func analyze(_ libraryId: KomgaLibraryId) async throws {
        try await http.send(http.request(.post, "api/v1/libraries/\(libraryId)/analyze"))
    }

    public func refreshMetadata(_ libraryId: KomgaLibraryId) async throws {
        try await http.send(http.request(.post, "api/v1/libraries/\(libraryId)/metadata/refresh"))
    }

    public func emptyTrash(_ libraryId: KomgaLibraryId) async throws {
        try await http.send(http.request(.post, "api/v1/libraries/\(libraryId)/empty-trash"))
    }
}

/// Port of `RemoteReferentialApi.kt` + `HttpReferentialClient.kt`.
public struct RemoteReferentialApi: KomgaReferentialApi {
    let http: KomgaHTTPClient
    public init(http: KomgaHTTPClient) { self.http = http }

    public func getAuthors(
        search: String?, role: String?, libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?,
        seriesId: KomgaSeriesId?, readListId: KomgaReadListId?, pageRequest: KomgaPageRequest?
    ) async throws -> Page<KomgaAuthor> {
        var query: [URLQueryItem] = []
        query.append("search", search)
        query.append("role", role)
        query.appendList("library_id", libraryIds, transform: \.rawValue)
        query.append("collection_id", collectionId?.rawValue)
        query.append("series_id", seriesId?.rawValue)
        query.append("readlist_id", readListId?.rawValue)
        query.appendPage(pageRequest)
        return try await http.fetch(http.request(.get, "api/v2/authors", query: query))
    }

    public func getAuthorsNames(search: String?) async throws -> [String] {
        var query: [URLQueryItem] = []
        query.append("search", search)
        return try await http.fetch(http.request(.get, "api/v1/authors/names", query: query))
    }

    public func getAuthorsRoles() async throws -> [String] {
        try await http.fetch(http.request(.get, "api/v1/authors/roles"))
    }

    public func getGenres(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws -> [String] {
        try await scoped("api/v1/genres", libraryIds, collectionId)
    }

    public func getSharingLabels(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws
        -> [String]
    {
        try await scoped("api/v1/sharing-labels", libraryIds, collectionId)
    }

    public func getTags(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws -> [String] {
        try await scoped("api/v1/tags", libraryIds, collectionId)
    }

    public func getBookTags(seriesId: KomgaSeriesId?, readListId: KomgaReadListId?, libraryIds: [KomgaLibraryId])
        async throws -> [String]
    {
        var query: [URLQueryItem] = []
        query.append("series_id", seriesId?.rawValue)
        query.append("readlist_id", readListId?.rawValue)
        query.appendList("library_id", libraryIds, transform: \.rawValue)
        return try await http.fetch(http.request(.get, "api/v1/tags/book", query: query))
    }

    public func getSeriesTags(libraryId: KomgaLibraryId?, collectionId: KomgaCollectionId?) async throws -> [String] {
        var query: [URLQueryItem] = []
        query.append("library_id", libraryId?.rawValue)
        query.append("collection_id", collectionId?.rawValue)
        return try await http.fetch(http.request(.get, "api/v1/tags/series", query: query))
    }

    public func getLanguages(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws -> [String] {
        try await scoped("api/v1/languages", libraryIds, collectionId)
    }

    public func getPublishers(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws
        -> [String]
    {
        try await scoped("api/v1/publishers", libraryIds, collectionId)
    }

    public func getAgeRatings(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws
        -> [String]
    {
        try await scoped("api/v1/age-ratings", libraryIds, collectionId)
    }

    public func getSeriesReleaseDates(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws
        -> [String]
    {
        try await scoped("api/v1/series/release-dates", libraryIds, collectionId)
    }

    /// Shared shape of the `library_id` + `collection_id` referential endpoints.
    private func scoped(_ path: String, _ libraryIds: [KomgaLibraryId], _ collectionId: KomgaCollectionId?)
        async throws -> [String]
    {
        var query: [URLQueryItem] = []
        query.appendList("library_id", libraryIds, transform: \.rawValue)
        query.append("collection_id", collectionId?.rawValue)
        return try await http.fetch(http.request(.get, path, query: query))
    }
}

/// Port of `RemoteUserApi.kt` + `HttpUserClient.kt`.
public struct RemoteUserApi: KomgaUserApi {
    let http: KomgaHTTPClient
    public init(http: KomgaHTTPClient) { self.http = http }

    public func logout() async throws {
        try await http.send(http.request(.post, "api/logout"))
    }

    public func getMe() async throws -> KomgaUser {
        try await http.fetch(http.request(.get, "api/v2/users/me"))
    }

    public func getMe(username: String, password: String, rememberMe: Bool) async throws -> KomgaUser {
        let encoded = Data("\(username):\(password)".utf8).base64EncodedString()
        var query: [URLQueryItem] = []
        query.append("remember-me", rememberMe)
        return try await http.fetch(http.request(
            .get, "api/v2/users/me", query: query,
            headers: ["Authorization": "Basic \(encoded)", "Cache-Control": "no-cache, no-store, max-age=0"]))
    }

    public func updateMyPassword(_ newPassword: String) async throws {
        try await http.send(http.jsonRequest(.patch, "api/v2/users/me/password", body: ["password": newPassword]))
    }

    public func getAllUsers() async throws -> [KomgaUser] {
        try await http.fetch(http.request(.get, "api/v2/users"))
    }

    public func addUser(_ user: KomgaUserCreateRequest) async throws -> KomgaUser {
        try await http.fetch(http.jsonRequest(.post, "api/v2/users", body: user))
    }

    public func deleteUser(_ userId: KomgaUserId) async throws {
        try await http.send(http.request(.delete, "api/v2/users/\(userId)"))
    }

    public func updateUser(_ userId: KomgaUserId, request: KomgaUserUpdateRequest) async throws {
        try await http.send(http.jsonRequest(.patch, "api/v2/users/\(userId)", body: request))
    }

    public func updatePassword(_ userId: KomgaUserId, password: String) async throws {
        try await http.send(http.jsonRequest(.patch, "api/v2/users/\(userId)/password", body: ["password": password]))
    }

    public func getMeAuthenticationActivity(pageRequest: KomgaPageRequest?, unpaged: Bool) async throws
        -> Page<KomgaAuthenticationActivity>
    {
        try await activity("api/v2/users/me/authentication-activity", pageRequest, unpaged)
    }

    public func getAuthenticationActivity(pageRequest: KomgaPageRequest?, unpaged: Bool) async throws
        -> Page<KomgaAuthenticationActivity>
    {
        try await activity("api/v2/users/authentication-activity", pageRequest, unpaged)
    }

    public func getLatestAuthenticationActivityForUser(_ userId: KomgaUserId) async throws
        -> KomgaAuthenticationActivity?
    {
        try await http.nilIfNotFound {
            try await http.fetch(http.request(.get, "api/v2/users/\(userId)/authentication-activity/latest"))
        }
    }

    private func activity(_ path: String, _ pageRequest: KomgaPageRequest?, _ unpaged: Bool) async throws
        -> Page<KomgaAuthenticationActivity>
    {
        var request = pageRequest ?? KomgaPageRequest(unpaged: nil)
        request.unpaged = unpaged  // Kotlin appends `unpaged` separately; avoid sending it twice.
        var query: [URLQueryItem] = []
        query.appendPage(request)
        return try await http.fetch(http.request(.get, path, query: query))
    }
}

/// Ports of the small admin clients (settings, tasks, actuator, announcements, filesystem).
public struct RemoteSettingsApi: KomgaSettingsApi {
    let http: KomgaHTTPClient
    public init(http: KomgaHTTPClient) { self.http = http }

    public func getSettings() async throws -> KomgaSettings {
        try await http.fetch(http.request(.get, "api/v1/settings"))
    }

    public func updateSettings(_ request: KomgaSettingsUpdateRequest) async throws {
        try await http.send(http.jsonRequest(.patch, "api/v1/settings", body: request))
    }
}

public struct RemoteTaskApi: KomgaTaskApi {
    let http: KomgaHTTPClient
    public init(http: KomgaHTTPClient) { self.http = http }

    public func emptyTaskQueue() async throws -> Int {
        let (data, _) = try await http.send(http.request(.delete, "api/v1/tasks"))
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let count = Int(text) else { throw KomgaAPIError.decoding("Expected integer body, got '\(text)'") }
        return count
    }
}

public struct RemoteActuatorApi: KomgaActuatorApi {
    let http: KomgaHTTPClient
    public init(http: KomgaHTTPClient) { self.http = http }

    public func shutdown() async throws {
        try await http.send(http.request(.post, "actuator/shutdown"))
    }
}

public struct RemoteAnnouncementsApi: KomgaAnnouncementsApi {
    let http: KomgaHTTPClient
    public init(http: KomgaHTTPClient) { self.http = http }

    public func getAnnouncements() async throws -> KomgaJsonFeed {
        try await http.fetch(http.request(.get, "api/v1/announcements"))
    }

    public func markAnnouncementsRead(_ announcements: [KomgaAnnouncementId]) async throws {
        try await http.send(http.jsonRequest(.put, "api/v1/announcements", body: announcements))
    }
}

/// Desktop-only in the original (server directory picker); kept for protocol completeness.
public struct RemoteFileSystemApi: KomgaFileSystemApi {
    let http: KomgaHTTPClient
    public init(http: KomgaHTTPClient) { self.http = http }

    public func getDirectoryListing(_ request: DirectoryRequest) async throws -> DirectoryListing {
        try await http.fetch(http.jsonRequest(.post, "api/v1/filesystem", body: request))
    }
}
