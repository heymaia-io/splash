import Foundation
import KomgaAPI
import Synchronization

// Hand-rolled doubles for screen-model tests (the package has no shared mock module; test targets cannot
// import each other). Only the members a test overrides do anything — everything else traps, so a test
// that wanders into an unexpected call fails loudly instead of silently passing.

/// Records every mutating call in order and answers reads from the closures a test installs.
final class RecordingBookApi: KomgaBookApi, @unchecked Sendable {
    enum Call: Equatable { case deleteBook(KomgaBookId) }

    private let recorded = Mutex<[Call]>([])
    var calls: [Call] { recorded.withLock { $0 } }

    var onGetOne: @Sendable (KomgaBookId) async throws -> SplashBook = { _ in fatalError("getOne") }
    var onGetBookPages: @Sendable (KomgaBookId) async throws -> [KomgaBookPage] = { _ in [] }
    var onDeleteBook: @Sendable (KomgaBookId) async throws -> Void = { _ in }
    var onGetSiblingPrevious: @Sendable (KomgaBookId) async throws -> SplashBook? = { _ in nil }
    var onGetSiblingNext: @Sendable (KomgaBookId) async throws -> SplashBook? = { _ in nil }
    var onGetReadLists: @Sendable (KomgaBookId) async throws -> [KomgaReadList] = { _ in [] }

    func getOne(_ bookId: KomgaBookId) async throws -> SplashBook { try await onGetOne(bookId) }
    func getBookPages(_ bookId: KomgaBookId) async throws -> [KomgaBookPage] { try await onGetBookPages(bookId) }
    func deleteBook(_ bookId: KomgaBookId) async throws {
        recorded.withLock { $0.append(.deleteBook(bookId)) }
        try await onDeleteBook(bookId)
    }
    func getBookSiblingPrevious(_ bookId: KomgaBookId) async throws -> SplashBook? { try await onGetSiblingPrevious(bookId) }
    func getBookSiblingNext(_ bookId: KomgaBookId) async throws -> SplashBook? { try await onGetSiblingNext(bookId) }
    func getAllReadListsByBook(_ bookId: KomgaBookId) async throws -> [KomgaReadList] { try await onGetReadLists(bookId) }

    func getBookList(search: KomgaBookSearch, pageRequest: KomgaPageRequest?) async throws -> Page<SplashBook> { fatalError() }
    func getLatestBooks(pageRequest: KomgaPageRequest?) async throws -> Page<SplashBook> { fatalError() }
    func getBooksOnDeck(libraryIds: [KomgaLibraryId]?, pageRequest: KomgaPageRequest?) async throws -> Page<SplashBook> { fatalError() }
    func getDuplicateBooks(pageRequest: KomgaPageRequest?) async throws -> Page<SplashBook> { fatalError() }
    func updateMetadata(_ bookId: KomgaBookId, request: KomgaBookMetadataUpdateRequest) async throws { fatalError() }
    func analyze(_ bookId: KomgaBookId) async throws { fatalError() }
    func refreshMetadata(_ bookId: KomgaBookId) async throws { fatalError() }
    func markReadProgress(_ bookId: KomgaBookId, request: KomgaBookReadProgressUpdateRequest) async throws { fatalError() }
    func deleteReadProgress(_ bookId: KomgaBookId) async throws { fatalError() }
    func regenerateThumbnails(forBiggerResultOnly: Bool) async throws { fatalError() }
    func getDefaultThumbnail(_ bookId: KomgaBookId) async throws -> Data? { fatalError() }
    func getThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws -> Data { fatalError() }
    func getThumbnails(_ bookId: KomgaBookId) async throws -> [KomgaBookThumbnail] { fatalError() }
    func uploadThumbnail(_ bookId: KomgaBookId, file: Data, filename: String, selected: Bool) async throws -> KomgaBookThumbnail { fatalError() }
    func selectBookThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws { fatalError() }
    func deleteBookThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws { fatalError() }
    func getPage(_ bookId: KomgaBookId, page: Int) async throws -> Data { fatalError() }
    func getPageThumbnail(_ bookId: KomgaBookId, page: Int) async throws -> Data { fatalError() }
    func getReadiumProgression(_ bookId: KomgaBookId) async throws -> R2Progression? { fatalError() }
    func updateReadiumProgression(_ bookId: KomgaBookId, progression: R2Progression) async throws { fatalError() }
    func getReadiumPositions(_ bookId: KomgaBookId) async throws -> R2Positions { fatalError() }
    func getWebPubManifest(_ bookId: KomgaBookId) async throws -> WPPublication { fatalError() }
    func getBookEpubResource(_ bookId: KomgaBookId, resourceName: String) async throws -> Data { fatalError() }
}

