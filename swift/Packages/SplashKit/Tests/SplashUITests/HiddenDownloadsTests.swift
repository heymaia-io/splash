import KomgaAPI
import SplashCore
import SplashOffline
import Testing
@testable import SplashUI

/// Download rows show the book title, so they are a listing in every way that matters. They are also the one
/// place where the filter cannot read the object's own `libraryId`, because `BookDownload` has none.
@Suite struct HiddenDownloadsTests {
    private static let libraryA = KomgaLibraryId("lib-a")
    private static let seriesA = KomgaSeriesId("s-a")
    private static let seriesB = KomgaSeriesId("s-b")

    private static let seriesLibraries: [KomgaSeriesId: KomgaLibraryId] = [
        seriesA: libraryA,
        seriesB: KomgaLibraryId("lib-b"),
    ]

    private static func download(
        _ id: String, series: KomgaSeriesId?, title: String? = "Title"
    ) -> BookDownload {
        BookDownload(bookId: KomgaBookId(id), status: .complete, bookTitle: title, seriesId: series)
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

    @Test func nothingHiddenKeepsEveryRow() {
        let all = [Self.download("b1", series: Self.seriesA), Self.download("b2", series: Self.seriesB)]
        #expect(Self.filter().visible(all, seriesLibraries: Self.seriesLibraries) == all)
    }

    @Test func hidingABookDropsItsRow() {
        let hidden = Self.download("b1", series: Self.seriesA)
        let kept = Self.download("b2", series: Self.seriesB)
        #expect(Self.filter(books: [hidden.bookId]).visible([hidden, kept], seriesLibraries: Self.seriesLibraries)
            == [kept])
    }

    @Test func hidingASeriesDropsItsDownloads() {
        let hidden = Self.download("b1", series: Self.seriesA)
        let kept = Self.download("b2", series: Self.seriesB)
        #expect(Self.filter(series: [Self.seriesA]).visible([hidden, kept], seriesLibraries: Self.seriesLibraries)
            == [kept])
    }

    /// The case the download record cannot answer on its own — resolved through the series → library map.
    @Test func hidingALibraryDropsDownloadsFromIt() {
        let hidden = Self.download("b1", series: Self.seriesA)
        let kept = Self.download("b2", series: Self.seriesB)
        #expect(Self.filter(libraries: [Self.libraryA]).visible([hidden, kept], seriesLibraries: Self.seriesLibraries)
            == [kept])
    }

    /// Without the map the library case is simply unresolvable, so it must fail *visible* rather than
    /// pretend: the row shows a title either way, and this pins that the map is what closes the gap.
    @Test func anUnresolvableSeriesIsNotDroppedByLibrary() {
        let unknown = Self.download("b1", series: KomgaSeriesId("s-unknown"))
        #expect(Self.filter(libraries: [Self.libraryA]).visible([unknown], seriesLibraries: Self.seriesLibraries)
            == [unknown])
    }

    /// A download with no series yet also has no title yet — both are written together once metadata
    /// arrives — so it reveals nothing and stays, rather than vanishing from the user's own queue.
    @Test func aDownloadWithoutMetadataStays() {
        let queued = Self.download("b1", series: nil, title: nil)
        #expect(Self.filter(libraries: [Self.libraryA], series: [Self.seriesA])
            .visible([queued], seriesLibraries: Self.seriesLibraries) == [queued])
    }
}
