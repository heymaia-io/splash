import Foundation
import Testing
@testable import KomgaAPI
@testable import SplashCore

/// `HiddenContentFilter` is the single place that decides what a private-content screen may show, so it
/// carries the bulk of the feature's test weight — every chokepoint elsewhere is a one-line call into it.
@Suite struct HiddenContentFilterTests {
    // MARK: Fixtures

    private static let date = Date(timeIntervalSince1970: 1_700_000_000)

    private static func series(_ id: String, library: String) -> KomgaSeries {
        KomgaSeries(
            id: KomgaSeriesId(id), libraryId: KomgaLibraryId(library), name: id, url: "/data/\(id)",
            booksCount: 1, booksReadCount: 0, booksUnreadCount: 1, booksInProgressCount: 0,
            metadata: KomgaSeriesMetadata(
                status: .ongoing, title: id, titleSort: id, publisher: "", language: "en", genres: [],
                tags: [], totalBookCount: nil),
            deleted: false, oneshot: false,
            booksMetadata: KomgaSeriesBookMetadata(
                authors: [], tags: [], releaseDate: nil, summary: "", summaryNumber: "", created: date,
                lastModified: date),
            created: date, lastModified: date, fileLastModified: date)
    }

    private static func book(_ id: String, in series: KomgaSeries) -> SplashBook {
        SplashBook(book: KomgaBook(
            id: KomgaBookId(id), seriesId: series.id, seriesTitle: series.metadata.title,
            libraryId: series.libraryId, name: id, url: "/data/\(id).cbz", number: 1,
            created: date, lastModified: date, fileLastModified: date, sizeBytes: 1, size: "",
            media: Media(
                status: .ready, mediaType: "application/zip", pagesCount: 1, comment: "",
                epubDivinaCompatible: false, epubIsKepub: false, mediaProfile: .divina),
            metadata: KomgaBookMetadata(
                title: id, summary: "", number: "1", numberSort: 1, releaseDate: nil, authors: [], tags: [],
                isbn: "", links: [], created: date, lastModified: date),
            readProgress: nil, deleted: false, fileHash: "", oneshot: false))
    }

    private static let libA = KomgaLibrary(id: KomgaLibraryId("lib-a"), name: "A", root: "/a", seriesCover: .first)
    private static let libB = KomgaLibrary(id: KomgaLibraryId("lib-b"), name: "B", root: "/b", seriesCover: .first)

    private static let s1 = series("s1", library: "lib-a")
    private static let s2 = series("s2", library: "lib-a")
    private static let s3 = series("s3", library: "lib-b")
    private static let b1 = book("b1", in: s1)
    private static let b2 = book("b2", in: s2)
    private static let b3 = book("b3", in: s3)

    private static func hiding(
        libraries: [String] = [], series hiddenSeries: [String] = [], books: [String] = []
    ) -> HiddenContent {
        var content = HiddenContent()
        content.libraries = Set(libraries.map(KomgaLibraryId.init))
        content.series = Set(hiddenSeries.map(KomgaSeriesId.init))
        content.books = Set(books.map(KomgaBookId.init))
        return content
    }

    // MARK: Nothing hidden

    @Test func emptyFilterChangesNothing() {
        let filter = HiddenContentFilter.disabled
        #expect(filter.isNoop)
        #expect(filter.seriesConditions.isEmpty)
        #expect(filter.bookConditions.isEmpty)
        #expect(filter.libraryAllowList(from: [Self.libA, Self.libB]) == nil)
        #expect(filter.visible([Self.s1, Self.s3]) == [Self.s1, Self.s3])
        #expect(filter.visible([Self.b1, Self.b3]) == [Self.b1, Self.b3])
    }

    // MARK: Inheritance — the crux of the feature

    @Test func hidingALibraryHidesItsSeriesAndBooks() {
        let filter = HiddenContentFilter(hidden: Self.hiding(libraries: ["lib-a"]))
        #expect(filter.isHidden(series: Self.s1))
        #expect(filter.isHidden(series: Self.s2))
        #expect(!filter.isHidden(series: Self.s3))
        // A book inherits through its series' library without the series itself being marked.
        #expect(filter.isHidden(book: Self.b1))
        #expect(!filter.isHidden(book: Self.b3))
    }

