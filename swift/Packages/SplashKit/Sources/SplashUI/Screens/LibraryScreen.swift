import SplashCore
import KomgaAPI
import Observation
import SwiftUI

/// `LibrarySeriesTabState.SeriesSort` (verbatim option set).
public enum SeriesSortOption: String, CaseIterable, Identifiable, Sendable {
    case updatedDesc, updatedAsc, releaseDateDesc, releaseDateAsc, titleAsc, titleDesc, dateAddedDesc, dateAddedAsc
    /// [NUEVO] Server-side shuffle. Komga re-rolls `random` on every request, so this one cannot be paged
    /// through — the screen shows a single shuffled page and a Shuffle button instead of the page bar.
    case random

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
        case .random: KomgaSeriesSort.random()
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
        case .random: "Random"
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
    /// [NUEVO] `ALL # A–Z` navigation, like the web UI's alphabetical bar.
    public var letter: SeriesLetterFilter = .all
    /// [NUEVO] Tag filter. Several tags read as OR, matching the web UI.
    public var selectedTags: Set<String> = []
    public private(set) var availableTags: [String] = []

    public private(set) var collections: [KomgaCollection] = []
    public private(set) var readLists: [KomgaReadList] = []

    private let api: any KomgaApi
    private let authState: KomgaAuthenticationState
    private let settings: CommonSettingsRepository
    private let events: KomgaEventSource
    /// A provider, not a snapshot: re-read per fetch so hiding and unlocking both take effect live.
    private let hiddenFilter: @MainActor () -> HiddenContentFilter
    private let hiddenChanges: @MainActor () -> AsyncStream<PrivacyState>
    private var eventTask: Task<Void, Never>?
    private var hiddenTask: Task<Void, Never>?
    @ObservationIgnored private lazy var seriesReloader = ReloadScheduler(cooldown: .seconds(1)) { [weak self] in
        guard let self else { return }
        await self.loadSeriesPage(self.currentPage)
    }
    @ObservationIgnored private lazy var countsReloader = ReloadScheduler(cooldown: .seconds(1)) { [weak self] in
        await self?.loadItemCounts()
    }

    init(api: any KomgaApi, libraryId: KomgaLibraryId?, authState: KomgaAuthenticationState,
         settings: CommonSettingsRepository, events: KomgaEventSource,
         hiddenFilter: @escaping @MainActor () -> HiddenContentFilter = { .disabled },
         hiddenChanges: @escaping @MainActor () -> AsyncStream<PrivacyState> = { noHiddenChanges }) {
        self.api = api
        self.libraryId = libraryId
        self.authState = authState
        self.settings = settings
        self.events = events
        self.hiddenFilter = hiddenFilter
        self.hiddenChanges = hiddenChanges
    }

    public var library: KomgaLibrary? { authState.libraries.first { $0.id == libraryId } }
    /// Drives the library switcher below the title (the rows the sidebar used to hold).
    public var libraries: [KomgaLibrary] { hiddenFilter().visible(authState.libraries) }
    public var cardWidth: CGFloat { CGFloat(settings.value.cardWidth) }
    /// A shuffled listing has no stable pages: the server reshuffles per request.
    public var isShuffled: Bool { sort == .random }

    public func initialize() async {
        guard seriesState.isUninitialized else { return }
        eventTask = listen(to: events) { [weak self] event in self?.handle(event) }
        hiddenTask = listenHidden(to: hiddenChanges) { [weak self] in await self?.reload() }
        async let counts: Void = loadItemCounts()
        async let tags: Void = loadTags()
        async let page: Void = loadSeriesPage(1)
        _ = await (counts, tags, page)
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
    /// Re-rolls the shuffle (the server does the shuffling; asking again is the whole operation).
    public func shuffle() async { await loadSeriesPage(1) }

    public func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
    }

    public func setEventsEnabled(_ enabled: Bool) {
        seriesReloader.isEnabled = enabled
        countsReloader.isEnabled = enabled
    }

    func loadSeriesPage(_ page: Int) async {
        let libraryId = self.libraryId
        let hidden = hiddenFilter()
        // Hidden *libraries* are excluded server-side; hidden *series* cannot be — `SeriesCondition` has no
        // id case — so `visible(...)` below is the actual guard.
        var conditions: [SeriesCondition] = (libraryId.map { [.libraryId(.isEqualTo($0))] } ?? [])
            + hidden.seriesConditions
        if let letterCondition = letter.seriesCondition { conditions.append(letterCondition) }
        if !selectedTags.isEmpty {
            conditions.append(.anyOf(selectedTags.sorted().map { .tag(.isEqualTo($0)) }))
        }
        let term = searchTerm.trimmingCharacters(in: .whitespaces)
        if series.isEmpty { seriesState = .loading }
        do {
            let result = try await api.seriesApi.getSeriesList(
                search: KomgaSeriesSearch(condition: .allOf(conditions), fullTextSearch: term.isEmpty ? nil : term),
                pageRequest: KomgaPageRequest(
                    pageIndex: (isShuffled ? 1 : page) - 1, size: settings.value.seriesPageLoadSize,
                    sort: sort.komgaSort))
            // Known limit: an individually hidden series still counts toward the server's totals, so a page
            // can render up to k fewer cards than the page size. `totalPages` is deliberately left as the
            // server reported it — shrinking it makes the tail unreachable. The real fix is upstream.
            series = hidden.visible(result.content)
            // A shuffled page is deliberately presented as the only page: page 2 of a `random` sort is a
            // fresh shuffle, so paging would repeat some series and never show others.
            currentPage = isShuffled ? 1 : result.number + 1
            totalPages = isShuffled ? 1 : max(result.totalPages, 1)
            totalCount = result.totalElements
            seriesState = .success(())
        } catch {
            seriesState = .error(error)
        }
    }

