import SplashCore
import KomgaAPI
import Observation
import SwiftUI

/// [NUEVO] Everything carrying one metadata value, reached by tapping a tag or genre chip on a detail screen.
/// There is no Kotlin original; the chips there are inert.
///
/// Shaped like `SearchViewModel` (two parallel listings behind a segmented picker) but paginated, because a
/// popular tag can cover more books than a search result ever shows.
@MainActor
@Observable
public final class FacetBrowseViewModel {
    public enum Tab: Hashable { case series, books }

    public let facet: BrowseFacet
    public var currentTab: Tab = .series
    public private(set) var state: LoadState<Void> = .uninitialized

    public private(set) var series: [KomgaSeries] = []
    public private(set) var seriesPage = 1
    public private(set) var seriesTotalPages = 1
    public private(set) var seriesCount = 0

    public private(set) var books: [SplashBook] = []
    public private(set) var booksPage = 1
    public private(set) var booksTotalPages = 1
    public private(set) var booksCount = 0

    private let api: any KomgaApi
    private let settings: CommonSettingsRepository
    /// A provider, not a snapshot: re-read per fetch so hiding and unlocking both take effect live.
    private let hiddenFilter: @MainActor () -> HiddenContentFilter
    private let hiddenChanges: @MainActor () -> AsyncStream<PrivacyState>
    private var hiddenTask: Task<Void, Never>?

    init(facet: BrowseFacet, api: any KomgaApi, settings: CommonSettingsRepository,
         hiddenFilter: @escaping @MainActor () -> HiddenContentFilter = { .disabled },
         hiddenChanges: @escaping @MainActor () -> AsyncStream<PrivacyState> = { noHiddenChanges }) {
        self.facet = facet
        self.api = api
        self.settings = settings
        self.hiddenFilter = hiddenFilter
        self.hiddenChanges = hiddenChanges
    }

    public var cardWidth: CGFloat { CGFloat(settings.value.cardWidth) }
    /// Komga has no book-level genre, so a genre facet is a series-only listing.
    public var showsBooks: Bool { facet.bookCondition != nil }
    public var title: String { facet.value }

    public func initialize() async {
        guard state.isUninitialized else { return }
        hiddenTask = listenHidden(to: hiddenChanges) { [weak self] in await self?.reload() }
        state = .loading
        async let series: Void = loadSeries(page: 1)
        async let books: Void = loadBooks(page: 1)
        _ = await (series, books)
        if case .loading = state { state = .success(()) }
    }

    public func reload() async {
        async let series: Void = loadSeries(page: seriesPage)
        async let books: Void = loadBooks(page: booksPage)
        _ = await (series, books)
    }

    public func onSeriesPageChange(_ page: Int) async { await loadSeries(page: page) }
    public func onBooksPageChange(_ page: Int) async { await loadBooks(page: page) }

    private func loadSeries(page: Int) async {
        let hidden = hiddenFilter()
        let conditions = [facet.seriesCondition] + hidden.seriesConditions
        do {
            let result = try await api.seriesApi.getSeriesList(
                search: KomgaSeriesSearch(condition: .allOf(conditions)),
                pageRequest: KomgaPageRequest(
                    pageIndex: page - 1, size: settings.value.seriesPageLoadSize,
                    sort: KomgaSeriesSort.byTitle(.asc)))
            // Conditions cannot exclude an individually hidden series, so the guard still runs on results.
            series = hidden.visible(result.content)
            seriesPage = result.number + 1
            seriesTotalPages = max(result.totalPages, 1)
            seriesCount = result.totalElements
        } catch {
            if !error.isCancellation { state = .error(error) }
        }
    }

    private func loadBooks(page: Int) async {
        guard let facetCondition = facet.bookCondition else { return }
        let hidden = hiddenFilter()
        let conditions = [facetCondition] + hidden.bookConditions
        do {
            let result = try await api.bookApi.getBookList(
                search: KomgaBookSearch(condition: .allOf(conditions)),
                pageRequest: KomgaPageRequest(
                    pageIndex: page - 1, size: settings.value.bookPageLoadSize,
                    sort: KomgaBooksSort.bySeriesTitle(.asc).and(KomgaBooksSort.byNumber(.asc))))
            books = hidden.visible(result.content)
            booksPage = result.number + 1
            booksTotalPages = max(result.totalPages, 1)
            booksCount = result.totalElements
        } catch {
            if !error.isCancellation { state = .error(error) }
        }
    }
}

struct FacetBrowseScreen: View {
    @State var model: FacetBrowseViewModel
    let navigate: (Destination) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if model.showsBooks {
                    Picker("Results", selection: $model.currentTab) {
                        Text("Series (\(model.seriesCount))").tag(FacetBrowseViewModel.Tab.series)
                        Text("Books (\(model.booksCount))").tag(FacetBrowseViewModel.Tab.books)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
                switch model.state {
                case .uninitialized, .loading:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                case .error(let error):
                    ScreenErrorView(error: error, retry: { Task { await model.reload() } })
                case .success:
                    if model.currentTab == .series || !model.showsBooks {
                        seriesSection
                    } else {
                        booksSection
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(model.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await model.initialize() }
        .refreshable { await model.reload() }
    }

    @ViewBuilder private var seriesSection: some View {
        if model.series.isEmpty {
            ContentUnavailableView("No series", systemImage: "books.vertical")
        } else {
            CardGrid(items: model.series, cardWidth: model.cardWidth) { item in
                Button { navigate(item.oneshot ? .oneshot(item.id) : .series(item.id)) } label: {
                    SeriesCard(series: item)
                }
                .buttonStyle(.plain)
            }
            PaginationBar(currentPage: model.seriesPage, totalPages: model.seriesTotalPages) { page in
                Task { await model.onSeriesPageChange(page) }
            }
        }
    }

    @ViewBuilder private var booksSection: some View {
        if model.books.isEmpty {
            ContentUnavailableView("No books", systemImage: "book")
        } else {
            CardGrid(items: model.books, cardWidth: model.cardWidth) { book in
                Button { navigate(book.oneshot ? .oneshot(book.seriesId) : .book(book.id)) } label: {
                    BookCard(book: book, showSeries: true)
                }
                .buttonStyle(.plain)
            }
            PaginationBar(currentPage: model.booksPage, totalPages: model.booksTotalPages) { page in
                Task { await model.onBooksPageChange(page) }
            }
        }
    }
}
