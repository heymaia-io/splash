import Foundation
import KomgaAPI
import Testing

@testable import KomeliaOffline

/// A "remote" API built from another KomgaApi (here the offline one) where some books answer 404 and progress
/// writes are recorded (Decorator).
struct FakeRemoteApi: KomgaApi {
    let base: any KomgaApi
    let books: RecordingBookApi

    init(base: any KomgaApi, missingBooks: Set<KomgaBookId>) {
        self.base = base
        books = RecordingBookApi(base: base.bookApi, missing: missingBooks)
    }

    var actuatorApi: any KomgaActuatorApi { base.actuatorApi }
    var announcementsApi: any KomgaAnnouncementsApi { base.announcementsApi }
    var bookApi: any KomgaBookApi { books }
    var collectionsApi: any KomgaCollectionsApi { base.collectionsApi }
    var fileSystemApi: any KomgaFileSystemApi { base.fileSystemApi }
    var libraryApi: any KomgaLibraryApi { base.libraryApi }
    var readListApi: any KomgaReadListApi { base.readListApi }
    var referentialApi: any KomgaReferentialApi { base.referentialApi }
    var seriesApi: any KomgaSeriesApi { base.seriesApi }
    var settingsApi: any KomgaSettingsApi { base.settingsApi }
    var tasksApi: any KomgaTaskApi { base.tasksApi }
    var userApi: any KomgaUserApi { base.userApi }
    func createSSESession() async throws -> any KomgaSSESession { try await base.createSSESession() }
}

final class RecordingBookApi: KomgaBookApi, @unchecked Sendable {
    let base: any KomgaBookApi
    let missing: Set<KomgaBookId>
    private let lock = NSLock()
    private var _progressWrites: [(KomgaBookId, KomgaBookReadProgressUpdateRequest)] = []
    var remoteProgress: [KomgaBookId: ReadProgress] = [:]

    init(base: any KomgaBookApi, missing: Set<KomgaBookId>) {
        self.base = base
        self.missing = missing
    }

    var progressWrites: [(KomgaBookId, KomgaBookReadProgressUpdateRequest)] { lock.withLock { _progressWrites } }

    private func check(_ id: KomgaBookId) throws {
        if missing.contains(id) { throw KomgaAPIError.httpStatus(code: 404, body: Data()) }
    }

    func getOne(_ bookId: KomgaBookId) async throws -> KomeliaBook {
        try check(bookId)
        var book = try await base.getOne(bookId)
        book.book.readProgress = lock.withLock { remoteProgress[bookId] }
        return book
    }
    func getBookList(search: KomgaBookSearch, pageRequest: KomgaPageRequest?) async throws -> Page<KomeliaBook> {
        try await base.getBookList(search: search, pageRequest: pageRequest)
    }
    func getLatestBooks(pageRequest: KomgaPageRequest?) async throws -> Page<KomeliaBook> {
        try await base.getLatestBooks(pageRequest: pageRequest)
    }
    func getBooksOnDeck(libraryIds: [KomgaLibraryId]?, pageRequest: KomgaPageRequest?) async throws
        -> Page<KomeliaBook>
    { try await base.getBooksOnDeck(libraryIds: libraryIds, pageRequest: pageRequest) }
    func getDuplicateBooks(pageRequest: KomgaPageRequest?) async throws -> Page<KomeliaBook> { .empty() }
    func getBookSiblingPrevious(_ bookId: KomgaBookId) async throws -> KomeliaBook? { nil }
    func getBookSiblingNext(_ bookId: KomgaBookId) async throws -> KomeliaBook? { nil }
    func updateMetadata(_ bookId: KomgaBookId, request: KomgaBookMetadataUpdateRequest) async throws {}
    func getBookPages(_ bookId: KomgaBookId) async throws -> [KomgaBookPage] { try await base.getBookPages(bookId) }
    func analyze(_ bookId: KomgaBookId) async throws {}
    func refreshMetadata(_ bookId: KomgaBookId) async throws {}
    func markReadProgress(_ bookId: KomgaBookId, request: KomgaBookReadProgressUpdateRequest) async throws {
        lock.withLock { _progressWrites.append((bookId, request)) }
    }
    func deleteReadProgress(_ bookId: KomgaBookId) async throws {}
    func deleteBook(_ bookId: KomgaBookId) async throws {}
    func regenerateThumbnails(forBiggerResultOnly: Bool) async throws {}
    func getDefaultThumbnail(_ bookId: KomgaBookId) async throws -> Data? { nil }
    func getThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws -> Data {
        try await base.getThumbnail(bookId, thumbnailId: thumbnailId)
    }
    func getThumbnails(_ bookId: KomgaBookId) async throws -> [KomgaBookThumbnail] {
        try await base.getThumbnails(bookId)
    }
    func uploadThumbnail(_ bookId: KomgaBookId, file: Data, filename: String, selected: Bool) async throws
        -> KomgaBookThumbnail
    { throw KomgaAPIError.unsupported("") }
    func selectBookThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws {}
    func deleteBookThumbnail(_ bookId: KomgaBookId, thumbnailId: KomgaThumbnailId) async throws {}
    func getAllReadListsByBook(_ bookId: KomgaBookId) async throws -> [KomgaReadList] { [] }
    func getPage(_ bookId: KomgaBookId, page: Int) async throws -> Data { Data() }
    func getPageThumbnail(_ bookId: KomgaBookId, page: Int) async throws -> Data { Data() }
    func getReadiumProgression(_ bookId: KomgaBookId) async throws -> R2Progression? { nil }
    func updateReadiumProgression(_ bookId: KomgaBookId, progression: R2Progression) async throws {}
    func getReadiumPositions(_ bookId: KomgaBookId) async throws -> R2Positions { throw KomgaAPIError.unsupported("") }
    func getWebPubManifest(_ bookId: KomgaBookId) async throws -> WPPublication { throw KomgaAPIError.unsupported("") }
    func getBookEpubResource(_ bookId: KomgaBookId, resourceName: String) async throws -> Data { Data() }
}

