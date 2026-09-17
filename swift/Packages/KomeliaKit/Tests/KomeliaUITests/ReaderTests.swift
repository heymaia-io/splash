import CoreGraphics
import Foundation
import Testing
@testable import KomeliaCore
@testable import KomeliaUI
@testable import KomgaAPI
@testable import KomgaRemote

@Suite struct ReaderLogicTests {
    func pages(_ landscape: Set<Int> = [], count: Int = 8) -> [PageMetadata] {
        (1...count).map { n in
            PageMetadata(bookId: "B", pageNumber: n,
                         size: landscape.contains(n) ? CGSize(width: 2000, height: 1000) : CGSize(width: 1000, height: 1500))
        }
    }

    func numbers(_ spreads: [[PageMetadata]]) -> [[Int]] { spreads.map { $0.map(\.pageNumber) } }

    @Test func singlePageSpreads() {
        #expect(numbers(PagedReaderModel.buildSpreadMap(pages(count: 3), layout: .singlePage, offset: false))
                == [[1], [2], [3]])
    }

    @Test func doublePagesWithCoverAndLandscapeBreaks() {
        let spreads = PagedReaderModel.buildSpreadMap(pages([5], count: 8), layout: .doublePages, offset: false)
        #expect(numbers(spreads) == [[1], [2, 3], [4], [5], [6, 7], [8]])
    }

    @Test func doublePagesNoCoverWithOffset() {
        let spreads = PagedReaderModel.buildSpreadMap(pages(count: 6), layout: .doublePagesNoCover, offset: true)
        #expect(numbers(spreads) == [[1], [2, 3], [4, 5], [6]])
    }

    @Test(arguments: [
        (KomgaReadingDirection?.some(.leftToRight), ReaderType.continuous, ReaderType.paged),
        (.some(.rightToLeft), .continuous, .paged),
        (.some(.webtoon), .paged, .continuous),
        (.some(.vertical), .continuous, .continuous),
        (nil, .panels, .paged),
    ])
    func readerTypeDerivation(direction: KomgaReadingDirection?, fallback: ReaderType, expected: ReaderType) {
        #expect(ReaderViewModel.readerType(for: direction, fallback: fallback) == expected)
    }

    @Test func spreadLayoutScaleTypes() {
        let area = CGSize(width: 1000, height: 800)
        let page = [CGSize(width: 1000, height: 2000)]
        #expect(SpreadLayout.pageSizes(contentSizes: page, area: area, scaleType: .screen, stretchToFit: true, screenScale: 1)
                == [CGSize(width: 400, height: 800)])
        #expect(SpreadLayout.pageSizes(contentSizes: page, area: area, scaleType: .fitWidth, stretchToFit: true, screenScale: 1)
                == [CGSize(width: 1000, height: 2000)])
        #expect(SpreadLayout.pageSizes(contentSizes: page, area: area, scaleType: .fitHeight, stretchToFit: true, screenScale: 1)
                == [CGSize(width: 400, height: 800)])
        #expect(SpreadLayout.pageSizes(contentSizes: page, area: area, scaleType: .original, stretchToFit: true, screenScale: 2)
                == [CGSize(width: 500, height: 1000)])
        // Two pages share the width.
        let two = SpreadLayout.pageSizes(contentSizes: page + page, area: area, scaleType: .screen,
                                         stretchToFit: true, screenScale: 1)
        #expect(two == [CGSize(width: 400, height: 800), CGSize(width: 400, height: 800)])  // 500×800 half, height-limited
        let (content, frames) = SpreadLayout.frames(for: two, rightToLeft: true)
        #expect(content == CGSize(width: 800, height: 800))
        #expect(frames[0].minX == 400)  // first page on the right
    }
}

@MainActor
@Suite(.enabled(if: FixtureAvailability.isAvailable), .serialized)
struct ReaderIntegrationTests {
    func api() async throws -> RemoteKomgaApi {
        let url = URL(string: "http://localhost:25601")!
        let cookies = KomgaCookieStore(serverURL: { url }, persistence: nil)
        let api = RemoteKomgaApi(http: KomgaHTTPClient(baseURL: { url }, cookieStore: cookies))
        _ = try await api.userApi.getMe(username: "admin@fixture.local", password: "fixture-password", rememberMe: true)
        return api
    }

    func bookId(_ api: RemoteKomgaApi, title: String) async throws -> KomgaBookId {
        try #require(try await api.bookApi.getBookList(condition: .title(.isEqualTo(title))).content.first).id
    }