    /// Library scope for the endpoints that accept only `libraryIds`: the selected library, or — when
    /// showing "All Libraries" — an allow-list that omits the hidden ones. `nil` means "no restriction",
    /// which keeps the request byte-identical for anyone who hides nothing.
    ///
    /// Counts stay server-accurate precisely because this filters at the request, not the result: collections
    /// and read lists are never removed client-side, so `collectionsCount` cannot drift from `collections`
    /// and the tab chips cannot lie.
    private func libraryScope(_ hidden: HiddenContentFilter) -> [KomgaLibraryId]? {
        libraryId.map { [$0] } ?? hidden.libraryAllowList(from: authState.libraries)
    }

    private func loadItemCounts() async {
        let ids = libraryScope(hiddenFilter())
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

    /// Tag names for the filter menu. Scoped to the visible libraries: a tag carried only by series in a
    /// hidden library would otherwise be listed, which is content the private area is meant to keep out.
    private func loadTags() async {
        let referential = api.referentialApi
        do {
            let tags: [String]
            if let libraryId {
                tags = try await referential.getSeriesTags(libraryId: libraryId, collectionId: nil)
            } else if let allowList = libraryScope(hiddenFilter()) {
                var union: Set<String> = []
                for id in allowList {
                    union.formUnion(try await referential.getSeriesTags(libraryId: id, collectionId: nil))
                }
                tags = Array(union)
            } else {
                tags = try await referential.getSeriesTags(libraryId: nil, collectionId: nil)
            }
            availableTags = tags.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            // A tag that disappeared from the server must not keep filtering the grid.
            selectedTags.formIntersection(availableTags)
        } catch {
            // Decorative like the counts: the series tab is what reports errors.
        }
    }

    private func loadCollections() async {
        let ids = libraryScope(hiddenFilter())
        collections = (try? await api.collectionsApi.getAll(
            search: nil, libraryIds: ids, pageRequest: KomgaPageRequest(unpaged: true)).content) ?? []
    }

    private func loadReadLists() async {
        let ids = libraryScope(hiddenFilter())
        readLists = (try? await api.readListApi.getAll(
            search: nil, libraryIds: ids, pageRequest: KomgaPageRequest(unpaged: true)).content) ?? []
    }

    private func handle(_ event: KomgaEvent) {
        switch event {
        // A reload re-rolls a shuffled listing, so live events leave it alone: the grid would rearrange
        // itself while the user is looking at it, for a change they did not make.
        case .seriesAdded(let p), .seriesChanged(let p), .seriesDeleted(let p):
            if !isShuffled, libraryId == nil || p.libraryId == libraryId { seriesReloader.request() }
        case .readProgressSeriesChanged(let p), .readProgressSeriesDeleted(let p):
            if !isShuffled, series.contains(where: { $0.id == p.seriesId }) { seriesReloader.request() }
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
                if model.currentTab == .series {
                    AlphabeticalNavigationBar(selection: $model.letter)
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
            tagFilterMenu
            Menu {
                Picker("Sort", selection: $model.sort) {
                    ForEach(SeriesSortOption.allCases) { Text($0.label).tag($0) }
                }
                // Only meaningful with a library actually selected; "All Libraries" has nothing to hide.
                if let libraryId = model.libraryId {
                    HideMenuButton(target: .library(libraryId))
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
        }
        .onChange(of: model.sort) { Task { await model.onFilterChange() } }
        .onChange(of: model.letter) { Task { await model.onFilterChange() } }
        .onChange(of: model.selectedTags) { Task { await model.onFilterChange() } }
        .task { await model.initialize() }
        .refreshable { await model.reload() }
    }

    /// Library switcher, styled as the chip under the large title in the design references.
    ///
    /// The empty space trailing the chip is the private-area reveal target. It is deliberately *not* the
    /// chip itself: a long press there would fight the menu's own press-and-hold.
    private var libraryPicker: some View {
        HStack(spacing: 0) {
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

            Color.clear
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, minHeight: 44)
                .privacyRevealGesture()
        }
        .padding(.horizontal)
    }

    /// Tags are a menu rather than a chip row: a library can carry hundreds of them, and the row above the
    /// grid already belongs to the alphabet.
    @ViewBuilder private var tagFilterMenu: some View {
        if !model.availableTags.isEmpty {
            Menu {
                if !model.selectedTags.isEmpty {
                    Button("Clear tags") { model.selectedTags = [] }
                    Divider()
                }
                ForEach(model.availableTags, id: \.self) { tag in
                    Button { model.toggleTag(tag) } label: {
                        if model.selectedTags.contains(tag) {
                            Label(tag, systemImage: "checkmark")
                        } else {
                            Text(tag)
                        }
                    }
                }
            } label: {
                Label("Tags", systemImage: model.selectedTags.isEmpty
                    ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
            }
        }
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
                if model.isShuffled {
                    Button { Task { await model.shuffle() } } label: {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .frame(maxWidth: .infinity)
                } else {
                    PaginationBar(currentPage: model.currentPage, totalPages: model.totalPages) { page in
                        Task { await model.onPageChange(page) }
                    }
                }
            }
        }
    }
}
