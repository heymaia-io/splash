import Foundation

// Port of komelia-domain/komga-api/src/commonMain/kotlin/snd/komelia/komga/api/*.kt
//
// ARCHITECTURAL SEAM (plan principle #2): every screen depends on these protocols, never on a concrete
// implementation. `RemoteKomgaApi` (HTTP) and `OfflineKomgaApi` (SQLite, Phase 10) both conform, which is
// what lets offline mode reuse the exact same UI. Do not downcast.
//
// Kotlin default arguments become protocol-extension overloads at the bottom of each file section.

public protocol KomgaApi: Sendable {
    var actuatorApi: any KomgaActuatorApi { get }
    var announcementsApi: any KomgaAnnouncementsApi { get }
    var bookApi: any KomgaBookApi { get }
    var collectionsApi: any KomgaCollectionsApi { get }
    var fileSystemApi: any KomgaFileSystemApi { get }
    var libraryApi: any KomgaLibraryApi { get }
    var readListApi: any KomgaReadListApi { get }
    var referentialApi: any KomgaReferentialApi { get }
    var seriesApi: any KomgaSeriesApi { get }
    var settingsApi: any KomgaSettingsApi { get }
    var tasksApi: any KomgaTaskApi { get }
    var userApi: any KomgaUserApi { get }

    func createSSESession() async throws -> any KomgaSSESession
}

public protocol KomgaActuatorApi: Sendable {
    func shutdown() async throws
    /// `GET /actuator/info` — build, runtime and host details. ADMIN only; other roles get a 403.
    func getInfo() async throws -> KomgaServerInfo
}

public protocol KomgaAnnouncementsApi: Sendable {
    func getAnnouncements() async throws -> KomgaJsonFeed
    func markAnnouncementsRead(_ announcements: [KomgaAnnouncementId]) async throws
}

public protocol KomgaFileSystemApi: Sendable {
    func getDirectoryListing(_ request: DirectoryRequest) async throws -> DirectoryListing
}

public protocol KomgaSettingsApi: Sendable {
    func getSettings() async throws -> KomgaSettings
    func updateSettings(_ request: KomgaSettingsUpdateRequest) async throws
}

public protocol KomgaTaskApi: Sendable {
    func emptyTaskQueue() async throws -> Int
}

// MARK: - Books

public protocol KomgaBookApi: Sendable {
    func getOne(_ bookId: KomgaBookId) async throws -> SplashBook
    func getBookList(search: KomgaBookSearch, pageRequest: KomgaPageRequest?) async throws -> Page<SplashBook>
    func getLatestBooks(pageRequest: KomgaPageRequest?) async throws -> Page<SplashBook>
    func getBooksOnDeck(libraryIds: [KomgaLibraryId]?, pageRequest: KomgaPageRequest?) async throws
        -> Page<SplashBook>
    func getDuplicateBooks(pageRequest: KomgaPageRequest?) async throws -> Page<SplashBook>
    func getBookSiblingPrevious(_ bookId: KomgaBookId) async throws -> SplashBook?
    func getBookSiblingNext(_ bookId: KomgaBookId) async throws -> SplashBook?
    func updateMetadata(_ bookId: KomgaBookId, request: KomgaBookMetadataUpdateRequest) async throws
    func getBookPages(_ bookId: KomgaBookId) async throws -> [KomgaBookPage]
    func analyze(_ bookId: KomgaBookId) async throws
    func refreshMetadata(_ bookId: KomgaBookId) async throws
    func markReadProgress(_ bookId: KomgaBookId, request: KomgaBookReadProgressUpdateRequest) async throws
    func deleteReadProgress(_ bookId: KomgaBookId) async throws
    func deleteBook(_ bookId: KomgaBookId) async throws
    func regenerateThumbnails(forBiggerResultOnly: Bool) async throws
    func getDefaultThumbnail(_ bookId: KomgaBookId) async throws -> Data?
    func getThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws -> Data
    func getThumbnails(_ bookId: KomgaBookId) async throws -> [KomgaBookThumbnail]
    func uploadThumbnail(_ bookId: KomgaBookId, file: Data, filename: String, selected: Bool) async throws
        -> KomgaBookThumbnail
    func selectBookThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws
    func deleteBookThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws
    func getAllReadListsByBook(_ bookId: KomgaBookId) async throws -> [KomgaReadList]
    func getPage(_ bookId: KomgaBookId, page: Int) async throws -> Data
    func getPageThumbnail(_ bookId: KomgaBookId, page: Int) async throws -> Data