    @Test func pagedReaderLoadsTurnsPagesAndReportsProgress() async throws {
        let api = try await api()
        let id = try await bookId(api, title: "Fixture Hero #2")
        let settings = SettingsState(initial: ImageReaderSettings()) { _ in }
        let reader = ReaderViewModel(bookId: id, api: api, settings: settings)
        await reader.initialize()
        #expect(reader.readerType == .paged)
        #expect(reader.books?.currentBookPages.count == 12)
        #expect(reader.books?.previousBook != nil && reader.books?.nextBook != nil)

        let paged = PagedReaderModel(reader: reader)
        paged.bookDidChange()
        try await waitUntil { paged.currentSpread.first?.image != nil }
        #expect(paged.handleTap(atX: 500, width: 1000))  // center toggles overlay
        #expect(!paged.handleTap(atX: 900, width: 1000))  // right = next in LTR
        #expect(paged.currentPageNumber == 2)
        try await waitUntil(timeout: .seconds(5)) { true }
        try await Task.sleep(for: .milliseconds(500))
        #expect(try await api.bookApi.getOne(id).readProgress?.page == 2)

        paged.goTo(pageNumber: 12)
        paged.nextPage()
        if case .bookEnd(_, let next) = paged.transitionPage { #expect(next != nil) } else {
            Issue.record("expected book end transition")
        }
        try await api.bookApi.deleteReadProgress(id)
    }

    @Test func webtoonUsesContinuousReaderWithLayout() async throws {
        let api = try await api()
        let id = try await bookId(api, title: "Fixture Webtoon #1")
        let reader = ReaderViewModel(
            bookId: id, api: api, settings: SettingsState(initial: ImageReaderSettings()) { _ in },
            markReadProgress: false)
        await reader.initialize()
        #expect(reader.readerType == .continuous)
        let model = ContinuousReaderModel(reader: reader)
        model.bookDidChange()
        let frames = model.layoutFrames(viewport: CGSize(width: 800, height: 1000))
        #expect(frames.count == 5)
        #expect(frames[1].minY == frames[0].maxY)
        #expect(abs(frames[0].height - 6000) < 1)  // 800x6000 page at 800pt width
        let image = await model.image(for: model.pages[0])
        #expect(image?.originalSize == CGSize(width: 800, height: 6000))
    }
}

@MainActor
@Suite struct EpubReaderModelTests {
    @Test func hrefMappingBetweenKomgaAndReader() throws {
        let book = try JSONDecoder.komga.decode(KomgaBook.self, from: Self.bookJSON)
        let model = EpubReaderModel(
            book: KomeliaBook(book: book),
            source: .remote(manifest: URL(string: "http://h:1/api/v1/books/B/manifest")!, headers: { _ in [:] }),
            api: RemoteKomgaApi(http: KomgaHTTPClient(baseURL: { URL(string: "http://h:1")! })),
            settings: SettingsState(initial: EpubReaderSettings()) { _ in })
        let reader = model.toReader(R2Locator(href: "text/ch1.html", type: "application/xhtml+xml",
                                              locations: R2Location(progression: 0.5, totalProgression: 0.25)))
        #expect(reader.href == "text/ch1.html")
        #expect(model.toReader(R2Locator(href: "http://h:1/api/v1/books/B/resource/a.html", type: "t")).href == "a.html")
        #expect(reader.totalProgression == 0.25)
        let absolute = EpubLocation(href: "http://h:1/api/v1/books/B/resource/text/ch1.html", type: "t",
                                    progression: 0.5, totalProgression: 0.25, position: nil)
        let komga = model.toKomga(absolute)
        #expect(komga.href == "text/ch1.html")
        #expect(komga.locations?.progression == 0.5)
    }

    @Test func localSourceKeepsRelativeHrefs() throws {
        let book = try JSONDecoder.komga.decode(KomgaBook.self, from: Self.bookJSON)
        let model = EpubReaderModel(
            book: KomeliaBook(book: book), source: .local(file: URL(filePath: "/tmp/b.epub")),
            api: RemoteKomgaApi(http: KomgaHTTPClient(baseURL: { URL(string: "http://h:1")! })),
            settings: SettingsState(initial: EpubReaderSettings()) { _ in })
        let location = EpubLocation(href: "/OEBPS/c.xhtml", type: "t", progression: nil, totalProgression: nil, position: 3)
        #expect(model.toKomga(location).href == "OEBPS/c.xhtml")
        #expect(model.toReader(R2Locator(href: "OEBPS/c.xhtml", type: "t")).href == "OEBPS/c.xhtml")
    }

    static let bookJSON = Data(#"""
    {"id":"B","seriesId":"S","seriesTitle":"S","libraryId":"L","name":"n","url":"/x.epub","number":1,
     "created":"2026-01-01T00:00:00Z","lastModified":"2026-01-01T00:00:00Z","fileLastModified":"2026-01-01T00:00:00Z",
     "sizeBytes":1,"size":"1 B","media":{"status":"READY","mediaType":"application/epub+zip","pagesCount":0,
     "comment":"","epubDivinaCompatible":false,"epubIsKepub":false,"mediaProfile":"EPUB"},
     "metadata":{"title":"t","summary":"","number":"1","numberSort":1,"releaseDate":null,"authors":[],"tags":[],
     "isbn":"","links":[],"titleLock":false,"summaryLock":false,"numberLock":false,"numberSortLock":false,
     "releaseDateLock":false,"authorsLock":false,"tagsLock":false,"isbnLock":false,"linksLock":false,
     "created":"2026-01-01T00:00:00Z","lastModified":"2026-01-01T00:00:00Z"},
     "readProgress":null,"deleted":false,"fileHash":"","oneshot":false}
    """#.utf8)
}

extension JSONDecoder {
    static var komga: JSONDecoder { KomgaJSON.makeDecoder() }
}
