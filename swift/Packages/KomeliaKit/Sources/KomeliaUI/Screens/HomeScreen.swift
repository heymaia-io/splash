import KomeliaCore
import KomgaAPI
import Observation
import SwiftUI

/// Port of `HomeViewModel.kt` / `HomeFilterData.kt`.
@MainActor
@Observable
public final class HomeViewModel {
    public enum Section: Identifiable, Sendable {
        case series(HomeScreenFilter, [KomgaSeries])
        case books(HomeScreenFilter, [KomeliaBook])

        public var id: Int { filter.order }
        public var filter: HomeScreenFilter {
            switch self {
            case .series(let f, _), .books(let f, _): f
            }
        }
        var isEmpty: Bool {
            switch self {
            case .series(_, let s): s.isEmpty
            case .books(_, let b): b.isEmpty
            }
        }
    }

    public private(set) var state: LoadState<Void> = .uninitialized
    public private(set) var sections: [Section] = []
    /// `activeFilterNumber` — 0 = all sections.
    public var activeFilter = 0

    private let api: any KomgaApi
    private let filters: HomeScreenFilterRepository
    private let events: KomgaEventSource
    private var eventTask: Task<Void, Never>?
    @ObservationIgnored private lazy var reloader = ReloadScheduler(cooldown: .seconds(5)) { [weak self] in
        await self?.load()
    }

    init(api: any KomgaApi, filters: HomeScreenFilterRepository, events: KomgaEventSource) {
        self.api = api
        self.filters = filters
        self.events = events
    }

    public func initialize() async {
        guard state.isUninitialized else { return }
        eventTask = listen(to: events) { [weak self] event in
            switch event {
            case .bookAdded, .bookChanged, .bookDeleted, .seriesAdded, .seriesChanged, .seriesDeleted,
                 .readProgressChanged, .readProgressDeleted, .readProgressSeriesChanged, .readProgressSeriesDeleted:
                self?.reloader.request()
            default: break
            }
        }
        await load()
    }

    public func setEventsEnabled(_ enabled: Bool) { reloader.isEnabled = enabled }

    public func load() async {
        state = .loading
        do {
            let loaded = try await Self.fetchAll(filters.value, api: api)
            sections = loaded.sorted { $0.filter.order < $1.filter.order }
            state = .success(())
        } catch {
            state = .error(error)
        }
    }

    /// All filters concurrently (`map { async { fetchFilterData(it) } }.awaitAll()`).
    nonisolated static func fetchAll(_ filters: [HomeScreenFilter], api: any KomgaApi) async throws -> [Section] {
        try await withThrowingTaskGroup(of: Section.self) { group in
            for filter in filters {
                group.addTask { try await fetch(filter, api: api) }
            }
            var sections: [Section] = []
            for try await section in group { sections.append(section) }
            return sections
        }
    }

    /// `fetchFilterData(filter)` — one strategy per filter kind.
    nonisolated static func fetch(_ filter: HomeScreenFilter, api: any KomgaApi) async throws -> Section {
        switch filter {
        case .booksCustom(_, _, let condition, let text, _, _):
            let books = try await api.bookApi.getBookList(
                search: KomgaBookSearch(condition: condition, fullTextSearch: text), pageRequest: filter.pageRequest)
            return .books(filter, books.content)
        case .booksOnDeck(_, _, let pageSize):
            let books = try await api.bookApi.getBooksOnDeck(libraryIds: nil, pageRequest: KomgaPageRequest(size: pageSize))
            return .books(filter, books.content)
        case .seriesCustom(_, _, let condition, let text, _, _):
            let series = try await api.seriesApi.getSeriesList(
                search: KomgaSeriesSearch(condition: condition, fullTextSearch: text), pageRequest: filter.pageRequest)
            return .series(filter, series.content)
        case .seriesRecentlyAdded(_, _, let pageSize):
            let series = try await api.seriesApi.getNewSeries(
                libraryIds: nil, oneshot: false, deleted: nil, pageRequest: KomgaPageRequest(size: pageSize))
            return .series(filter, series.content)
        case .seriesRecentlyUpdated(_, _, let pageSize):
            let series = try await api.seriesApi.getUpdatedSeries(
                libraryIds: nil, oneshot: false, deleted: nil, pageRequest: KomgaPageRequest(size: pageSize))
            return .series(filter, series.content)
        }
    }
}

/// Port of `HomeContent.kt`: filter chips + horizontal carousels.
struct HomeScreen: View {
    @State var model: HomeViewModel
    let navigate: (Destination) -> Void
    let cardWidth: CGFloat

    var body: some View {
        Group {
            switch model.state {
            case .error(let error) where model.sections.isEmpty:
                ErrorView(error: error) { Task { await model.load() } }
            case .uninitialized:
                ProgressView()
            default:
                content
            }
        }
        .navigationTitle("Home")
        .task { await model.initialize() }
        .refreshable { await model.load() }
    }

    private var visibleSections: [HomeViewModel.Section] {
        let nonEmpty = model.sections.filter { !$0.isEmpty }
        guard model.activeFilter != 0 else { return nonEmpty }
        return nonEmpty.filter { $0.filter.order == model.activeFilter }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                filterChips
                if visibleSections.isEmpty, !model.state.isLoading {
                    ContentUnavailableView("Nothing to show", systemImage: "books.vertical")
                }
                ForEach(visibleSections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.filter.label).font(.title3.bold()).padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 12) {
                                sectionCards(section)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .overlay(alignment: .top) {
            if model.state.isLoading { ProgressView().padding() }
        }
    }

    @ViewBuilder private func sectionCards(_ section: HomeViewModel.Section) -> some View {
        switch section {
        case .series(_, let series):
            ForEach(series) { item in
                Button { navigate(item.oneshot ? .oneshot(item.id) : .series(item.id)) } label: {
                    SeriesCard(series: item).frame(width: cardWidth)
                }
                .buttonStyle(.plain)
            }
        case .books(_, let books):
            ForEach(books) { book in
                Button { navigate(book.oneshot ? .oneshot(book.seriesId) : .book(book.id)) } label: {
                    BookCard(book: book, showSeries: true).frame(width: cardWidth)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                chip(label: String(localized: "All"), tag: 0)
                ForEach(model.sections.filter { !$0.isEmpty }) { section in
                    chip(label: section.filter.label, tag: section.filter.order)
                }
            }
            .padding(.horizontal)
        }
    }

    private func chip(label: String, tag: Int) -> some View {
        Button(label) { model.activeFilter = tag }
            .buttonStyle(.bordered)
            .tint(model.activeFilter == tag ? .accentColor : .secondary)
    }
}
