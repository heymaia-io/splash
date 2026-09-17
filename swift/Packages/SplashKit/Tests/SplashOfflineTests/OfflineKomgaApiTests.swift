import CoreGraphics
import Foundation
import KomgaAPI
import Testing

@testable import SplashOffline

/// OfflineKomgaApi against an in-memory database seeded through the import actions.
///
/// Seed: library "Comics" (L1) with "Alpha" (3 books, B1 has a real CBZ + completed progress) and deleted
/// "Gamma"; library "Manga" (L2) with oneshot "Beta" (B4, a PDF).
@Suite(.serialized)
struct OfflineKomgaApiTests {
    static let comics = Fixtures.library("L1", name: "Comics")
    static let manga = Fixtures.library("L2", name: "Manga")
    static let alpha = Fixtures.series("S1", library: "L1", title: "Alpha", booksCount: 3, genres: ["Shonen"],
                                       totalBookCount: 3, publisher: "Pub A")
    static let beta = Fixtures.series(
        "S2", library: "L2", title: "Beta", booksCount: 1, oneshot: true, lastModified: baseDate.addingTimeInterval(60))
    static let gamma = Fixtures.series("S3", library: "L1", title: "Gamma", booksCount: 1, deleted: true)

    static let completed = ReadProgress(
        page: 2, completed: true, readDate: baseDate, deviceId: "d", deviceName: "iPad", created: baseDate,
        lastModified: baseDate)
    static let b1 = Fixtures.book(
        "B1", series: alpha, number: 1, title: "Alpha One", tags: ["Action"],
        authors: [KomgaAuthor(name: "Writer A", role: "writer")], releaseDate: KomgaLocalDate(year: 2020, month: 1, day: 5),
        readProgress: completed, summary: "First summary")
    static let b2 = Fixtures.book(
        "B2", series: alpha, number: 2, title: "Alpha Two", authors: [KomgaAuthor(name: "Artist B", role: "penciller")],
        releaseDate: KomgaLocalDate(year: 2021, month: 3, day: 1))
    static let b3 = Fixtures.book("B3", series: alpha, number: 3, title: "Alpha Three")
    static let b4 = Fixtures.book(
        "B4", series: beta, number: 1, title: "Beta Oneshot", pages: 3, profile: .pdf, mediaType: "application/pdf",
        oneshot: true)
    static let b5 = Fixtures.book("B5", series: gamma, number: 1, deleted: true)

    static let pdfSizes = [CGSize(width: 100, height: 200), CGSize(width: 300, height: 150), CGSize(width: 50, height: 50)]

    private func seeded() async throws -> OfflineTestEnvironment {
        let env = try await OfflineTestEnvironment.make()
        var source = StubImportSource()
        source.pages[Self.b1.id] = Fixtures.pages(["p1.png", "p2.png"])
        source.pages[Self.b2.id] = Fixtures.pages(["p1.png", "p2.png"])
        source.pages[Self.b3.id] = Fixtures.pages(["p1.png", "p2.png"])
        source.pages[Self.b4.id] = Fixtures.pages(["", "", ""], mediaType: "image/jpeg")
        source.bookThumbnails[Self.b1.id] = Fixtures.thumbnail(bookId: Self.b1.id, bytes: Data("thumb-b1".utf8))
        try await env.importHierarchy(
            libraries: [Self.comics, Self.manga], series: [Self.alpha, Self.beta, Self.gamma], user: Fixtures.user,
            source: source)
        try await env.settings.putUserId(Fixtures.user.id)
        let cbz = try await GeneratedMedia.cbz(entries: ["p1.png", "p2.png"])
        try await env.importBook(Self.b1, file: cbz, userId: Fixtures.user.id, source: source)
        try await env.importBook(Self.b2, file: cbz, userId: Fixtures.user.id, source: source)
        try await env.importBook(Self.b3, userId: Fixtures.user.id, source: source)
        try await env.importBook(
            Self.b4, file: GeneratedMedia.pdf(pageSizes: Self.pdfSizes), fileName: "Beta.pdf",
            userId: Fixtures.user.id, source: source)
        try await env.importBook(Self.b5, userId: Fixtures.user.id, source: source)
        for series in [Self.alpha, Self.beta, Self.gamma] {
            try await env.actions.seriesAggregateBookMetadata.execute(series.id)
        }
        return env
    }

