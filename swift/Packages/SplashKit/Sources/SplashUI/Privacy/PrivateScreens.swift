import SplashCore
import KomgaAPI
import Observation
import SwiftUI

/// Resolves the hidden ids into real objects.
///
/// The private root cannot query a list endpoint: Komga has no "id is one of" condition for series or
/// books, so there is no search that returns exactly the hidden set. It fetches each id instead, which is
/// fine for a user-curated set of tens to hundreds. Past roughly a thousand items this wants a real index.
@MainActor
@Observable
public final class PrivateCatalogViewModel {
    public private(set) var libraries: [KomgaLibrary] = []
    public private(set) var series: [KomgaSeries] = []
    public private(set) var books: [SplashBook] = []
    public private(set) var state: LoadState<Void> = .uninitialized

    private let api: any KomgaApi
    private let authState: KomgaAuthenticationState
    private let hiddenFilter: @MainActor () -> HiddenContentFilter
    private let hiddenChanges: () -> AsyncStream<HiddenContent>
    private var hiddenTask: Task<Void, Never>?

    init(
        api: any KomgaApi, authState: KomgaAuthenticationState,
        hiddenFilter: @escaping @MainActor () -> HiddenContentFilter,
        hiddenChanges: @escaping () -> AsyncStream<HiddenContent>
    ) {
        self.api = api
        self.authState = authState
        self.hiddenFilter = hiddenFilter
        self.hiddenChanges = hiddenChanges
    }

    public var isEmpty: Bool { libraries.isEmpty && series.isEmpty && books.isEmpty }

    /// Watches the stored set so unhiding something from this very screen removes the card straight away,
    /// instead of leaving it there until the tab is rebuilt.
    public func start() {
        guard hiddenTask == nil else { return }
        hiddenTask = Task { [weak self] in
            var isFirst = true  // `values()` replays the current value
            for await hidden in self?.hiddenChanges() ?? .init(unfolding: { nil }) {
                if isFirst { isFirst = false; continue }
                await self?.apply(hidden)
            }
        }
    }

    public func stop() {
        hiddenTask?.cancel()
        hiddenTask = nil
    }

    /// Drops what is no longer private without a round trip — the card disappears on the same frame as the
    /// tap — and only goes back to the server when something newly private needs resolving.
    private func apply(_ hidden: HiddenContent) async {
        libraries.removeAll { !hidden.libraries.contains($0.id) }
        series.removeAll { !hidden.series.contains($0.id) }
        books.removeAll { !hidden.books.contains($0.id) }

        let needsSeries = !hidden.series.subtracting(series.map(\.id)).isEmpty
        let needsBooks = !hidden.books.subtracting(books.map(\.id)).isEmpty
        let needsLibraries = libraries.count != hidden.libraries.count
        guard needsSeries || needsBooks || needsLibraries else { return }
        await load()
    }

    public func load() async {
        let hidden = hiddenFilter().hidden
        state = .loading
        libraries = authState.libraries.filter { hidden.libraries.contains($0.id) }
        async let series = Self.resolve(hidden.series, concurrency: 6) { [api] in
            try await api.seriesApi.getOneSeries($0)
        }
        async let books = Self.resolve(hidden.books, concurrency: 6) { [api] in
            try await api.bookApi.getOne($0)
        }
        self.series = await series.sorted { $0.metadata.titleSort < $1.metadata.titleSort }
        self.books = await books.sorted { $0.metadata.title < $1.metadata.title }
        state = .success(())
    }

    /// Ids that fail to resolve (deleted on the server, or simply unreachable) are dropped from the
    /// display but deliberately left in the stored set: a server hiccup must never silently unhide
    /// something, and a re-added series must come back still hidden.
    private nonisolated static func resolve<ID: Sendable & Hashable, Value: Sendable>(
        _ ids: Set<ID>, concurrency: Int, fetch: @escaping @Sendable (ID) async throws -> Value
    ) async -> [Value] {
        await withTaskGroup(of: Value?.self) { group in
            var pending = Array(ids)
            var running = 0
            var results: [Value] = []
            while !pending.isEmpty || running > 0 {
                while running < concurrency, let id = pending.popLast() {
                    group.addTask { try? await fetch(id) }
                    running += 1
                }
                if let value = await group.next() {
                    running -= 1
                    if let value { results.append(value) }
                }
            }
            return results
        }
    }
}

/// The private area's root. Reads like Home — the same shelves, the same covers — because private
/// content is a mix of whole libraries, whole series and single books, and a flat grid buried the
/// difference. Hidden libraries stay a row list above the shelves: a carousel cannot represent a
/// library, and it is the one part that scales through real server-side paging.
struct PrivateHomeScreen: View {
    @State var model: PrivateHomeViewModel
    let cardWidth: CGFloat
    let navigate: (Destination) -> Void

    var body: some View {
        Group {
            switch model.state {
            case .uninitialized:
                ProgressView()
            case .error(let error) where model.isEmpty:
                ErrorView(error: error) { Task { await model.load() } }
            default:
                if model.isEmpty, !model.state.isLoading {
                    ContentUnavailableView(
                        "Nothing is private yet", systemImage: "eye.slash",
                        description: Text("Use Hide on a library, a series or a book to keep it here."))
                } else {
                    content
                }
            }
        }
        .navigationTitle("Private")
        .task {
            model.start()
            if model.state.isUninitialized { await model.load() }
        }
        .onDisappear { model.stop() }
        .refreshable { await model.load() }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if !model.libraries.isEmpty { librariesBar }
            SectionCarousels(
                sections: model.sections, activeFilter: $model.activeFilter, cardWidth: cardWidth,
                isLoading: model.state.isLoading, navigate: navigate,
                cardMenu: { destination in
                    switch destination {
                    case .series(let id): HideMenuButton(target: .series(id))
                    case .book(let id): HideMenuButton(target: .book(id, isDownloaded: false))
                    default: EmptyView()
                    }
                })
        }
    }

    private var librariesBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Libraries").font(.title3.bold()).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.libraries) { library in
                        Button { navigate(.privateLibrary(library.id)) } label: {
                            Label(library.name, systemImage: "books.vertical")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .contextMenu { HideMenuButton(target: .library(library.id)) }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 12)
    }
}

