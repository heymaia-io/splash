import Foundation
import KomgaAPI
import Testing
@testable import SplashCore

/// The filter is where every chokepoint's correctness actually lives — each call site is one line, so this is
/// where the inheritance rules and the wire shape of the server-side conditions are pinned down.
@Suite struct HiddenContentFilterTests {
    // MARK: - Fixtures

    private static let libraryA = KomgaLibraryId("lib-a")
    private static let libraryB = KomgaLibraryId("lib-b")

    private static func library(_ id: KomgaLibraryId) -> KomgaLibrary {
        KomgaLibrary(id: id, name: id.rawValue, root: "/data/\(id.rawValue)")
    }

    private static func series(_ id: String, in libraryId: KomgaLibraryId) -> KomgaSeries {
        let date = Date(timeIntervalSince1970: 0)
        return KomgaSeries(
            id: KomgaSeriesId(id), libraryId: libraryId, name: id, url: "/data/\(id)",
            booksCount: 1, booksReadCount: 0, booksUnreadCount: 1, booksInProgressCount: 0,
            metadata: KomgaSeriesMetadata(status: .ongoing, title: id, titleSort: id),
            deleted: false, oneshot: false,
            booksMetadata: KomgaSeriesBookMetadata(
                authors: [], tags: [], releaseDate: nil, summary: "", summaryNumber: "",
                created: date, lastModified: date),
            created: date, lastModified: date, fileLastModified: date)
    }

    private static func book(_ id: String, in series: KomgaSeries) -> SplashBook {
        let date = Date(timeIntervalSince1970: 0)
        return SplashBook(book: KomgaBook(
            id: KomgaBookId(id), seriesId: series.id, seriesTitle: series.name, libraryId: series.libraryId,
            name: id, url: "/data/\(id).cbz", number: 1, created: date, lastModified: date,
            fileLastModified: date, sizeBytes: 1, size: "",
            media: Media(
                status: .ready, mediaType: "application/zip", pagesCount: 1, comment: "",
                epubDivinaCompatible: false, epubIsKepub: false, mediaProfile: .divina),
            metadata: KomgaBookMetadata(
                title: id, summary: "", number: "1", numberSort: 1, releaseDate: nil, authors: [], tags: [],
                isbn: "", links: [], created: date, lastModified: date),
            readProgress: nil, deleted: false, fileHash: "", oneshot: false))
    }

    private static func filter(
        libraries: Set<KomgaLibraryId> = [], series: Set<KomgaSeriesId> = [], books: Set<KomgaBookId> = []
    ) -> HiddenContentFilter {
        var hidden = HiddenContent()
        hidden.libraries = libraries
        hidden.series = series
        hidden.books = books
        return HiddenContentFilter(hidden: hidden)
    }

    // MARK: - Inheritance

    @Test func hidingALibraryHidesItsSeriesAndBooks() {
        let series = Self.series("s1", in: Self.libraryA)
        let book = Self.book("b1", in: series)
        let filter = Self.filter(libraries: [Self.libraryA])

        #expect(filter.isHidden(libraryId: Self.libraryA))
        #expect(filter.isHidden(series: series))
        #expect(filter.isHidden(book: book))
    }

    @Test func hidingASeriesHidesItsBooksButNotItsLibrary() {
        let series = Self.series("s1", in: Self.libraryA)
        let book = Self.book("b1", in: series)
        let filter = Self.filter(series: [series.id])

        #expect(!filter.isHidden(libraryId: Self.libraryA))
        #expect(filter.isHidden(series: series))
        #expect(filter.isHidden(book: book))
    }

    @Test func hidingABookHidesNothingElse() {
        let series = Self.series("s1", in: Self.libraryA)
        let hiddenBook = Self.book("b1", in: series)
        let siblingBook = Self.book("b2", in: series)
        let filter = Self.filter(books: [hiddenBook.id])

        #expect(filter.isHidden(book: hiddenBook))
        #expect(!filter.isHidden(book: siblingBook))
        #expect(!filter.isHidden(series: series))
        #expect(!filter.isHidden(libraryId: Self.libraryA))
    }

    @Test func inheritanceDoesNotLeakAcrossLibraries() {
        let inA = Self.series("s1", in: Self.libraryA)
        let inB = Self.series("s2", in: Self.libraryB)
        let filter = Self.filter(libraries: [Self.libraryA])

        #expect(filter.isHidden(series: inA))
        #expect(!filter.isHidden(series: inB))
        #expect(!filter.isHidden(book: Self.book("b2", in: inB)))
    }

    @Test func aNilLibraryIdIsNeverHidden() {
        #expect(!Self.filter(libraries: [Self.libraryA]).isHidden(libraryId: nil))
    }

    // MARK: - visible(_:)

    @Test func visibleRemovesEachKindAndKeepsTheRest() {
        let visibleSeries = Self.series("s1", in: Self.libraryB)
        let hiddenSeries = Self.series("s2", in: Self.libraryB)
        let inHiddenLibrary = Self.series("s3", in: Self.libraryA)
        let filter = Self.filter(libraries: [Self.libraryA], series: [hiddenSeries.id])

        #expect(filter.visible([visibleSeries, hiddenSeries, inHiddenLibrary]) == [visibleSeries])
        #expect(filter.visible([Self.library(Self.libraryA), Self.library(Self.libraryB)])
            == [Self.library(Self.libraryB)])