    // MARK: Libraries / users

    @Test func librariesAreScopedToTheUsersServer() async throws {
        let env = try await seeded()
        defer { env.cleanup() }
        #expect(try await env.api.libraryApi.getLibraries().map(\.name) == ["Comics", "Manga"])
        #expect(try await env.api.libraryApi.getLibrary("L1") == Self.comics)
        #expect(try await env.api.userApi.getMe().email == Fixtures.user.email)

        // Another server's library is invisible to this user but visible to root.
        let other = try await env.actions.mediaServerSave.execute(serverUrl: "http://other.test")
        try await env.actions.libraryImport.execute(Fixtures.library("L9", name: "Elsewhere"), serverId: other.id)
        #expect(try await env.api.libraryApi.getLibraries().count == 2)
        try await env.settings.putUserId(OfflineUser.root)
        #expect(try await env.api.libraryApi.getLibraries().count == 3)
    }

    // MARK: Series

    @Test func seriesListingConditionsAndSorts() async throws {
        let env = try await seeded()
        defer { env.cleanup() }
        let api = env.api.seriesApi

        let inComics = try await api.getSeriesList(condition: .allOfSeries(.libraryId(.isEqualTo("L1"))))
        #expect(Set(inComics.content.map(\.id)) == ["S1", "S3"])

        let notDeleted = try await api.getSeriesList(
            condition: .allOfSeries(.libraryId(.isEqualTo("L1")), .deleted(.isFalse)))
        #expect(notDeleted.content.map(\.id) == ["S1"])

        let byTitleDesc = try await api.getSeriesList(
            condition: nil, pageRequest: KomgaPageRequest(sort: KomgaSeriesSort.byTitle(.desc)))
        #expect(byTitleDesc.content.map(\.metadata.title) == ["Gamma", "Beta", "Alpha"])
        #expect(byTitleDesc.totalElements == 3)

        let anyOf = try await api.getSeriesList(
            condition: .anyOfSeries(.oneShot(.isTrue), .deleted(.isTrue)),
            pageRequest: KomgaPageRequest(sort: KomgaSeriesSort.byTitle(.asc)))
        #expect(anyOf.content.map(\.id) == ["S2", "S3"])

        #expect(try await api.getSeriesList(condition: .genre(.isEqualTo("shonen"))).content.map(\.id) == ["S1"])
        #expect(try await api.getSeriesList(condition: .publisher(.isEqualTo("pub a"))).content.map(\.id) == ["S1"])
        #expect(try await api.getSeriesList(condition: .complete(.isTrue)).content.map(\.id) == ["S1"])
        #expect(try await api.getSeriesList(condition: .tag(.isEqualTo("ACTION"))).content.map(\.id) == ["S1"])
        #expect(
            try await api.getSeriesList(condition: .author(.isEqualTo(AuthorMatch(name: "writer a")))).content
                .map(\.id) == ["S1"])
        #expect(
            try await api.getSeriesList(condition: .title(.contains("ET"))).content.map(\.id) == ["S2"])
        #expect(
            try await api.getSeriesList(
                condition: .releaseDate(.after(Date(timeIntervalSince1970: 1_577_836_800)))  // 2020-01-01
            ).content.map(\.id) == ["S1"])
        #expect(try await api.getSeriesList(search: KomgaSeriesSearch(fullTextSearch: "gam"), pageRequest: nil)
            .content.map(\.id) == ["S3"])

        let paged = try await api.getSeriesList(
            condition: nil, pageRequest: KomgaPageRequest(pageIndex: 1, size: 2, sort: KomgaSeriesSort.byTitle(.asc)))
        #expect(paged.content.map(\.id) == ["S3"])
        #expect(paged.totalPages == 2 && paged.number == 1 && paged.last && !paged.first)

        #expect(try await api.getNewSeries(libraryIds: ["L2"]).content.map(\.id) == ["S2"])
        #expect(try await api.getUpdatedSeries().content.map(\.id) == ["S2"])  // only Beta has lastModified ≠ created
    }

    @Test func seriesDtoIsRebuiltWithCountsAndAggregation() async throws {
        let env = try await seeded()
        defer { env.cleanup() }
        let alpha = try await env.api.seriesApi.getOneSeries("S1")
        #expect(alpha.metadata.title == "Alpha")
        #expect(alpha.metadata.genres == ["Shonen"])
        #expect(alpha.metadata.tags == ["series-tag"])
        #expect(alpha.booksCount == 3 && alpha.booksReadCount == 1 && alpha.booksUnreadCount == 2)
        #expect(Set(alpha.booksMetadata.authors.map(\.name)) == ["Writer A", "Artist B"])
        #expect(alpha.booksMetadata.tags == ["Action"])
        #expect(alpha.booksMetadata.releaseDate == KomgaLocalDate(year: 2020, month: 1, day: 5))
        #expect(alpha.booksMetadata.summary == "First summary" && alpha.booksMetadata.summaryNumber == "1")

        #expect(try await env.api.seriesApi.getSeriesList(condition: .readStatus(.isEqualTo(.inProgress))).content
            .map(\.id) == ["S1"])
        #expect(Set(try await env.api.seriesApi.getSeriesList(condition: .readStatus(.isEqualTo(.unread))).content
            .map(\.id)) == ["S2", "S3"])
    }

    // MARK: Books

    @Test func bookListingConditionsSortsAndFlags() async throws {
        let env = try await seeded()
        defer { env.cleanup() }
        let api = env.api.bookApi

        let alphaBooks = try await api.getBookList(
            condition: .allOfBooks(.seriesId(.isEqualTo("S1")), .deleted(.isFalse)),
            pageRequest: KomgaPageRequest(sort: KomgaBooksSort.byNumber(.asc)))
        #expect(alphaBooks.content.map(\.id) == ["B1", "B2", "B3"])
        let first = try #require(alphaBooks.content.first)
        #expect(first.downloaded && !first.remoteFileUnavailable)
        #expect(first.localFileLastModified == Self.b1.fileLastModified)
        #expect(first.seriesTitle == "Alpha")
        #expect(first.media.mediaType == "application/zip" && first.media.mediaProfile == .divina)
        #expect(first.metadata.authors == [KomgaAuthor(name: "Writer A", role: "writer")])
        #expect(first.readProgress?.completed == true)
        #expect(first.size == "0.00MiB")

        #expect(try await api.getBookList(condition: .readStatus(.isEqualTo(.read))).content.map(\.id) == ["B1"])
        #expect(
            try await api.getBookList(
                condition: .allOfBooks(.readStatus(.isNotEqualTo(.read)), .seriesId(.isEqualTo("S1"))),
                pageRequest: KomgaPageRequest(sort: KomgaBooksSort.byNumber(.desc))
            ).content.map(\.id) == ["B3", "B2"])
        #expect(try await api.getBookList(condition: .tag(.isEqualTo("action"))).content.map(\.id) == ["B1"])
        #expect(try await api.getBookList(condition: .tag(.isNull)).totalElements == 4)
        #expect(
            try await api.getBookList(condition: .author(.isEqualTo(AuthorMatch(role: "PENCILLER")))).content
                .map(\.id) == ["B2"])
        #expect(try await api.getBookList(condition: .title(.beginsWith("alpha t"))).totalElements == 2)
        #expect(try await api.getBookList(condition: .oneShot(.isTrue)).content.map(\.id) == ["B4"])
        #expect(try await api.getBookList(condition: .mediaProfile(.isEqualTo(.pdf))).content.map(\.id) == ["B4"])
        #expect(try await api.getBookList(condition: .numberSort(.greaterThan(2))).content.map(\.id) == ["B3"])
        #expect(
            try await api.getBookList(condition: .releaseDate(.before(Date(timeIntervalSince1970: 1_600_000_000))))
                .content.map(\.id) == ["B1"])
        #expect(
            try await api.getBookList(
                condition: .anyOfBooks(.libraryId(.isEqualTo("L2")), .deleted(.isTrue)),
                pageRequest: KomgaPageRequest(sort: KomgaBooksSort.byTitle(.asc))
            ).content.map(\.id) == ["B4", "B5"])
        #expect(try await api.getBookList(condition: .readListId(.isEqualTo("RL"))).totalElements == 0)
        #expect(try await api.getBookList(search: KomgaBookSearch(fullTextSearch: "two"), pageRequest: nil)
            .content.map(\.id) == ["B2"])

        let paged = try await api.getBookList(
            condition: nil, pageRequest: KomgaPageRequest(pageIndex: 0, size: 2, sort: KomgaBooksSort.byTitle(.asc)))
        #expect(paged.content.count == 2 && paged.totalElements == 5 && paged.totalPages == 3)

        let latest = try await api.getLatestBooks(pageRequest: KomgaPageRequest(size: 1))
        #expect(latest.content.count == 1)
    }

    @Test func siblingsAndPages() async throws {
        let env = try await seeded()
        defer { env.cleanup() }
        let api = env.api.bookApi
        #expect(try await api.getBookSiblingPrevious("B1") == nil)
        #expect(try await api.getBookSiblingNext("B1")?.id == "B2")
        #expect(try await api.getBookSiblingPrevious("B3")?.id == "B2")
        #expect(try await api.getBookSiblingNext("B3") == nil)

        let pages = try await api.getBookPages("B1")
        #expect(pages.map(\.number) == [1, 2] && pages.map(\.fileName) == ["p1.png", "p2.png"])

        let page1 = try await api.getPage("B1", page: 1)
        let page2 = try await api.getPage("B1", page: 2)
        #expect(page1.starts(with: [0x89, 0x50, 0x4E, 0x47]))  // PNG
        #expect(page1 == GeneratedMedia.png + Data([0]) && page2 == GeneratedMedia.png + Data([1]))
        #expect(try await api.getPageThumbnail("B1", page: 2) == page2)
        await #expect(throws: OfflineError.self) { try await api.getPage("B1", page: 3) }
        await #expect(throws: OfflineError.self) { try await api.getPage("B3", page: 1) }  // file not downloaded
    }

    @Test func pdfPagesAreSinglePagePDFs() async throws {
        let env = try await seeded()
        defer { env.cleanup() }
        for (index, expected) in Self.pdfSizes.enumerated() {
            let data = try await env.api.bookApi.getPage("B4", page: index + 1)
            #expect(data.starts(with: Array("%PDF".utf8)))
            let document = try #require(CGPDFDocument(CGDataProvider(data: data as CFData)!))
            #expect(document.numberOfPages == 1)
            let box = try #require(document.page(at: 1)).getBoxRect(.mediaBox)
            #expect(box.size == expected)
        }
        await #expect(throws: OfflineError.self) { try await env.api.bookApi.getPage("B4", page: 4) }
    }

    @Test func thumbnails() async throws {
        let env = try await seeded()
        defer { env.cleanup() }
        #expect(try await env.api.bookApi.getDefaultThumbnail("B1") == Data("thumb-b1".utf8))
        #expect(try await env.api.bookApi.getDefaultThumbnail("B2") == nil)
        let thumbnails = try await env.api.bookApi.getThumbnails("B1")
        #expect(thumbnails.map(\.selected) == [true] && thumbnails.first?.bookId == "B1")
        // No series thumbnail: the first book's (library seriesCover = FIRST).
        #expect(try await env.api.seriesApi.getDefaultThumbnail("S1") == Data("thumb-b1".utf8))
        #expect(try await env.api.seriesApi.getDefaultThumbnail("S2") == nil)
    }

    // MARK: Read progress

    @Test func readProgressIsWrittenLocallyAndEmitsEvents() async throws {
        let env = try await seeded()
        defer { env.cleanup() }
        let session = try await env.api.createSSESession()
        let recorder = EventRecorder(session.incoming)
        let api = env.api.bookApi

        try await api.markReadProgress("B2", request: KomgaBookReadProgressUpdateRequest(page: 1))
        var b2 = try await api.getOne("B2")
        #expect(b2.readProgress?.page == 1 && b2.readProgress?.completed == false)
        #expect(try await env.api.seriesApi.getOneSeries("S1").booksInProgressCount == 1)

        // On deck needs "nothing in progress": B2 is in progress → nothing.
        #expect(try await api.getBooksOnDeck().content.isEmpty)

        try await api.markReadProgress("B2", request: KomgaBookReadProgressUpdateRequest(page: 2))  // last page
        b2 = try await api.getOne("B2")
        #expect(b2.readProgress?.completed == true)
        #expect(try await api.getBooksOnDeck(libraryIds: ["L1"]).content.map(\.id) == ["B3"])
        #expect(try await api.getBooksOnDeck(libraryIds: ["L2"]).content.isEmpty)

        try await api.deleteReadProgress("B2")
        #expect(try await api.getOne("B2").readProgress == nil)
        #expect(try await api.getBooksOnDeck().content.map(\.id) == ["B2"])
        await #expect(throws: OfflineError.self) {
            try await api.markReadProgress("B2", request: KomgaBookReadProgressUpdateRequest(page: 9))
        }

        try await env.api.seriesApi.markAsRead("S1")
        #expect(try await env.api.seriesApi.getOneSeries("S1").booksReadCount == 3)
        try await env.api.seriesApi.markAsUnread("S1")
        #expect(try await env.api.seriesApi.getOneSeries("S1").booksReadCount == 0)

        let delivered = await recorder.waitFor { events in
            events.contains(.readProgressChanged(.init(bookId: "B2", userId: Fixtures.user.id)))
                && events.contains(.readProgressDeleted(.init(bookId: "B2", userId: Fixtures.user.id)))
                && events.contains { if case .readProgressSeriesChanged = $0 { true } else { false } }
                && events.contains { if case .readProgressSeriesDeleted = $0 { true } else { false } }
        }
        #expect(delivered)
        session.cancel()
    }

    @Test func readiumProgressionForDivinaBooks() async throws {
        let env = try await seeded()
        defer { env.cleanup() }
        let progression = R2Progression(
            modified: baseDate, device: R2Device(id: "dev", name: "iPad"),
            locator: R2Locator(href: "p1.png", type: "image/png", locations: R2Location(position: 1)))
        try await env.api.bookApi.updateReadiumProgression("B3", progression: progression)
        let stored = try #require(try await env.api.bookApi.getReadiumProgression("B3"))
        #expect(stored.device == R2Device(id: "dev", name: "iPad"))
        #expect(stored.locator.locations?.position == 1)
        #expect(try await env.api.bookApi.getOne("B3").readProgress?.page == 1)
    }

    // MARK: Referential / unsupported

    @Test func referentialValues() async throws {
        let env = try await seeded()
        defer { env.cleanup() }
        let api = env.api.referentialApi
        #expect(try await api.getGenres() == ["Shonen"])
        #expect(try await api.getTags(libraryIds: ["L1"]) == ["Action", "series-tag"])
        #expect(try await api.getBookTags(seriesId: "S1", readListId: nil, libraryIds: []) == ["Action"])
        #expect(try await api.getAuthorsNames(search: "writ") == ["Writer A"])
        #expect(Set(try await api.getAuthorsRoles()) == ["writer", "penciller"])
        #expect(try await api.getAuthors(search: "a", libraryIds: ["L1"]).totalElements == 2)
        #expect(try await api.getPublishers(libraryIds: [], collectionId: nil) == ["Pub A"])
        #expect(try await api.getLanguages(libraryIds: ["L2"], collectionId: nil) == ["en"])
        #expect(try await api.getAgeRatings(libraryIds: [], collectionId: nil) == ["None"])
        #expect(try await api.getSeriesReleaseDates(libraryIds: [], collectionId: nil) == ["2020"])
        #expect(try await api.getGenres(libraryIds: [], collectionId: "C1").isEmpty)
    }

    @Test func unsupportedOperationsThrow() async throws {
        let env = try await seeded()
        defer { env.cleanup() }
        await #expect(throws: KomgaAPIError.unsupported("Book analysis is not available offline")) {
            try await env.api.bookApi.analyze("B1")
        }
        await #expect(throws: KomgaAPIError.self) { try await env.api.libraryApi.scan("L1") }
        await #expect(throws: KomgaAPIError.self) {
            try await env.api.seriesApi.update("S1", request: KomgaSeriesMetadataUpdateRequest())
        }
        await #expect(throws: KomgaAPIError.self) { try await env.api.userApi.deleteUser(Fixtures.user.id) }
        #expect(try await env.api.userApi.getAllUsers().map(\.id) == [Fixtures.user.id])
        #expect(try await env.api.collectionsApi.getAll().content.isEmpty)
        #expect(try await env.api.readListApi.getAll().content.isEmpty)
        #expect(try await env.api.settingsApi.getSettings().thumbnailSize == .default)
        #expect(try await env.api.announcementsApi.getAnnouncements().items.isEmpty)
        #expect(try await env.api.fileSystemApi.getDirectoryListing(DirectoryRequest(path: "/")).directories.isEmpty)
    }

    // MARK: Deletion + book states

    @Test func deletingASeriesRemovesRowsAndQueuesFileDeletion() async throws {
        let env = try await seeded()
        defer { env.cleanup() }
        let states = DatabaseOfflineBookStateProvider(store: env.store)
        #expect(Array(try await states.offlineStates(for: ["B1", "B9"]).keys) == ["B1"])
        let storedPath = try await env.store.read { try $0.books.get("B1").fileDownloadPath }
        let b1File = env.locator.fileURL(for: storedPath)
        #expect(FileManager.default.fileExists(atPath: b1File.path(percentEncoded: false)))

        try await env.api.seriesApi.delete("S1")
        await #expect(throws: OfflineError.self) { try await env.api.seriesApi.getOneSeries("S1") }
        #expect(try await env.api.bookApi.getBookList(condition: .seriesId(.isEqualTo("S1"))).content.isEmpty)
        #expect(try await states.offlineStates(for: ["B1"]).isEmpty)

        let queued = try await env.tasks.findAll().map(\.task)
        #expect(queued.contains(.deleteBookFiles(storedPath)))
        #expect(env.locator.storedPath(for: b1File) == storedPath)
        for case .deleteBookFiles(let path) in queued { try await env.actions.bookDeleteFiles.execute(path) }
        #expect(!FileManager.default.fileExists(atPath: b1File.path(percentEncoded: false)))
        // Emptied series folder is removed too, but never the download root.
        #expect(!FileManager.default.fileExists(atPath: b1File.deletingLastPathComponent().path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: env.root.path(percentEncoded: false)))

        try await env.api.libraryApi.deleteOne("L2")
        #expect(try await env.api.libraryApi.getLibraries().map(\.id) == ["L1"])
    }

    @Test func remoteUnavailableFlag() async throws {
        let env = try await seeded()
        defer { env.cleanup() }
        try await env.actions.bookMarkRemoteDeleted.execute("B2")
        #expect(try await env.api.bookApi.getOne("B2").remoteFileUnavailable)
        let available = try await env.store.read { repos in try repos.books.findAllNotDeleted("S1").map { $0.id } }
        #expect(Set(available) == ["B1", "B3"])
    }
}