@Suite(.serialized)
struct SyncManagerTests {
    static let library = Fixtures.library("L1", name: "Comics")
    static let series = Fixtures.series("S1", library: "L1", title: "Alpha", booksCount: 2)

    private func seeded() async throws -> OfflineTestEnvironment {
        let env = try await OfflineTestEnvironment.make()
        try await env.importHierarchy(libraries: [Self.library], series: [Self.series], user: Fixtures.user)
        var source = StubImportSource()
        source.pages["B1"] = Fixtures.pages(["p1.png", "p2.png"])
        source.pages["B2"] = Fixtures.pages(["p1.png", "p2.png"])
        try await env.importBook(Fixtures.book("B1", series: Self.series, number: 1), userId: Fixtures.user.id, source: source)
        try await env.importBook(Fixtures.book("B2", series: Self.series, number: 2), userId: Fixtures.user.id, source: source)
        try await env.settings.putUserId(Fixtures.user.id)
        return env
    }

    @Test func pushesNewerLocalProgressOnlyAndMarksMissingBooksUnavailable() async throws {
        let env = try await seeded()
        defer { env.cleanup() }
        let remote = FakeRemoteApi(base: env.api, missingBooks: ["B2"])
        // Remote progress of B1 is older than the local one → pushed; B2 is gone (404) → error, not pushed.
        remote.books.remoteProgress["B1"] = ReadProgress(
            page: 1, completed: false, readDate: baseDate, deviceId: "", deviceName: "", created: baseDate,
            lastModified: baseDate)
        try await env.api.bookApi.markReadProgress("B1", request: KomgaBookReadProgressUpdateRequest(page: 2))
        try await env.api.bookApi.markReadProgress("B2", request: KomgaBookReadProgressUpdateRequest(page: 1))

        let manager = SyncManager(actions: env.actions)
        let result = await manager.sync(user: Fixtures.user, api: remote)

        #expect(result == SyncManager.Result(progressPushed: false, dataSynced: false))
        #expect(remote.books.progressWrites.map(\.0) == ["B1"])
        #expect(remote.books.progressWrites.first?.1 == KomgaBookReadProgressUpdateRequest(completed: true))
        // Nothing is marked as synced after a partial failure (the fix), so the next run retries.
        #expect(env.settings.readProgressSyncDate == nil)
        #expect(env.settings.dataSyncDate == nil)
        #expect(try await env.api.bookApi.getOne("B2").remoteFileUnavailable)
        #expect(try await !env.api.bookApi.getOne("B1").remoteFileUnavailable)
        let errors = try await env.store.read { try $0.logJournal.findAll(type: .error, limit: 10, offset: 0) }
        #expect(errors.totalElements >= 2)
    }

    @Test func successfulSyncAdvancesDatesAndIsThrottled() async throws {
        let env = try await seeded()
        defer { env.cleanup() }
        let remote = FakeRemoteApi(base: env.api, missingBooks: [])
        let manager = SyncManager(actions: env.actions)

        let first = await manager.sync(user: Fixtures.user, api: remote)
        #expect(first == SyncManager.Result(progressPushed: true, dataSynced: true))
        let syncedAt = try #require(env.settings.dataSyncDate)
        #expect(env.settings.readProgressSyncDate != nil)

        // Within 6 h the data pull is skipped; `onlineUserChanged` goes through the same serialized path.
        await manager.onlineUserChanged(Fixtures.user, api: remote)
        await manager.onlineUserChanged(nil, api: remote)
        await manager.waitForCurrentSync()
        #expect(env.settings.dataSyncDate == syncedAt)
        #expect(await manager.sync(user: Fixtures.user, api: remote)?.dataSynced == nil)
        #expect(await manager.sync(user: Fixtures.user, api: remote, force: true)?.dataSynced == true)
    }

    @Test func epubBooksImportWithoutPagesOrReadiumData() async throws {
        let env = try await seeded()
        defer { env.cleanup() }
        let epub = Fixtures.book(
            "E1", series: Self.series, number: 3, pages: 0, profile: .epub, mediaType: "application/epub+zip")
        try await env.importBook(epub, file: Data("epub".utf8), fileName: "E1.epub", userId: Fixtures.user.id)

        let downloaded = try await env.api.bookApi.getOne("E1")
        #expect(downloaded.downloaded && downloaded.media.mediaProfile == .epub)
        #expect(try await env.api.bookApi.getBookPages("E1").isEmpty)
        await #expect(throws: OfflineError.self) { try await env.api.bookApi.getPage("E1", page: 1) }

        let manager = URLSessionDownloadManager(
            service: BookDownloadService(actions: env.actions, remote: { throw OfflineError.invalidState("offline") }),
            store: env.store, requestProvider: { _ in throw OfflineError.invalidState("offline") })
        defer { manager.invalidate() }
        let downloads = OfflineDownloads(store: env.store, taskEmitter: env.emitter, fileLocator: env.locator, manager: manager)
        let url = try #require(try await downloads.localFileURL(for: "E1"))
        #expect(url.lastPathComponent == "E1.epub")
        #expect(try Data(contentsOf: url) == Data("epub".utf8))
        #expect(try await downloads.localFileURL(for: "B1") == nil)  // imported without a file
        #expect(try await downloads.downloadedBytes() == 4)
    }
}