        let kept = Self.book("b1", in: visibleSeries)
        let dropped = Self.book("b2", in: hiddenSeries)
        #expect(filter.visible([kept, dropped]) == [kept])
    }

    @Test func disabledShowsEverything() {
        let series = Self.series("s1", in: Self.libraryA)
        let filter = HiddenContentFilter.disabled

        #expect(filter.isNoop)
        #expect(!filter.isHidden(series: series))
        #expect(filter.visible([series]) == [series])
        #expect(filter.seriesConditions.isEmpty)
        #expect(filter.bookConditions.isEmpty)
    }

    // MARK: - Server-side conditions

    /// `SeriesCondition` has no id case, so an individually hidden series is *not* expressible server-side —
    /// this is exactly why `visible(_:)` is the guard and conditions are only an optimisation.
    @Test func seriesConditionsCoverLibrariesOnly() {
        let filter = Self.filter(libraries: [Self.libraryA], series: [KomgaSeriesId("s1")])
        #expect(filter.seriesConditions == [.libraryId(.isNotEqualTo(Self.libraryA))])
    }

    @Test func bookConditionsCoverLibrariesAndSeries() {
        let filter = Self.filter(
            libraries: [Self.libraryA], series: [KomgaSeriesId("s1")], books: [KomgaBookId("b1")])
        #expect(filter.bookConditions == [
            .libraryId(.isNotEqualTo(Self.libraryA)),
            .seriesId(.isNotEqualTo(KomgaSeriesId("s1"))),
        ])
    }

    @Test func conditionsEncodeToTheKomgaWireShape() throws {
        let filter = Self.filter(libraries: [Self.libraryA], series: [KomgaSeriesId("s1")])

        let seriesJson = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(filter.seriesConditions)) as? [[String: Any]]
        #expect(seriesJson?.count == 1)
        let libraryOp = seriesJson?.first?["libraryId"] as? [String: Any]
        #expect(libraryOp?["operator"] as? String == "isNot")
        #expect(libraryOp?["value"] as? String == "lib-a")

        let bookJson = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(filter.bookConditions)) as? [[String: Any]]
        #expect(bookJson?.count == 2)
        let seriesOp = bookJson?.last?["seriesId"] as? [String: Any]
        #expect(seriesOp?["operator"] as? String == "isNot")
        #expect(seriesOp?["value"] as? String == "s1")
    }

    /// Ordering is fixed so the emitted request is stable across launches (`Set` iteration is not).
    @Test func conditionOrderIsDeterministic() {
        let filter = Self.filter(libraries: [KomgaLibraryId("z"), KomgaLibraryId("a"), KomgaLibraryId("m")])
        #expect(filter.seriesConditions == [
            .libraryId(.isNotEqualTo(KomgaLibraryId("a"))),
            .libraryId(.isNotEqualTo(KomgaLibraryId("m"))),
            .libraryId(.isNotEqualTo(KomgaLibraryId("z"))),
        ])
    }

    // MARK: - combined(_:)

    @Test func combinedLeavesTheQueryUntouchedWhenNothingIsExcluded() {
        // The fast path every user who never hides anything stays on.
        #expect(Self.filter().combined(nil as BookCondition?) == nil)
        #expect(Self.filter().combined(nil as SeriesCondition?) == nil)

        let existing = BookCondition.readStatus(.isEqualTo(.unread))
        #expect(Self.filter().combined(existing) == existing)
        // A hidden *book* is not expressible server-side, so it must not perturb the query either.
        #expect(Self.filter(books: [KomgaBookId("b1")]).combined(existing) == existing)
    }

    @Test func combinedAndsExclusionsOntoAnExistingCondition() {
        let filter = Self.filter(libraries: [Self.libraryA])
        let existing = BookCondition.readStatus(.isEqualTo(.unread))
        #expect(filter.combined(existing)
            == .allOf([existing, .libraryId(.isNotEqualTo(Self.libraryA))]))

        let existingSeries = SeriesCondition.oneShot(.isFalse)
        #expect(filter.combined(existingSeries)
            == .allOf([existingSeries, .libraryId(.isNotEqualTo(Self.libraryA))]))
    }

    @Test func combinedBuildsAConditionWhenTheQueryHadNone() {
        let filter = Self.filter(libraries: [Self.libraryA], series: [KomgaSeriesId("s1")])
        #expect(filter.combined(nil as SeriesCondition?)
            == .allOf([.libraryId(.isNotEqualTo(Self.libraryA))]))
        #expect(filter.combined(nil as BookCondition?)
            == .allOf([.libraryId(.isNotEqualTo(Self.libraryA)), .seriesId(.isNotEqualTo(KomgaSeriesId("s1")))]))
    }

    // MARK: - libraryAllowList

    @Test func libraryAllowListIsNilWhenNoLibraryIsHidden() {
        let all = [Self.library(Self.libraryA), Self.library(Self.libraryB)]
        // nil keeps the request byte-identical for every user who never hides anything.
        #expect(Self.filter().libraryAllowList(from: all) == nil)
        // A hidden *series* still cannot be expressed as a library allow-list.
        #expect(Self.filter(series: [KomgaSeriesId("s1")]).libraryAllowList(from: all) == nil)
    }

    @Test func libraryAllowListExcludesHiddenLibraries() {
        let all = [Self.library(Self.libraryA), Self.library(Self.libraryB)]
        #expect(Self.filter(libraries: [Self.libraryA]).libraryAllowList(from: all) == [Self.libraryB])
    }

    /// Hiding every library yields an empty allow-list, not `nil` — "show nothing" must not read as
    /// "show everything".
    @Test func hidingEveryLibraryYieldsAnEmptyAllowList() {
        let all = [Self.library(Self.libraryA), Self.library(Self.libraryB)]
        #expect(Self.filter(libraries: [Self.libraryA, Self.libraryB]).libraryAllowList(from: all) == [])
    }
}
