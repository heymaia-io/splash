import SplashCore
import KomgaAPI
import Observation
import SwiftUI

/// `LibrarySeriesTabState.SeriesSort` (verbatim option set).
public enum SeriesSortOption: String, CaseIterable, Identifiable, Sendable {
    case updatedDesc, updatedAsc, releaseDateDesc, releaseDateAsc, titleAsc, titleDesc, dateAddedDesc, dateAddedAsc

    public var id: String { rawValue }

    var komgaSort: KomgaSort {
        switch self {
        case .updatedDesc: KomgaSeriesSort.byLastModifiedDate(.desc)
        case .updatedAsc: KomgaSeriesSort.byLastModifiedDate(.asc)
        case .releaseDateDesc: KomgaSeriesSort.byReleaseDate(.desc)
        case .releaseDateAsc: KomgaSeriesSort.byReleaseDate(.asc)
        case .titleAsc: KomgaSeriesSort.byTitle(.asc)
        case .titleDesc: KomgaSeriesSort.byTitle(.desc)
        case .dateAddedDesc: KomgaSeriesSort.byCreatedDate(.desc)
        case .dateAddedAsc: KomgaSeriesSort.byCreatedDate(.asc)
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .updatedDesc: "Updated (newest)"
        case .updatedAsc: "Updated (oldest)"
        case .releaseDateDesc: "Release date (newest)"
        case .releaseDateAsc: "Release date (oldest)"
        case .titleAsc: "Title (A–Z)"
        case .titleDesc: "Title (Z–A)"
        case .dateAddedDesc: "Date added (newest)"
        case .dateAddedAsc: "Date added (oldest)"
        }
    }
}

/// Port of `LibraryViewModel.kt` + `LibrarySeriesTabState.kt` + collections/read-lists tab states.
/// v1 scope: sort + text search + default filters (the full filter editor is deferred, plan Phase 6).
@MainActor
@Observable
public final class LibraryViewModel {
    public enum Tab: Hashable { case series, collections, readLists }

    public let libraryId: KomgaLibraryId?
    public var currentTab: Tab = .series
    public private(set) var collectionsCount = 0
    public private(set) var readListsCount = 0

    public private(set) var seriesState: LoadState<Void> = .uninitialized
    public private(set) var series: [KomgaSeries] = []
    public private(set) var currentPage = 1
    public private(set) var totalPages = 1
    public private(set) var totalCount = 0
    public var sort: SeriesSortOption = .titleAsc
    public var searchTerm = ""

    public private(set) var collections: [KomgaCollection] = []
    public private(set) var readLists: [KomgaReadList] = []

    private let api: any KomgaApi
    private let authState: KomgaAuthenticationState
    private let settings: CommonSettingsRepository
    private let events: KomgaEventSource
    private var eventTask: Task<Void, Never>?
    @ObservationIgnored private lazy var seriesReloader = ReloadScheduler(cooldown: .seconds(1)) { [weak self] in
        guard let self else { return }
        await self.loadSeriesPage(self.currentPage)
    }
    @ObservationIgnored private lazy var countsReloader = ReloadScheduler(cooldown: .seconds(1)) { [weak self] in
        await self?.loadItemCounts()
    }

    init(api: any KomgaApi, libraryId: KomgaLibraryId?, authState: KomgaAuthenticationState,
         settings: CommonSettingsRepository, events: KomgaEventSource) {
        self.api = api
        self.libraryId = libraryId
        self.authState = authState
        self.settings = settings
        self.events = events
    }

    public var library: KomgaLibrary? { authState.libraries.first { $0.id == libraryId } }
    /// Drives the library switcher below the title (the rows the sidebar used to hold).
    public var libraries: [KomgaLibrary] { authState.libraries }
    public var cardWidth: CGFloat { CGFloat(settings.value.cardWidth) }

    public func initialize() async {
        guard seriesState.isUninitialized else { return }
        eventTask = listen(to: events) { [weak self] event in self?.handle(event) }
        async let counts: Void = loadItemCounts()
        async let page: Void = loadSeriesPage(1)
        _ = await (counts, page)
    }

    public func reload() async {
        await loadItemCounts()
        switch currentTab {
        case .series: await loadSeriesPage(1)
        case .collections: await loadCollections()
        case .readLists: await loadReadLists()
        }
    }

    public func onTabChange(_ tab: Tab) async {
        currentTab = tab
        switch tab {
        case .series: break
        case .collections: if collections.isEmpty { await loadCollections() }
        case .readLists: if readLists.isEmpty { await loadReadLists() }
        }
    }

    public func onPageChange(_ page: Int) async { await loadSeriesPage(page) }
    public func onFilterChange() async { await loadSeriesPage(1) }

    public func setEventsEnabled(_ enabled: Bool) {
        seriesReloader.isEnabled = enabled
        countsReloader.isEnabled = enabled
    }

    func loadSeriesPage(_ page: Int) async {
        let libraryId = self.libraryId
        let conditions: [SeriesCondition] = libraryId.map { [.libraryId(.isEqualTo($0))] } ?? []
        let term = searchTerm.trimmingCharacters(in: .whitespaces)
        if series.isEmpty { seriesState = .loading }
        do {
            let result = try await api.seriesApi.getSeriesList(
                search: KomgaSeriesSearch(condition: .allOf(conditions), fullTextSearch: term.isEmpty ? nil : term),
                pageRequest: KomgaPageRequest(
                    pageIndex: page - 1, size: settings.value.seriesPageLoadSize, sort: sort.komgaSort))
            series = result.content
            currentPage = result.number + 1
            totalPages = max(result.totalPages, 1)
            totalCount = result.totalElements
            seriesState = .success(())
        } catch {
            seriesState = .error(error)
        }
    }