final class RecordingLibraryApi: KomgaLibraryApi, @unchecked Sendable {
    private let recorded = Mutex<[KomgaLibraryId]>([])
    /// Libraries whose trash was emptied, in order.
    var emptiedTrash: [KomgaLibraryId] { recorded.withLock { $0 } }
    var onEmptyTrash: @Sendable (KomgaLibraryId) async throws -> Void = { _ in }

    func emptyTrash(_ libraryId: KomgaLibraryId) async throws {
        recorded.withLock { $0.append(libraryId) }
        try await onEmptyTrash(libraryId)
    }

    func getLibraries() async throws -> [KomgaLibrary] { fatalError() }
    func getLibrary(_ libraryId: KomgaLibraryId) async throws -> KomgaLibrary { fatalError() }
    func addOne(_ request: KomgaLibraryCreateRequest) async throws -> KomgaLibrary { fatalError() }
    func patchOne(_ libraryId: KomgaLibraryId, request: KomgaLibraryUpdateRequest) async throws { fatalError() }
    func deleteOne(_ libraryId: KomgaLibraryId) async throws { fatalError() }
    func scan(_ libraryId: KomgaLibraryId, deep: Bool) async throws { fatalError() }
    func analyze(_ libraryId: KomgaLibraryId) async throws { fatalError() }
    func refreshMetadata(_ libraryId: KomgaLibraryId) async throws { fatalError() }
}

final class StubSeriesApi: KomgaSeriesApi, @unchecked Sendable {
    var onGetOneSeries: @Sendable (KomgaSeriesId) async throws -> KomgaSeries = { _ in fatalError("getOneSeries") }

    func getOneSeries(_ seriesId: KomgaSeriesId) async throws -> KomgaSeries { try await onGetOneSeries(seriesId) }

    func getSeriesList(search: KomgaSeriesSearch, pageRequest: KomgaPageRequest?) async throws -> Page<KomgaSeries> { fatalError() }
    func getNewSeries(libraryIds: [KomgaLibraryId]?, oneshot: Bool?, deleted: Bool?, pageRequest: KomgaPageRequest?) async throws -> Page<KomgaSeries> { fatalError() }
    func getUpdatedSeries(libraryIds: [KomgaLibraryId]?, oneshot: Bool?, deleted: Bool?, pageRequest: KomgaPageRequest?) async throws -> Page<KomgaSeries> { fatalError() }
    func analyze(_ seriesId: KomgaSeriesId) async throws { fatalError() }
    func refreshMetadata(_ seriesId: KomgaSeriesId) async throws { fatalError() }
    func markAsRead(_ seriesId: KomgaSeriesId) async throws { fatalError() }
    func markAsUnread(_ seriesId: KomgaSeriesId) async throws { fatalError() }
    func delete(_ seriesId: KomgaSeriesId) async throws { fatalError() }
    func update(_ seriesId: KomgaSeriesId, request: KomgaSeriesMetadataUpdateRequest) async throws { fatalError() }
    func getDefaultThumbnail(_ seriesId: KomgaSeriesId) async throws -> Data? { fatalError() }
    func getThumbnail(_ seriesId: KomgaSeriesId, thumbnailId: KomgaThumbnailId) async throws -> Data { fatalError() }
    func getThumbnails(_ seriesId: KomgaSeriesId) async throws -> [KomgaSeriesThumbnail] { fatalError() }
    func uploadThumbnail(_ seriesId: KomgaSeriesId, file: Data, filename: String, selected: Bool) async throws -> KomgaSeriesThumbnail { fatalError() }
    func selectThumbnail(_ seriesId: KomgaSeriesId, thumbnailId: KomgaThumbnailId) async throws { fatalError() }
    func deleteThumbnail(_ seriesId: KomgaSeriesId, thumbnailId: KomgaThumbnailId) async throws { fatalError() }
    func getAllCollectionsBySeries(_ seriesId: KomgaSeriesId) async throws -> [KomgaCollection] { fatalError() }
}