    func getReadiumProgression(_ bookId: KomgaBookId) async throws -> R2Progression?
    func updateReadiumProgression(_ bookId: KomgaBookId, progression: R2Progression) async throws
    func getReadiumPositions(_ bookId: KomgaBookId) async throws -> R2Positions
    func getWebPubManifest(_ bookId: KomgaBookId) async throws -> WPPublication
    func getBookEpubResource(_ bookId: KomgaBookId, resourceName: String) async throws -> Data
}

extension KomgaBookApi {
    /// `getBookList(conditionBuilder, fullTextSearch, pageRequest)` overload.
    public func getBookList(
        condition: BookCondition?, fullTextSearch: String? = nil, pageRequest: KomgaPageRequest? = nil
    ) async throws -> Page<SplashBook> {
        try await getBookList(
            search: KomgaBookSearch(condition: condition, fullTextSearch: fullTextSearch), pageRequest: pageRequest)
    }

    public func getLatestBooks() async throws -> Page<SplashBook> { try await getLatestBooks(pageRequest: nil) }

    public func getBooksOnDeck(libraryIds: [KomgaLibraryId]? = nil) async throws -> Page<SplashBook> {
        try await getBooksOnDeck(libraryIds: libraryIds, pageRequest: nil)
    }

    public func uploadThumbnail(_ bookId: KomgaBookId, file: Data) async throws -> KomgaBookThumbnail {
        try await uploadThumbnail(bookId, file: file, filename: "", selected: true)
    }
}

// MARK: - Series

public protocol KomgaSeriesApi: Sendable {
    func getOneSeries(_ seriesId: KomgaSeriesId) async throws -> KomgaSeries
    func getSeriesList(search: KomgaSeriesSearch, pageRequest: KomgaPageRequest?) async throws -> Page<KomgaSeries>
    func getNewSeries(libraryIds: [KomgaLibraryId]?, oneshot: Bool?, deleted: Bool?, pageRequest: KomgaPageRequest?)
        async throws -> Page<KomgaSeries>
    func getUpdatedSeries(
        libraryIds: [KomgaLibraryId]?, oneshot: Bool?, deleted: Bool?, pageRequest: KomgaPageRequest?
    ) async throws -> Page<KomgaSeries>
    func analyze(_ seriesId: KomgaSeriesId) async throws
    func refreshMetadata(_ seriesId: KomgaSeriesId) async throws
    func markAsRead(_ seriesId: KomgaSeriesId) async throws
    func markAsUnread(_ seriesId: KomgaSeriesId) async throws
    func delete(_ seriesId: KomgaSeriesId) async throws
    func update(_ seriesId: KomgaSeriesId, request: KomgaSeriesMetadataUpdateRequest) async throws
    func getDefaultThumbnail(_ seriesId: KomgaSeriesId) async throws -> Data?
    func getThumbnail(_ seriesId: KomgaSeriesId, thumbnailId: KomgaThumbnailId) async throws -> Data
    func getThumbnails(_ seriesId: KomgaSeriesId) async throws -> [KomgaSeriesThumbnail]
    func uploadThumbnail(_ seriesId: KomgaSeriesId, file: Data, filename: String, selected: Bool) async throws
        -> KomgaSeriesThumbnail
    func selectThumbnail(_ seriesId: KomgaSeriesId, thumbnailId: KomgaThumbnailId) async throws
    func deleteThumbnail(_ seriesId: KomgaSeriesId, thumbnailId: KomgaThumbnailId) async throws
    func getAllCollectionsBySeries(_ seriesId: KomgaSeriesId) async throws -> [KomgaCollection]
}

extension KomgaSeriesApi {
    public func getSeriesList(
        condition: SeriesCondition?, fullTextSearch: String? = nil, pageRequest: KomgaPageRequest? = nil
    ) async throws -> Page<KomgaSeries> {
        try await getSeriesList(
            search: KomgaSeriesSearch(condition: condition, fullTextSearch: fullTextSearch), pageRequest: pageRequest)
    }

    public func getNewSeries(
        libraryIds: [KomgaLibraryId]? = nil, oneshot: Bool? = nil, pageRequest: KomgaPageRequest? = nil
    ) async throws -> Page<KomgaSeries> {
        try await getNewSeries(libraryIds: libraryIds, oneshot: oneshot, deleted: nil, pageRequest: pageRequest)
    }