    @Test func hidingASeriesHidesItsBooksOnly() {
        let filter = HiddenContentFilter(hidden: Self.hiding(series: ["s1"]))
        #expect(filter.isHidden(series: Self.s1))
        #expect(filter.isHidden(book: Self.b1))
        // Same library, different series — untouched.
        #expect(!filter.isHidden(series: Self.s2))
        #expect(!filter.isHidden(book: Self.b2))
    }

    @Test func hidingABookLeavesItsSeriesVisible() {
        let filter = HiddenContentFilter(hidden: Self.hiding(books: ["b1"]))
        #expect(filter.isHidden(book: Self.b1))
        #expect(!filter.isHidden(series: Self.s1))
    }



    // MARK: Server-side conditions

    @Test func hiddenLibrariesBecomeNotEqualConditions() {
        let filter = HiddenContentFilter(hidden: Self.hiding(libraries: ["lib-a"]))
        #expect(filter.seriesConditions == [.libraryId(.isNotEqualTo(KomgaLibraryId("lib-a")))])
        #expect(filter.bookConditions == [.libraryId(.isNotEqualTo(KomgaLibraryId("lib-a")))])
    }

    @Test func hiddenSeriesAreExpressibleForBooksButNotForSeries() {
        let filter = HiddenContentFilter(hidden: Self.hiding(series: ["s1"]))
        // `SeriesCondition` has no id case, so this exclusion can only happen client-side.
        #expect(filter.seriesConditions.isEmpty)
        #expect(filter.bookConditions == [.seriesId(.isNotEqualTo(KomgaSeriesId("s1")))])
    }

    @Test func hiddenBooksAreNeverExpressibleServerSide() {
        let filter = HiddenContentFilter(hidden: Self.hiding(books: ["b1"]))
        #expect(filter.seriesConditions.isEmpty)
        #expect(filter.bookConditions.isEmpty)
    }


    // MARK: Allow-list

    @Test func allowListExcludesHiddenLibrariesAndIsNilWhenIdle() {
        let libraries = [Self.libA, Self.libB]
        #expect(HiddenContentFilter.disabled.libraryAllowList(from: libraries) == nil)

        let filter = HiddenContentFilter(hidden: Self.hiding(libraries: ["lib-a"]))
        #expect(filter.libraryAllowList(from: libraries) == [Self.libB.id])

        // A hidden *series* alone must not narrow the allow-list — that would silently drop whole libraries.
        let seriesOnly = HiddenContentFilter(hidden: Self.hiding(series: ["s1"]))
        #expect(seriesOnly.libraryAllowList(from: libraries) == nil)
    }


    // MARK: Count correction

    @Test func hiddenSeriesCountIgnoresSeriesInAlreadyExcludedLibraries() {
        let owners: [KomgaSeriesId: KomgaLibraryId] = [
            Self.s1.id: Self.libA.id, Self.s2.id: Self.libA.id, Self.s3.id: Self.libB.id,
        ]
        let filter = HiddenContentFilter(hidden: Self.hiding(libraries: ["lib-b"], series: ["s1", "s3"]))
        // s3 lives in a hidden library, so the server already excluded it — counting it again double-counts.
        #expect(filter.hiddenSeriesCount(inLibrary: nil) { owners[$0] } == 1)
        #expect(filter.hiddenSeriesCount(inLibrary: Self.libA.id) { owners[$0] } == 1)
        #expect(filter.hiddenSeriesCount(inLibrary: Self.libB.id) { owners[$0] } == 0)
    }

    // MARK: Multi-server guard

    @Test func hiddenSetOnlyAppliesToItsOwnServer() {
        var content = HiddenContent()
        content.serverUrl = "http://komga.home"
        #expect(content.applies(to: "http://komga.home"))
        #expect(!content.applies(to: "http://other.server"))
        // A set that has never recorded a server adopts whichever one is active.
        #expect(HiddenContent().applies(to: "http://anything"))
    }
}
