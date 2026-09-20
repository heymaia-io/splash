import Foundation
import KomgaAPI
import Testing
@testable import SplashUI

/// The download state of a book cannot be a Komga query condition — the server knows nothing about
/// downloads — so the series screen either asks the offline store or trims the page itself.
@Suite struct BookDownloadFilterTests {
    private static func book(_ id: String, downloaded: Bool) -> SplashBook {
        let date = Date(timeIntervalSince1970: 0)
        return SplashBook(
            book: KomgaBook(
                id: KomgaBookId(id), seriesId: "s1", seriesTitle: "Series", libraryId: "lib",
                name: id, url: "/data/\(id).cbz", number: 1, created: date, lastModified: date,
                fileLastModified: date, sizeBytes: 1, size: "",
                media: Media(
                    status: .ready, mediaType: "application/zip", pagesCount: 1, comment: "",
                    epubDivinaCompatible: false, epubIsKepub: false, mediaProfile: .divina),
                metadata: KomgaBookMetadata(
                    title: id, summary: "", number: "1", numberSort: 1, releaseDate: nil, authors: [],
                    tags: [], isbn: "", links: [], created: date, lastModified: date),
                readProgress: nil, deleted: false, fileHash: "", oneshot: false),
            downloaded: downloaded)
    }

    private static let mixed = [
        book("b1", downloaded: true), book("b2", downloaded: false), book("b3", downloaded: true),
    ]

    @Test func allKeepsEverything() {
        #expect(BookDownloadFilter.all.apply(to: Self.mixed) == Self.mixed)
    }

    @Test func downloadedKeepsOnlyDownloadedBooks() {
        #expect(BookDownloadFilter.downloaded.apply(to: Self.mixed).map(\.id)
            == [KomgaBookId("b1"), KomgaBookId("b3")])
    }

    @Test func notDownloadedIsTheExactComplement() {
        #expect(BookDownloadFilter.notDownloaded.apply(to: Self.mixed).map(\.id) == [KomgaBookId("b2")])
        // Every book lands in exactly one of the two.
        let downloaded = BookDownloadFilter.downloaded.apply(to: Self.mixed)
        let not = BookDownloadFilter.notDownloaded.apply(to: Self.mixed)
        #expect(downloaded.count + not.count == Self.mixed.count)
        #expect(Set(downloaded.map(\.id)).isDisjoint(with: Set(not.map(\.id))))
    }

    /// Only `.downloaded` can be answered exactly by the offline store; the other two need the full list,
    /// which only the active API has.
    @Test func onlyDownloadedReadsTheOfflineStore() {
        #expect(BookDownloadFilter.downloaded.isAnsweredByOfflineStore)
        #expect(!BookDownloadFilter.all.isAnsweredByOfflineStore)
        #expect(!BookDownloadFilter.notDownloaded.isAnsweredByOfflineStore)
    }

    /// `apply` must still work for `.downloaded`, because previews and tests supply no offline store and the
    /// screen falls back to trimming remote results. Silently showing everything would be worse.
    @Test func downloadedStillFiltersWithoutAnOfflineStore() {
        let kept = BookDownloadFilter.downloaded.apply(to: Self.mixed)
        #expect(kept.count == 2)
        #expect(kept.filter(\.downloaded).count == kept.count)
    }

    @Test func everyCaseIsOfferedInThePicker() {
        #expect(BookDownloadFilter.allCases == [.all, .downloaded, .notDownloaded])
    }
}
