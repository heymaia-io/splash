import Foundation
import Testing
@testable import KomgaAPI
@testable import SplashCore

/// The private area folds individually hidden books into Home's carousels client-side, because Komga
/// has no book-id condition. These assert that the local predicate agrees with what each section's
/// server query asks for — a disagreement would file a finished book under "Keep reading".
@Suite struct HomeScreenFilterMatchingTests {
    private static let now = Date(timeIntervalSince1970: 1_700_000_000)

    private static func book(
        _ id: String, progress: ReadProgress? = nil, created: Date = now,
        releaseDate: KomgaLocalDate? = nil
    ) -> SplashBook {
        SplashBook(book: KomgaBook(
            id: KomgaBookId(id), seriesId: KomgaSeriesId("s1"), seriesTitle: "S",
            libraryId: KomgaLibraryId("lib"), name: id, url: "/\(id)", number: 1,
            created: created, lastModified: created, fileLastModified: created, sizeBytes: 1, size: "",
            media: Media(status: .ready, mediaType: "application/zip", pagesCount: 10, comment: "",
                         epubDivinaCompatible: false, epubIsKepub: false, mediaProfile: .divina),
            metadata: KomgaBookMetadata(
                title: id, summary: "", number: "1", numberSort: 1, releaseDate: releaseDate,
                authors: [], tags: [], isbn: "", links: [], created: created, lastModified: created),
            readProgress: progress, deleted: false, fileHash: "", oneshot: false))
    }

    private static func progress(completed: Bool, readDate: Date) -> ReadProgress {
        ReadProgress(page: 1, completed: completed, readDate: readDate, deviceId: "d", deviceName: "D",
                     created: readDate, lastModified: readDate)
    }

    private static var filters: [HomeScreenFilter] { HomeScreenFilter.defaults }
    private static func filter(_ label: String) -> HomeScreenFilter {
        filters.first { $0.label == String(localized: String.LocalizationValue(label)) } ?? filters[0]
    }

    @Test func keepReadingTakesInProgressOnly() {
        let section = Self.filter("Keep reading")
        let inProgress = Self.book("a", progress: Self.progress(completed: false, readDate: Self.now))
        let finished = Self.book("b", progress: Self.progress(completed: true, readDate: Self.now))
        let untouched = Self.book("c")

        #expect(section.matches(inProgress, now: Self.now) == true)
        #expect(section.matches(finished, now: Self.now) == false)
        #expect(section.matches(untouched, now: Self.now) == false)
    }

    @Test func recentlyReadTakesFinishedOnly() {
        let section = Self.filter("Recently read books")
        #expect(section.matches(Self.book("a", progress: Self.progress(completed: true, readDate: Self.now)),
                                now: Self.now) == true)
        #expect(section.matches(Self.book("b", progress: Self.progress(completed: false, readDate: Self.now)),
                                now: Self.now) == false)
    }

    @Test func recentlyReleasedRespectsTheThirtyDayWindow() {
        let section = Self.filter("Recently released books")
        let calendar = Calendar(identifier: .gregorian)
        let recent = calendar.dateComponents([.year, .month, .day], from: Self.now.addingTimeInterval(-5 * 86_400))
        let old = calendar.dateComponents([.year, .month, .day], from: Self.now.addingTimeInterval(-90 * 86_400))

        #expect(section.matches(
            Self.book("a", releaseDate: KomgaLocalDate(year: recent.year!, month: recent.month!, day: recent.day!)),
            now: Self.now) == true)
        #expect(section.matches(
            Self.book("b", releaseDate: KomgaLocalDate(year: old.year!, month: old.month!, day: old.day!)),
            now: Self.now) == false)
        // No release date at all must not slip into a date-windowed section.
        #expect(section.matches(Self.book("c"), now: Self.now) == false)
    }

    @Test func recentlyAddedTakesEverythingAndSortsByCreation() {
        let section = Self.filter("Recently added books")
        let older = Self.book("old", created: Self.now.addingTimeInterval(-86_400))
        let newer = Self.book("new", created: Self.now)
        #expect(section.matches(older, now: Self.now) == true)
        #expect(section.sorted([older, newer]).map(\.id) == [newer.id, older.id])
    }

    @Test func keepReadingSortsByMostRecentlyRead() {
        let section = Self.filter("Keep reading")
        let stale = Self.book("stale", progress: Self.progress(completed: false, readDate: Self.now.addingTimeInterval(-86_400)))
        let fresh = Self.book("fresh", progress: Self.progress(completed: false, readDate: Self.now))
        #expect(section.sorted([stale, fresh]).map(\.id) == [fresh.id, stale.id])
    }

    /// "On deck" is the server deciding which book comes next in a started series. Guessing at it
    /// locally would put the wrong book in the carousel, so it must stay unmergeable.
    @Test func onDeckIsNotDecidableOnTheClient() {
        #expect(Self.filter("On deck").matches(Self.book("a"), now: Self.now) == nil)
    }

    @Test func seriesSectionsOrderByAddedAndUpdated() {
        let first = KomgaSeriesFixture.make(id: "a", created: Self.now.addingTimeInterval(-86_400), lastModified: Self.now)
        let second = KomgaSeriesFixture.make(id: "b", created: Self.now, lastModified: Self.now.addingTimeInterval(-86_400))

        #expect(Self.filter("Recently added series").sorted([first, second]).map(\.id) == [second.id, first.id])
        #expect(Self.filter("Recently updated series").sorted([first, second]).map(\.id) == [first.id, second.id])
        #expect(Self.filter("Recently added series").matches(first, now: Self.now) == true)
    }
}

enum KomgaSeriesFixture {
    static func make(id: String, created: Date, lastModified: Date) -> KomgaSeries {
        KomgaSeries(
            id: KomgaSeriesId(id), libraryId: KomgaLibraryId("lib"), name: id, url: "/\(id)",
            booksCount: 1, booksReadCount: 0, booksUnreadCount: 1, booksInProgressCount: 0,
            metadata: KomgaSeriesMetadata(
                status: .ongoing, title: id, titleSort: id, publisher: "", language: "en", genres: [],
                tags: [], totalBookCount: nil),
            deleted: false, oneshot: false,
            booksMetadata: KomgaSeriesBookMetadata(
                authors: [], tags: [], releaseDate: nil, summary: "", summaryNumber: "",
                created: created, lastModified: lastModified),
            created: created, lastModified: lastModified, fileLastModified: created)
    }
}