    public func getUpdatedSeries(
        libraryIds: [KomgaLibraryId]? = nil, oneshot: Bool? = nil, pageRequest: KomgaPageRequest? = nil
    ) async throws -> Page<KomgaSeries> {
        try await getUpdatedSeries(libraryIds: libraryIds, oneshot: oneshot, deleted: nil, pageRequest: pageRequest)
    }
}

// MARK: - Libraries

public protocol KomgaLibraryApi: Sendable {
    func getLibraries() async throws -> [KomgaLibrary]
    func getLibrary(_ libraryId: KomgaLibraryId) async throws -> KomgaLibrary
    func addOne(_ request: KomgaLibraryCreateRequest) async throws -> KomgaLibrary
    func patchOne(_ libraryId: KomgaLibraryId, request: KomgaLibraryUpdateRequest) async throws
    func deleteOne(_ libraryId: KomgaLibraryId) async throws
    func scan(_ libraryId: KomgaLibraryId, deep: Bool) async throws
    func analyze(_ libraryId: KomgaLibraryId) async throws
    func refreshMetadata(_ libraryId: KomgaLibraryId) async throws
    func emptyTrash(_ libraryId: KomgaLibraryId) async throws
}

extension KomgaLibraryApi {
    public func scan(_ libraryId: KomgaLibraryId) async throws { try await scan(libraryId, deep: false) }
}

// MARK: - Collections

public protocol KomgaCollectionsApi: Sendable {
    func getAll(search: String?, libraryIds: [KomgaLibraryId]?, pageRequest: KomgaPageRequest?) async throws
        -> Page<KomgaCollection>
    func getOne(_ id: KomgaCollectionId) async throws -> KomgaCollection
    func addOne(_ request: KomgaCollectionCreateRequest) async throws -> KomgaCollection
    func updateOne(_ id: KomgaCollectionId, request: KomgaCollectionUpdateRequest) async throws
    func deleteOne(_ id: KomgaCollectionId) async throws
    func getSeriesForCollection(_ id: KomgaCollectionId, query: KomgaCollectionQuery?, pageRequest: KomgaPageRequest?)
        async throws -> Page<KomgaSeries>
    func getDefaultThumbnail(_ collectionId: KomgaCollectionId) async throws -> Data?
    func getThumbnail(_ collectionId: KomgaCollectionId, thumbnailId: KomgaThumbnailId) async throws -> Data
    func getThumbnails(_ collectionId: KomgaCollectionId) async throws -> [KomgaCollectionThumbnail]
    func uploadThumbnail(_ collectionId: KomgaCollectionId, file: Data, filename: String, selected: Bool)
        async throws -> KomgaCollectionThumbnail
    func selectThumbnail(_ collectionId: KomgaCollectionId, thumbnailId: KomgaThumbnailId) async throws
    func deleteThumbnail(_ collectionId: KomgaCollectionId, thumbnailId: KomgaThumbnailId) async throws
}

extension KomgaCollectionsApi {
    public func getAll(
        search: String? = nil, libraryIds: [KomgaLibraryId]? = nil, pageRequest: KomgaPageRequest? = nil
    ) async throws -> Page<KomgaCollection> {
        try await getAll(search: search, libraryIds: libraryIds, pageRequest: pageRequest)
    }

    public func getSeriesForCollection(_ id: KomgaCollectionId, pageRequest: KomgaPageRequest? = nil)
        async throws -> Page<KomgaSeries>
    {
        try await getSeriesForCollection(id, query: nil, pageRequest: pageRequest)
    }
}

// MARK: - Read lists

public protocol KomgaReadListApi: Sendable {
    func getAll(search: String?, libraryIds: [KomgaLibraryId]?, pageRequest: KomgaPageRequest?) async throws
        -> Page<KomgaReadList>
    func getOne(_ id: KomgaReadListId) async throws -> KomgaReadList
    func addOne(_ request: KomgaReadListCreateRequest) async throws -> KomgaReadList
    func updateOne(_ id: KomgaReadListId, request: KomgaReadListUpdateRequest) async throws
    func deleteOne(_ id: KomgaReadListId) async throws
    func getBooksForReadList(_ id: KomgaReadListId, query: KomgaReadListQuery?, pageRequest: KomgaPageRequest?)
        async throws -> Page<SplashBook>
    func getDefaultThumbnail(_ readListId: KomgaReadListId) async throws -> Data?
    func getThumbnail(_ readListId: KomgaReadListId, thumbnailId: KomgaThumbnailId) async throws -> Data
    func getThumbnails(_ readListId: KomgaReadListId) async throws -> [KomgaReadListThumbnail]
    func uploadThumbnail(_ readListId: KomgaReadListId, file: Data, filename: String, selected: Bool) async throws
        -> KomgaReadListThumbnail
    func selectThumbnail(_ readListId: KomgaReadListId, thumbnailId: KomgaThumbnailId) async throws
    func deleteThumbnail(_ readListId: KomgaReadListId, thumbnailId: KomgaThumbnailId) async throws
    func getBookSiblingNext(_ readListId: KomgaReadListId, bookId: KomgaBookId) async throws -> SplashBook?
    func getBookSiblingPrevious(_ readListId: KomgaReadListId, bookId: KomgaBookId) async throws -> SplashBook?
}

