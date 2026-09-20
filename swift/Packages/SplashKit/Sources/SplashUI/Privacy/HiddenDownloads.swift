import KomgaAPI
import SplashCore
import SplashOffline

extension HiddenContentFilter {
    /// Filters download rows, which carry the book's **title** and so leak as readily as any listing —
    /// in the Downloads tab, the in-flight transfers and the Settings list alike.
    ///
    /// `BookDownload` records a book id and, once metadata arrives, a series id — but never a library id,
    /// so the series → library link has to be supplied. Lives here rather than in `SplashCore` because
    /// `BookDownload` belongs to `SplashOffline`, which `SplashCore` does not depend on.
    ///
    /// A download whose `seriesId` is still nil has no `bookTitle` either — both are written in the same
    /// update once the metadata is known — so it shows only an id and reveals nothing. Keeping it visible is
    /// therefore safe, and avoids a queued download vanishing from the user's own list.
    func visible(
        _ downloads: [BookDownload], seriesLibraries: [KomgaSeriesId: KomgaLibraryId]
    ) -> [BookDownload] {
        guard !isNoop else { return downloads }
        return downloads.filter { download in
            if hidden.books.contains(download.bookId) { return false }
            guard let seriesId = download.seriesId else { return true }
            if hidden.series.contains(seriesId) { return false }
            return !isHidden(libraryId: seriesLibraries[seriesId])
        }
    }
}