    private func loadItemCounts() async {
        let ids = libraryId.map { [$0] }
        let sizeZero = KomgaPageRequest(size: 0)
        do {
            async let collections = api.collectionsApi.getAll(search: nil, libraryIds: ids, pageRequest: sizeZero)
            async let readLists = api.readListApi.getAll(search: nil, libraryIds: ids, pageRequest: sizeZero)
            collectionsCount = try await collections.totalElements
            readListsCount = try await readLists.totalElements
            if collectionsCount == 0, currentTab == .collections { currentTab = .series }
            if readListsCount == 0, currentTab == .readLists { currentTab = .series }
        } catch {
            // Counts are decorative; the series tab reports errors.
        }
    }

    private func loadCollections() async {
        let ids = libraryId.map { [$0] }
        collections = (try? await api.collectionsApi.getAll(
            search: nil, libraryIds: ids, pageRequest: KomgaPageRequest(unpaged: true)).content) ?? []
    }

    private func loadReadLists() async {
        let ids = libraryId.map { [$0] }
        readLists = (try? await api.readListApi.getAll(
            search: nil, libraryIds: ids, pageRequest: KomgaPageRequest(unpaged: true)).content) ?? []
    }

    private func handle(_ event: KomgaEvent) {
        switch event {
        case .seriesAdded(let p), .seriesChanged(let p), .seriesDeleted(let p):
            if libraryId == nil || p.libraryId == libraryId { seriesReloader.request() }
        case .readProgressSeriesChanged(let p), .readProgressSeriesDeleted(let p):
            if series.contains(where: { $0.id == p.seriesId }) { seriesReloader.request() }
        case .readListAdded, .readListDeleted, .collectionAdded, .collectionDeleted:
            countsReloader.request()
        default: break
        }
    }
}

/// Port of `LibraryScreen.kt` (tabs: Series / Collections / Read lists).
struct LibraryScreen: View {
    @State var model: LibraryViewModel
    let navigate: (Destination) -> Void
    /// Switching library replaces the tab's root instead of pushing, so the stack stays one level deep.
    let selectLibrary: (KomgaLibraryId?) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                libraryPicker
                if model.collectionsCount > 0 || model.readListsCount > 0 {
                    Picker("Section", selection: Binding(
                        get: { model.currentTab }, set: { tab in Task { await model.onTabChange(tab) } })
                    ) {
                        Text("Series").tag(LibraryViewModel.Tab.series)
                        if model.collectionsCount > 0 { Text("Collections").tag(LibraryViewModel.Tab.collections) }
                        if model.readListsCount > 0 { Text("Read lists").tag(LibraryViewModel.Tab.readLists) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
                switch model.currentTab {
                case .series: seriesTab
                case .collections:
                    CardGrid(items: model.collections, cardWidth: model.cardWidth) { item in
                        Button { navigate(.collection(item.id)) } label: { CollectionCard(collection: item) }
                            .buttonStyle(.plain)
                    }
                case .readLists:
                    CardGrid(items: model.readLists, cardWidth: model.cardWidth) { item in
                        Button { navigate(.readList(item.id)) } label: { ReadListCard(readList: item) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Library")
        // No library-scoped search field here: the shell's search bar is global by design, so searching from
        // inside a library queries every library instead of silently filtering the current one.
        .toolbar {
            Menu {
                Picker("Sort", selection: $model.sort) {
                    ForEach(SeriesSortOption.allCases) { Text($0.label).tag($0) }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
        }
        .onChange(of: model.sort) { Task { await model.onFilterChange() } }
        .task { await model.initialize() }
        .refreshable { await model.reload() }
    }

    /// Library switcher, styled as the chip under the large title in the design references.
    private var libraryPicker: some View {
        Menu {
            libraryOption(title: String(localized: "All Libraries"), id: nil)
            ForEach(model.libraries) { libraryOption(title: $0.name, id: $0.id) }
        } label: {
            Label {
                Text(model.library?.name ?? String(localized: "All Libraries"))
            } icon: {
                Image(systemName: "books.vertical")
            }
            .font(.subheadline.weight(.medium))
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    @ViewBuilder private func libraryOption(title: String, id: KomgaLibraryId?) -> some View {
        Button { selectLibrary(id) } label: {
            if model.libraryId == id {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    @ViewBuilder private var seriesTab: some View {
        switch model.seriesState {
        case .error(let error):
            ScreenErrorView(
                error: error, retry: { Task { await model.reload() } },
                downloads: .init(cardWidth: model.cardWidth, navigate: navigate))
        case .uninitialized:
            ProgressView().frame(maxWidth: .infinity, minHeight: 200)
        case .loading where model.series.isEmpty:
            ProgressView().frame(maxWidth: .infinity, minHeight: 200)
        default:
            if model.series.isEmpty {
                ContentUnavailableView("No series", systemImage: "books.vertical")
            } else {
                Text("\(model.totalCount) series")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                CardGrid(items: model.series, cardWidth: model.cardWidth) { item in
                    Button { navigate(item.oneshot ? .oneshot(item.id) : .series(item.id)) } label: {
                        SeriesCard(series: item)
                    }
                    .buttonStyle(.plain)
                }
                PaginationBar(currentPage: model.currentPage, totalPages: model.totalPages) { page in
                    Task { await model.onPageChange(page) }
                }
            }
        }
    }
}