extension KomgaReadListApi {
    public func getAll(
        search: String? = nil, libraryIds: [KomgaLibraryId]? = nil, pageRequest: KomgaPageRequest? = nil
    ) async throws -> Page<KomgaReadList> {
        try await getAll(search: search, libraryIds: libraryIds, pageRequest: pageRequest)
    }

    public func getBooksForReadList(_ id: KomgaReadListId, pageRequest: KomgaPageRequest? = nil)
        async throws -> Page<SplashBook>
    {
        try await getBooksForReadList(id, query: nil, pageRequest: pageRequest)
    }
}

// MARK: - Referential

public protocol KomgaReferentialApi: Sendable {
    func getAuthors(
        search: String?, role: String?, libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?,
        seriesId: KomgaSeriesId?, readListId: KomgaReadListId?, pageRequest: KomgaPageRequest?
    ) async throws -> Page<KomgaAuthor>
    func getAuthorsNames(search: String?) async throws -> [String]
    func getAuthorsRoles() async throws -> [String]
    func getGenres(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws -> [String]
    func getSharingLabels(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws -> [String]
    func getTags(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws -> [String]
    func getBookTags(seriesId: KomgaSeriesId?, readListId: KomgaReadListId?, libraryIds: [KomgaLibraryId])
        async throws -> [String]
    func getSeriesTags(libraryId: KomgaLibraryId?, collectionId: KomgaCollectionId?) async throws -> [String]
    func getLanguages(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws -> [String]
    func getPublishers(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws -> [String]
    func getAgeRatings(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws -> [String]
    func getSeriesReleaseDates(libraryIds: [KomgaLibraryId], collectionId: KomgaCollectionId?) async throws
        -> [String]
}

extension KomgaReferentialApi {
    public func getGenres(libraryIds: [KomgaLibraryId] = []) async throws -> [String] {
        try await getGenres(libraryIds: libraryIds, collectionId: nil)
    }

    public func getTags(libraryIds: [KomgaLibraryId] = []) async throws -> [String] {
        try await getTags(libraryIds: libraryIds, collectionId: nil)
    }

    public func getAuthors(search: String? = nil, libraryIds: [KomgaLibraryId] = [],
                           pageRequest: KomgaPageRequest? = nil) async throws -> Page<KomgaAuthor> {
        try await getAuthors(search: search, role: nil, libraryIds: libraryIds, collectionId: nil, seriesId: nil,
                             readListId: nil, pageRequest: pageRequest)
    }
}

// MARK: - Users

public protocol KomgaUserApi: Sendable {
    func logout() async throws
    func getMe() async throws -> KomgaUser
    /// Password login; `rememberMe` asks the server for the `komga-remember-me` cookie.
    func getMe(username: String, password: String, rememberMe: Bool) async throws -> KomgaUser
    func updateMyPassword(_ newPassword: String) async throws
    func getAllUsers() async throws -> [KomgaUser]
    func addUser(_ user: KomgaUserCreateRequest) async throws -> KomgaUser
    func deleteUser(_ userId: KomgaUserId) async throws
    func updateUser(_ userId: KomgaUserId, request: KomgaUserUpdateRequest) async throws
    func updatePassword(_ userId: KomgaUserId, password: String) async throws
    func getMeAuthenticationActivity(pageRequest: KomgaPageRequest?, unpaged: Bool) async throws
        -> Page<KomgaAuthenticationActivity>
    func getAuthenticationActivity(pageRequest: KomgaPageRequest?, unpaged: Bool) async throws
        -> Page<KomgaAuthenticationActivity>
    func getLatestAuthenticationActivityForUser(_ userId: KomgaUserId) async throws -> KomgaAuthenticationActivity?
}