/// Only the book, series and library areas are real; every other member traps if touched.
struct StubKomgaApi: KomgaApi {
    let bookApi: any KomgaBookApi
    var seriesApi: any KomgaSeriesApi = StubSeriesApi()
    var libraryApi: any KomgaLibraryApi = RecordingLibraryApi()

    var actuatorApi: any KomgaActuatorApi { fatalError() }
    var announcementsApi: any KomgaAnnouncementsApi { fatalError() }
    var collectionsApi: any KomgaCollectionsApi { fatalError() }
    var fileSystemApi: any KomgaFileSystemApi { fatalError() }
    var readListApi: any KomgaReadListApi { fatalError() }
    var referentialApi: any KomgaReferentialApi { fatalError() }
    var settingsApi: any KomgaSettingsApi { fatalError() }
    var tasksApi: any KomgaTaskApi { fatalError() }
    var userApi: any KomgaUserApi { fatalError() }
    func createSSESession() async throws -> any KomgaSSESession { fatalError() }
}

// MARK: - Fixtures

enum Fixture {
    static let date = Date(timeIntervalSince1970: 0)

    static func book(
        _ id: String = "b1", series: String = "s1", library: String = "lib", pagesCount: Int = 10,
        status: KomgaMediaStatus = .ready, mediaProfile: MediaProfile? = .divina, epubDivinaCompatible: Bool = false,
        readProgress: ReadProgress? = nil
    ) -> SplashBook {
        SplashBook(book: KomgaBook(
            id: KomgaBookId(id), seriesId: KomgaSeriesId(series), seriesTitle: series, libraryId: KomgaLibraryId(library),
            name: id, url: "/data/\(id).cbz", number: 1, created: date, lastModified: date,
            fileLastModified: date, sizeBytes: 1, size: "",
            media: Media(
                status: status, mediaType: "application/zip", pagesCount: pagesCount, comment: "",
                epubDivinaCompatible: epubDivinaCompatible, epubIsKepub: false, mediaProfile: mediaProfile),
            metadata: KomgaBookMetadata(
                title: id, summary: "", number: "1", numberSort: 1, releaseDate: nil, authors: [], tags: [],
                isbn: "", links: [], created: date, lastModified: date),
            readProgress: readProgress, deleted: false, fileHash: "", oneshot: false))
    }

    static func progress(page: Int, completed: Bool = false) -> ReadProgress {
        ReadProgress(page: page, completed: completed, readDate: date, deviceId: "", deviceName: "",
                     created: date, lastModified: date)
    }

    static func pages(_ count: Int) -> [KomgaBookPage] {
        (0..<count).map { $0 + 1 }.map {
            KomgaBookPage(number: $0, fileName: "\($0).jpg", mediaType: "image/jpeg", width: 1000, height: 1500,
                          sizeBytes: nil, size: "")
        }
    }

    static func series(_ id: String = "s1", library: String = "lib",
                       readingDirection: KomgaReadingDirection? = nil) -> KomgaSeries {
        KomgaSeries(
            id: KomgaSeriesId(id), libraryId: KomgaLibraryId(library), name: id, url: "/data/\(id)",
            booksCount: 1, booksReadCount: 0, booksUnreadCount: 1, booksInProgressCount: 0,
            metadata: KomgaSeriesMetadata(status: .ongoing, title: id, titleSort: id, readingDirection: readingDirection),
            deleted: false, oneshot: false,
            booksMetadata: KomgaSeriesBookMetadata(
                authors: [], tags: [], releaseDate: nil, summary: "", summaryNumber: "",
                created: date, lastModified: date),
            created: date, lastModified: date, fileLastModified: date)
    }

    static func user(admin: Bool) -> KomgaUser {
        KomgaUser(id: "u1", email: "u@example.com", roles: admin ? [KomgaUser.roleAdmin, KomgaUser.roleUser] : [KomgaUser.roleUser],
                  sharedAllLibraries: true, sharedLibrariesIds: [], labelsAllow: [], labelsExclude: [])
    }
}
