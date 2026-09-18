import Foundation
import KomgaAPI

/// Decides what a screen may show.
///
/// [NUEVO] One forgotten listing defeats the whole feature, so all the reasoning lives here as pure functions
/// and every call site stays a one-line `filter.visible(...)` that review can verify by eye. The alternative
/// — a `KomgaApi` decorator — was rejected: `KomgaBookApi` and `KomgaSeriesApi` alone would need ~120
/// forwarding stubs, and filtering in the view models covers the offline `KomgaApi` for free.
///
/// Server-side conditions are an **optimisation, never the guard**. Komga can exclude by library id (on both
/// series and book queries) and by series id (on book queries only); it has no id condition for a series in a
/// series query or a book in a book query. `visible(_:)` is therefore applied to every result unconditionally.
public struct HiddenContentFilter: Sendable, Equatable {
    public let hidden: HiddenContent

    /// Shows everything — used while the private area is unlocked, and wherever privacy is not configured.
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

    /// Hiding a library hides its series.
    public func isHidden(series: KomgaSeries) -> Bool {
        hidden.series.contains(series.id) || isHidden(libraryId: series.libraryId)
    }

    /// Hiding a library hides its books; hiding a series hides its books. `SplashBook` carries both ids
    /// (through `KomgaBook`), so this is decidable locally with no extra fetches.
    public func isHidden(book: SplashBook) -> Bool {
        hidden.books.contains(book.id)
            || hidden.series.contains(book.seriesId)
            || isHidden(libraryId: book.libraryId)
    }

    // MARK: - Client-side filtering (the guard)

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

    /// Library scoping for series queries. `SeriesCondition` has no id case, so an individually hidden series
    /// is not expressible here — `visible(_:)` removes it instead.
    public var seriesConditions: [SeriesCondition] {
        hidden.libraries.sorted { $0.rawValue < $1.rawValue }.map { .libraryId(.isNotEqualTo($0)) }
    }

    /// Book queries can additionally exclude whole series, which makes book pagination exact wherever the
    /// only hidden things in scope are libraries and series.
    public var bookConditions: [BookCondition] {
        hidden.libraries.sorted { $0.rawValue < $1.rawValue }.map { .libraryId(.isNotEqualTo($0)) }
            + hidden.series.sorted { $0.rawValue < $1.rawValue }.map { .seriesId(.isNotEqualTo($0)) }
    }

    /// ANDs the exclusions onto a query's existing condition.
    ///
    /// Returns the original untouched when nothing is excluded, so a user who never hides anything keeps
    /// byte-identical requests — including `nil`, which is what the screens pass today.
    public func combined(_ condition: BookCondition?) -> BookCondition? {
        let exclusions = bookConditions
        guard !exclusions.isEmpty else { return condition }
        return .allOf(condition.map { [$0] + exclusions } ?? exclusions)
    }

    public func combined(_ condition: SeriesCondition?) -> SeriesCondition? {
        let exclusions = seriesConditions
        guard !exclusions.isEmpty else { return condition }
        return .allOf(condition.map { [$0] + exclusions } ?? exclusions)
    }

    /// For the endpoints that take no condition at all (`getBooksOnDeck`, `getNewSeries`, `getUpdatedSeries`,
    /// and the collection / read-list `getAll`) — an allow-list of library ids.
    ///
    /// Returns `nil` when nothing would be excluded, so the request stays byte-identical to today's for every
    /// user who never hides anything.
    public func libraryAllowList(from all: [KomgaLibrary]) -> [KomgaLibraryId]? {
        guard !hidden.libraries.isEmpty else { return nil }
        return all.map(\.id).filter { !hidden.libraries.contains($0) }
    }
}