/// Search scoped to the private set.
///
/// Two halves, because Komga can express only one of them. A server query with the `.onlyHidden`
/// conditions reaches everything inside a hidden **library** and every book of a hidden **series** —
/// the part that scales. An individually hidden series or book has no id condition, so it is matched
/// in memory against the resolved catalog. Without the first half, a user whose private content is one
/// whole library got no results at all.
@MainActor
@Observable
public final class PrivateSearchViewModel {
    public var query: String
    public private(set) var series: [KomgaSeries] = []
    public private(set) var books: [SplashBook] = []
    public private(set) var state: LoadState<Void> = .uninitialized

    private let api: any KomgaApi
    private let catalog: PrivateCatalogViewModel
    private let hiddenFilter: @MainActor () -> HiddenContentFilter
    private var searchTask: Task<Void, Never>?

    init(
        api: any KomgaApi, catalog: PrivateCatalogViewModel, initialQuery: String,
        hiddenFilter: @escaping @MainActor () -> HiddenContentFilter
    ) {
        self.api = api
        self.catalog = catalog
        self.query = initialQuery
        self.hiddenFilter = hiddenFilter
    }

    public func onQueryChange() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await search()
        }
    }

    public func search() async {
        let term = query.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else {
            series = []
            books = []
            state = .uninitialized
            return
        }
        state = .loading
        let hidden = hiddenFilter()
        if catalog.state.isUninitialized { await catalog.load() }

        // In-memory half: the only way to reach an individually hidden book.
        let localSeries = catalog.series.filter { $0.matchesSearch(term) }
        let localBooks = catalog.books.filter { $0.matchesSearch(term) }

        do {
            let page = KomgaPageRequest(size: 50)
            async let remoteSeries = api.seriesApi.getSeriesList(
                search: KomgaSeriesSearch(
                    condition: hidden.seriesConditions.isEmpty ? nil : .allOf(hidden.seriesConditions),
                    fullTextSearch: term),
                pageRequest: page)
            async let remoteBooks = api.bookApi.getBookList(
                search: KomgaBookSearch(
                    condition: hidden.bookConditions.isEmpty ? nil : .allOf(hidden.bookConditions),
                    fullTextSearch: term),
                pageRequest: page)
            // `visible(_:)` still runs: an `.onlyHidden` condition set that is empty would otherwise
            // return the whole library.
            series = Self.merge(localSeries, hidden.visible(try await remoteSeries.content))
            books = Self.merge(localBooks, hidden.visible(try await remoteBooks.content))
            state = .success(())
        } catch {
            guard !Task.isCancelled else { return }
            // The server half failing still leaves the catalog matches worth showing.
            series = localSeries
            books = localBooks
            state = (localSeries.isEmpty && localBooks.isEmpty) ? .error(error) : .success(())
        }
    }

    private static func merge<T: Identifiable>(_ local: [T], _ remote: [T]) -> [T] {
        var seen = Set(local.map(\.id))
        return local + remote.filter { seen.insert($0.id).inserted }
    }
}

extension KomgaSeries {
    fileprivate func matchesSearch(_ term: String) -> Bool {
        metadata.title.localizedStandardContains(term) || name.localizedStandardContains(term)
    }
}

extension SplashBook {
    fileprivate func matchesSearch(_ term: String) -> Bool {
        book.metadata.title.localizedStandardContains(term)
            || book.seriesTitle.localizedStandardContains(term)
    }
}

struct PrivateSearchScreen: View {
    @State var model: PrivateSearchViewModel
    let cardWidth: CGFloat
    let navigate: (Destination) -> Void

    var body: some View {
        ScrollView {
            switch model.state {
            case .loading:
                ProgressView().padding()
            case .error(let error):
                ErrorView(error: error) { Task { await model.search() } }
            default:
                if model.series.isEmpty, model.books.isEmpty {
                    ContentUnavailableView.search(text: model.query)
                } else {
                    VStack(alignment: .leading, spacing: 24) {
                        if !model.series.isEmpty {
                            CardGrid(items: model.series, cardWidth: cardWidth) { item in
                                Button { navigate(item.oneshot ? .oneshot(item.id) : .series(item.id)) } label: {
                                    SeriesCard(series: item)
                                }
                                .buttonStyle(.plain)
                                .contextMenu { HideMenuButton(target: .series(item.id)) }
                            }
                        }
                        if !model.books.isEmpty {
                            CardGrid(items: model.books, cardWidth: cardWidth) { book in
                                Button { navigate(.book(book.id)) } label: {
                                    BookCard(book: book, showSeries: true)
                                }
                                .buttonStyle(.plain)
                                .contextMenu { HideMenuButton(target: .book(book.id, isDownloaded: book.downloaded)) }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Private results")
        // Its own field, so results can be refined in place — matching `SearchScreen`.
        .searchable(text: $model.query, prompt: Text("Search private"))
        .onChange(of: model.query) { model.onQueryChange() }
        .task { if model.state.isUninitialized, !model.query.isEmpty { await model.search() } }
    }
}
