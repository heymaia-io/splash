import Foundation
import KomgaAPI

/// Decides what a screen may show.
///
/// A leak in one forgotten listing defeats the whole feature, so all the reasoning lives here as pure
/// functions and every call site is a one-line `filter.visible(...)` that review can verify by eye.
/// The alternative — a `KomgaApi` decorator — was rejected: `KomgaBookApi` and `KomgaSeriesApi` alone
/// would need ~120 forwarding stubs.
///
/// Server-side conditions are an *optimisation*, never the guard: Komga can exclude by library id
/// (series and books) and by series id (books only), but has no id condition for series-in-series-lists
/// or books-in-book-lists. `visible(_:)` is therefore applied unconditionally to every result.
public struct HiddenContentFilter: Sendable, Equatable {
    public let hidden: HiddenContent

    /// Shows everything — used while the private area is unlocked, when the feature is unpurchased, or
    /// when the stored set belongs to another server.
    public static let disabled = HiddenContentFilter(hidden: HiddenContent())

    public init(hidden: HiddenContent) {
        self.hidden = hidden
    }

    /// True when this filter would change nothing, so call sites can keep the untouched fast path.
    public var isNoop: Bool { hidden.isEmpty }

    // MARK: - Predicates (inheritance lives here)

    public func isHidden(libraryId: KomgaLibraryId?) -> Bool {
        guard let libraryId else { return false }
        return hidden.libraries.contains(libraryId)
    }

    public func isHidden(series: KomgaSeries) -> Bool {
        hidden.series.contains(series.id) || isHidden(libraryId: series.libraryId)
    }

    public func isHidden(book: SplashBook) -> Bool {
        hidden.books.contains(book.id)
            || hidden.series.contains(book.seriesId)
            || isHidden(libraryId: book.libraryId)
    }

    // MARK: - Client-side filtering

    public func visible(_ libraries: [KomgaLibrary]) -> [KomgaLibrary] {
        libraries.filter { !hidden.libraries.contains($0.id) }
    }

    public func visible(_ series: [KomgaSeries]) -> [KomgaSeries] {
        series.filter { !isHidden(series: $0) }
    }

    public func visible(_ books: [SplashBook]) -> [SplashBook] {
        books.filter { !isHidden(book: $0) }
    }

    // MARK: - Server-side conditions (optimisation only)

    /// Library scoping for series queries. Komga has no series-id condition, so individually hidden
    /// series are not expressible here and are removed by `visible(_:)` instead.
    public var seriesConditions: [SeriesCondition] {
        hidden.libraries.map { SeriesCondition.libraryId(.isNotEqualTo($0)) }
    }

    /// Book queries can additionally exclude whole series, which makes book pagination exact.
    public var bookConditions: [BookCondition] {
        hidden.libraries.map { BookCondition.libraryId(.isNotEqualTo($0)) }
            + hidden.series.map { BookCondition.seriesId(.isNotEqualTo($0)) }
    }

    /// For the endpoints that take no condition at all (`getNewSeries`, `getUpdatedSeries`,
    /// `getBooksOnDeck`) — an allow-list of library ids.
    ///
    /// Returns `nil` when nothing would be excluded so the request stays byte-identical to today's for
    /// every user who never touches this feature.
    public func libraryAllowList(from all: [KomgaLibrary]) -> [KomgaLibraryId]? {
        guard !hidden.libraries.isEmpty else { return nil }
        return all.map(\.id).filter { !hidden.libraries.contains($0) }
    }

    /// How many *individually* hidden series fall in a scope — used to correct displayed totals, since
    /// the server still counts them (see `LibraryViewModel.loadSeriesPage`).
    public func hiddenSeriesCount(inLibrary libraryId: KomgaLibraryId?, resolving libraryOf: (KomgaSeriesId) -> KomgaLibraryId?) -> Int {
        hidden.series.count { seriesId in
            guard let owner = libraryOf(seriesId) else { return false }
            guard !hidden.libraries.contains(owner) else { return false }  // already excluded server-side
            return libraryId == nil || owner == libraryId
        }
    }
}
