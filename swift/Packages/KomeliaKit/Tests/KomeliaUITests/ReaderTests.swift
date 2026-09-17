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
