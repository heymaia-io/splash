import SplashCore
import KomgaAPI
import Observation
import SwiftUI

/// Port of `SearchViewModel.kt` — full-text search across series and books.
@MainActor
@Observable
public final class SearchViewModel {
    public enum Tab: Hashable { case series, books }

    public var query: String
    public var currentTab: Tab = .series
    public private(set) var series: [KomgaSeries] = []
    public private(set) var books: [SplashBook] = []
    public private(set) var state: LoadState<Void> = .uninitialized

    private let api: any KomgaApi
    /// A provider, not a snapshot: re-read per search so unlocking takes effect on the next keystroke.
    private let hiddenFilter: @MainActor () -> HiddenContentFilter
    private var searchTask: Task<Void, Never>?

    init(
        api: any KomgaApi, initialQuery: String,
        hiddenFilter: @escaping @MainActor () -> HiddenContentFilter = { .disabled }
    ) {
        self.api = api
        self.query = initialQuery
        self.hiddenFilter = hiddenFilter
    }

    /// Debounced (the Kotlin search bar also debounces keystrokes).
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
        do {
            let page = KomgaPageRequest(size: 50)
            let hidden = hiddenFilter()
            async let series = api.seriesApi.getSeriesList(
                search: KomgaSeriesSearch(condition: hidden.combined(nil), fullTextSearch: term), pageRequest: page)
            async let books = api.bookApi.getBookList(
                search: KomgaBookSearch(condition: hidden.combined(nil), fullTextSearch: term), pageRequest: page)
            // Conditions cannot exclude a series from a series query or a book from a book query, so both
            // results still go through the guard.
            self.series = hidden.visible(try await series.content)
            self.books = hidden.visible(try await books.content)
            state = .success(())
        } catch {
            if !Task.isCancelled { state = .error(error) }
        }
    }
}

struct SearchScreen: View {
    @State var model: SearchViewModel
    let cardWidth: CGFloat
    let navigate: (Destination) -> Void

    var body: some View {
        ScrollView {
            Picker("Results", selection: $model.currentTab) {
                Text("Series (\(model.series.count))").tag(SearchViewModel.Tab.series)
                Text("Books (\(model.books.count))").tag(SearchViewModel.Tab.books)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            switch model.state {
            case .uninitialized:
                ContentUnavailableView("Search", systemImage: "magnifyingglass",
                                       description: Text("Search all libraries"))
            case .error(let error):
                ScreenErrorView(error: error, retry: { Task { await model.search() } })
            default:
                if model.state.value != nil, model.series.isEmpty, model.books.isEmpty {
                    ContentUnavailableView.search(text: model.query)
                } else if model.currentTab == .series {
                    CardGrid(items: model.series, cardWidth: cardWidth) { item in
                        Button { navigate(item.oneshot ? .oneshot(item.id) : .series(item.id)) } label: {
                            SeriesCard(series: item)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    CardGrid(items: model.books, cardWidth: cardWidth) { book in
                        Button { navigate(book.oneshot ? .oneshot(book.seriesId) : .book(book.id)) } label: {
                            BookCard(book: book, showSeries: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .overlay { if model.state.isLoading { ProgressView() } }
        .navigationTitle("Search")
        .searchable(text: $model.query, prompt: "Search")
        .onChange(of: model.query) { model.onQueryChange() }
        .task { if !model.query.isEmpty, model.state.isUninitialized { await model.search() } }
    }
}
