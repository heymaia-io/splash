import Foundation
import SplashCore
import KomgaAPI
import Observation

/// Home's shelves, sourced from private content.
///
/// Necessarily a hybrid, because of one hard limit in Komga's query language:
///
/// - Content inside a hidden **library**, and books inside a hidden **series**, *are* expressible as
///   search conditions, so those come back from the same queries Home runs — correctly paged and sorted
///   by the server. That is the part that scales.
/// - An individually hidden **series** or **book** is not expressible at all (`SeriesCondition` and
///   `BookCondition` have no id case). Those are resolved by id and folded into the right shelf here,
///   using `HomeScreenFilter.matches(_:)` to reproduce what each section's query asks for.
@MainActor
@Observable
public final class PrivateHomeViewModel {
    public private(set) var sections: [HomeViewModel.Section] = []
    public private(set) var libraries: [KomgaLibrary] = []
    public private(set) var state: LoadState<Void> = .uninitialized
    public var activeFilter = 0

    private let api: any KomgaApi
    private let filters: HomeScreenFilterRepository
    private let authState: KomgaAuthenticationState
    private let catalog: PrivateCatalogViewModel
    private let hiddenFilter: @MainActor () -> HiddenContentFilter
    private let hiddenChanges: () -> AsyncStream<HiddenContent>
    private var hiddenTask: Task<Void, Never>?

    init(
        api: any KomgaApi, filters: HomeScreenFilterRepository, authState: KomgaAuthenticationState,
        catalog: PrivateCatalogViewModel,
        hiddenFilter: @escaping @MainActor () -> HiddenContentFilter,
        hiddenChanges: @escaping () -> AsyncStream<HiddenContent>
    ) {
        self.api = api
        self.filters = filters
        self.authState = authState
        self.catalog = catalog
        self.hiddenFilter = hiddenFilter
        self.hiddenChanges = hiddenChanges
    }

    public var isEmpty: Bool { libraries.isEmpty && sections.allSatisfy(\.isEmpty) }

    public func start() {
        guard hiddenTask == nil else { return }
        catalog.start()
        hiddenTask = Task { [weak self] in
            var isFirst = true  // `values()` replays the current value
            for await _ in self?.hiddenChanges() ?? .init(unfolding: { nil }) {
                if isFirst { isFirst = false; continue }
                await self?.load()
            }
        }
    }

    public func stop() {
        hiddenTask?.cancel()
        hiddenTask = nil
        catalog.stop()
    }

    public func load() async {
        state = .loading
        let hidden = hiddenFilter()
        libraries = hidden.visible(authState.libraries)

        async let catalogLoad: Void = catalog.load()
        let sectionFilters = filters.value
        do {
            async let served = HomeViewModel.fetchAll(
                sectionFilters, api: api, hidden: hidden, libraries: authState.libraries)
            let fetched = try await served
            _ = await catalogLoad
            sections = merge(fetched, with: catalog).sorted { $0.filter.order < $1.filter.order }
            state = .success(())
        } catch {
            _ = await catalogLoad
            // The server half failing must not hide what we *can* show: fall back to catalog-only shelves.
            sections = merge([], with: catalog).sorted { $0.filter.order < $1.filter.order }
            state = sections.allSatisfy(\.isEmpty) ? .error(error) : .success(())
        }
    }

    /// Folds individually hidden items into the shelves the server produced, deduplicated by id and
    /// capped at the section's own page size.
    private func merge(
        _ served: [HomeViewModel.Section], with catalog: PrivateCatalogViewModel
    ) -> [HomeViewModel.Section] {
        let now = Date()
        var byOrder = Dictionary(uniqueKeysWithValues: served.map { ($0.filter.order, $0) })

        for filter in filters.value {
            let existing = byOrder[filter.order]
            if filter.isBookFilter {
                var books = existing.flatMap { section -> [SplashBook]? in
                    if case .books(_, let b) = section { return b } else { return nil }
                } ?? []
                let extra = catalog.books.filter { book in
                    filter.matches(book, now: now) == true && !books.contains { $0.id == book.id }
                }
                guard existing != nil || !extra.isEmpty else { continue }
                books = Array(filter.sorted(books + extra).prefix(filter.mergeLimit))
                byOrder[filter.order] = .books(filter, books)
            } else {
                var series = existing.flatMap { section -> [KomgaSeries]? in
                    if case .series(_, let s) = section { return s } else { return nil }
                } ?? []
                let extra = catalog.series.filter { item in
                    filter.matches(item, now: now) == true && !series.contains { $0.id == item.id }
                }
                guard existing != nil || !extra.isEmpty else { continue }
                series = Array(filter.sorted(series + extra).prefix(filter.mergeLimit))
                byOrder[filter.order] = .series(filter, series)
            }
        }
        return Array(byOrder.values)
    }
}
