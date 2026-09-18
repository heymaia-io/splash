import SplashCore
import KomgaAPI
import Observation
import SwiftUI

/// `BookFilterState.BooksSort`
public enum BooksSortOption: String, CaseIterable, Identifiable, Sendable {
    case numberAsc, numberDesc
    public var id: String { rawValue }
    var komgaSort: KomgaSort { KomgaBooksSort.byNumber(self == .numberAsc ? .asc : .desc) }
}

/// [NUEVO] Which books of a series to show, by download state.
///
/// A small glyph on the cover was the only signal that a book was downloaded, which is easy to miss when
/// most of a long series is not. This makes it a first-class filter, and lets the Downloads tab open a
/// series showing just what you have without sending you to a different tab.
public enum BookDownloadFilter: String, CaseIterable, Identifiable, Sendable {
    case all, downloaded, notDownloaded
    public var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .all: "All"
        case .downloaded: "Downloaded"
        case .notDownloaded: "Not downloaded"
        }
    }

    /// True when the offline store can answer this exactly, so the screen queries it instead of trimming a
    /// page of remote results — no network, and not subject to pagination.
    var isAnsweredByOfflineStore: Bool { self == .downloaded }

    /// The client-side fallback. Komga knows nothing about downloads, so this can never be a query
    /// condition; it trims a page after the fact, exactly like the privacy filter, which means a page can
    /// render fewer cards than the page size.
    func apply(to books: [SplashBook]) -> [SplashBook] {
        switch self {
        case .all: books
        case .downloaded: books.filter(\.downloaded)
        case .notDownloaded: books.filter { !$0.downloaded }
        }
    }
}

/// Port of `SeriesViewModel.kt` + `SeriesBooksState.kt` + `SeriesCollectionsState.kt`.
@MainActor
@Observable
public final class SeriesViewModel {
    public enum Tab: Hashable { case books, collections }

    public let seriesId: KomgaSeriesId
    public private(set) var state: LoadState<Void> = .uninitialized
    public private(set) var series: KomgaSeries?
    public var currentTab: Tab = .books

    public private(set) var books: [SplashBook] = []
    public private(set) var currentPage = 1
    public private(set) var totalPages = 1
    public var sort: BooksSortOption = .numberAsc
    public var downloadFilter: BookDownloadFilter
    /// [NUEVO] Book-tag filter. Several tags read as OR, like the library's series-tag filter.
    public var selectedTags: Set<String> = []
    public private(set) var availableTags: [String] = []
    public private(set) var collections: [KomgaCollection] = []
    public private(set) var actionError: String?

    private let api: any KomgaApi
    /// Reads the offline store directly. `.downloaded` is answered from here rather than by filtering a page
    /// of remote results, so it is exact, needs no network, and is not subject to pagination.
    private let offlineApi: (any KomgaApi)?
    private let authState: KomgaAuthenticationState
    private let settings: CommonSettingsRepository
    private let events: KomgaEventSource
    private var eventTask: Task<Void, Never>?
    @ObservationIgnored private lazy var seriesReloader = ReloadScheduler(cooldown: .seconds(1)) { [weak self] in
        await self?.loadSeries()
    }
    @ObservationIgnored private lazy var booksReloader = ReloadScheduler(cooldown: .seconds(1)) { [weak self] in
        guard let self else { return }
        await self.loadBooks(page: self.currentPage)
    }

    /// A provider, not a snapshot: re-read per fetch so unlocking takes effect without rebuilding the model.
    private let hiddenFilter: @MainActor () -> HiddenContentFilter
    private let hiddenChanges: @MainActor () -> AsyncStream<PrivacyState>
    private var hiddenTask: Task<Void, Never>?

    init(seriesId: KomgaSeriesId, api: any KomgaApi, authState: KomgaAuthenticationState,
         settings: CommonSettingsRepository, events: KomgaEventSource,
         offlineApi: (any KomgaApi)? = nil,
         downloadFilter: BookDownloadFilter = .all,
         hiddenFilter: @escaping @MainActor () -> HiddenContentFilter = { .disabled },
         hiddenChanges: @escaping @MainActor () -> AsyncStream<PrivacyState> = { noHiddenChanges }) {
        self.seriesId = seriesId
        self.api = api
        self.offlineApi = offlineApi
        self.downloadFilter = downloadFilter
        self.authState = authState
        self.settings = settings
        self.events = events
        self.hiddenFilter = hiddenFilter
        self.hiddenChanges = hiddenChanges
    }

    public var library: KomgaLibrary? { series.flatMap { s in authState.libraries.first { $0.id == s.libraryId } } }
    public var cardWidth: CGFloat { CGFloat(settings.value.cardWidth) }

    public func initialize() async {
        guard state.isUninitialized else { return }
        eventTask = listen(to: events) { [weak self] event in self?.handle(event) }
        // Hiding a book from its context menu must drop it from the list straight away — the Hide action is
        // available while locked, so this is the ordinary path, not an edge case.
        hiddenTask = listenHidden(to: hiddenChanges) { [weak self] in
            guard let self else { return }
            await self.loadSeries()
            await self.loadBooks(page: self.currentPage)
        }
        await loadSeries()
        async let books: Void = loadBooks(page: 1)
        async let collections: Void = loadCollections()
        async let tags: Void = loadTags()
        _ = await (books, collections, tags)
    }

    public func reload() async {
        await loadSeries()
        await loadBooks(page: 1)
    }

    public func onPageChange(_ page: Int) async { await loadBooks(page: page) }
    public func onSortChange() async { await loadBooks(page: 1) }
    public func onDownloadFilterChange() async { await loadBooks(page: 1) }
    public func onTagFilterChange() async { await loadBooks(page: 1) }

    public func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
    }

    // MARK: SeriesMenuActions

    public func markAsRead() async { await perform { try await $0.seriesApi.markAsRead(self.seriesId) } }
    public func markAsUnread() async { await perform { try await $0.seriesApi.markAsUnread(self.seriesId) } }
    public func markBookRead(_ book: SplashBook) async {
        await perform { try await $0.bookApi.markReadProgress(book.id, request: .init(completed: true)) }
    }
    public func markBookUnread(_ book: SplashBook) async {
        await perform { try await $0.bookApi.deleteReadProgress(book.id) }
    }

    private func perform(_ action: @escaping (any KomgaApi) async throws -> Void) async {
        do {
            actionError = nil
            try await action(api)
            await reload()
        } catch {
            if !error.isCancellation { actionError = error.localizedDescription }
        }
    }

    // MARK: Loading

    private func loadSeries() async {
        if series == nil { state = .loading }
        do {
            var loaded = try await api.seriesApi.getOneSeries(seriesId)
            // A detail screen bypasses every listing, so it refuses a hidden series itself — reached by a
            // stale navigation stack, or by locking while viewing one. Same 404 the server gives for a
            // series that does not exist: no separate "this is private" state, which would confirm to a
            // snooper that there is something here.
            guard !hiddenFilter().isHidden(series: loaded) else {
                series = nil
                books = []
                throw KomgaAPIError.httpStatus(code: 404, body: Data())
            }
            loaded.metadata.tags.sort()  // `withSortedTags()`
            loaded.metadata.genres.sort()
            series = loaded
            state = .success(())
        } catch {
            if !error.isCancellation { state = .error(error) }
        }
    }

    func loadBooks(page: Int) async {
        do {
            let hidden = hiddenFilter()
            // `BookCondition` can exclude both libraries and whole series, so the only thing left for the
            // client-side guard here is an individually hidden *book* — pagination stays exact otherwise.
            var conditions: [BookCondition] = [.seriesId(.isEqualTo(seriesId))] + hidden.bookConditions
            if !selectedTags.isEmpty {
                conditions.append(.anyOf(selectedTags.sorted().map { .tag(.isEqualTo($0)) }))
            }
            let search = KomgaBookSearch(condition: .allOf(conditions))

            let filter = downloadFilter
            if filter.isAnsweredByOfflineStore, let offlineApi {
                // The offline store holds exactly the downloaded books. Unpaged because the count is bounded
                // by what the user chose to download, and it needs no network.
                let result = try await offlineApi.bookApi.getBookList(
                    search: search, pageRequest: KomgaPageRequest(sort: sort.komgaSort, unpaged: true))
                books = hidden.visible(result.content)
                currentPage = 1
                totalPages = 1
                return
            }

            let result = try await api.bookApi.getBookList(
                search: search,
                pageRequest: KomgaPageRequest(
                    pageIndex: page - 1, size: settings.value.bookPageLoadSize, sort: sort.komgaSort))
            // `apply` also covers `.downloaded` when no offline store was supplied (previews, tests), so the
            // filter is never silently ignored. The server's `totalPages` is kept either way, so trimming a
            // page never makes the tail unreachable.
            books = filter.apply(to: hidden.visible(result.content))
            currentPage = result.number + 1
            totalPages = max(result.totalPages, 1)
        } catch {
            if !error.isCancellation { actionError = error.localizedDescription }
        }
    }

    private func loadCollections() async {
        collections = (try? await api.seriesApi.getAllCollectionsBySeries(seriesId)) ?? []
    }

    /// Book tags of *this* series, for the filter menu. Nothing to scope for privacy: the screen is already
    /// one series, and a hidden series is never reachable.
    private func loadTags() async {
        let tags = (try? await api.referentialApi.getBookTags(
            seriesId: seriesId, readListId: nil, libraryIds: [])) ?? []
        availableTags = tags.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        selectedTags.formIntersection(availableTags)
    }

    private func handle(_ event: KomgaEvent) {
        switch event {
        case .seriesChanged(let p) where p.seriesId == seriesId:
            seriesReloader.request()
        case .bookAdded(let p), .bookChanged(let p), .bookDeleted(let p):
            if p.seriesId == seriesId { booksReloader.request() }
        case .readProgressChanged(let p), .readProgressDeleted(let p):
            if books.contains(where: { $0.id == p.bookId }) { booksReloader.request() }
        case .readProgressSeriesChanged(let p) where p.seriesId == seriesId:
            seriesReloader.request()
        default: break
        }
    }
}

/// Port of `SeriesScreen.kt` / `series/view`.
struct SeriesScreen: View {
    @State var model: SeriesViewModel
    @Environment(\.offlineController) private var offline
    let navigate: (Destination) -> Void
    let onRead: (SplashBook) -> Void

    var body: some View {
        Group {
            switch model.state {
            case .error(let error) where model.series == nil:
                ScreenErrorView(error: error, retry: { Task { await model.reload() } })
            case _ where model.series == nil:
                ProgressView()
            default:
                if let series = model.series { content(series) }
            }
        }
        .navigationTitle(model.series?.metadata.title ?? "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await model.initialize() }
        .refreshable { await model.reload() }
    }

    private func content(_ series: KomgaSeries) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SeriesHeader(series: series, library: model.library, navigate: navigate)
                    .padding(.horizontal)
                if let error = model.actionError {
                    Text(error).foregroundStyle(.red).font(.footnote).padding(.horizontal)
                }
                if !model.collections.isEmpty {
                    Picker("Section", selection: $model.currentTab) {
                        Text("Books").tag(SeriesViewModel.Tab.books)
                        Text("Collections").tag(SeriesViewModel.Tab.collections)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
                switch model.currentTab {
                case .books:
                    Picker("Show", selection: $model.downloadFilter) {
                        ForEach(BookDownloadFilter.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    CardGrid(items: model.books, cardWidth: model.cardWidth) { book in
                        Button { navigate(.book(book.id)) } label: { BookCard(book: book) }
                            .buttonStyle(.plain)
                            .contextMenu { bookMenu(book) }
                    }
                    PaginationBar(currentPage: model.currentPage, totalPages: model.totalPages) { page in
                        Task { await model.onPageChange(page) }
                    }
                case .collections:
                    CardGrid(items: model.collections, cardWidth: model.cardWidth) { item in
                        Button { navigate(.collection(item.id)) } label: { CollectionCard(collection: item) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical)
        }
        .toolbar {
            if let next = nextBook {
                Button { onRead(next) } label: { Label("Read", systemImage: "book") }
            }
            Menu {
                Picker("Sort", selection: $model.sort) {
                    Text("Number (ascending)").tag(BooksSortOption.numberAsc)
                    Text("Number (descending)").tag(BooksSortOption.numberDesc)
                }
                Divider()
                Button("Mark as read") { Task { await model.markAsRead() } }
                Button("Mark as unread") { Task { await model.markAsUnread() } }
                if let offline, !offline.isOfflineMode {
                    Divider()
                    Button { offline.download(series: model.seriesId) } label: {
                        Label("Download series", systemImage: "arrow.down.circle")
                    }
                    if model.books.contains(where: \.downloaded) {
                        Button("Delete downloaded books", role: .destructive) { offline.delete(series: model.seriesId) }
                    }
                }
                if !model.availableTags.isEmpty {
                    Divider()
                    tagFilterMenu
                }
                HideMenuButton(target: .series(model.seriesId))
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
        .onChange(of: model.sort) { Task { await model.onSortChange() } }
        .onChange(of: model.downloadFilter) { Task { await model.onDownloadFilterChange() } }
        .onChange(of: model.selectedTags) { Task { await model.onTagFilterChange() } }
    }

    private var tagFilterMenu: some View {
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

    /// First unfinished book on the current page (Kotlin's "read" shortcut picks the in-progress/unread one).
    private var nextBook: SplashBook? {
        model.books.first { $0.readProgress?.completed != true }
    }

    @ViewBuilder private func bookMenu(_ book: SplashBook) -> some View {
        Button { onRead(book) } label: { Label("Read", systemImage: "book") }
        if let offline, !offline.isOfflineMode {
            if book.downloaded {
                Button("Delete download", role: .destructive) { offline.delete(book: book.id) }
            } else {
                Button { offline.download(book: book.id) } label: { Label("Download", systemImage: "arrow.down.circle") }
            }
        }
        if book.readProgress?.completed == true {
            Button("Mark as unread") { Task { await model.markBookUnread(book) } }
        } else {
            Button("Mark as read") { Task { await model.markBookRead(book) } }
        }
        HideMenuButton(
            target: .book(book.id), downloadedBook: book,
            onDeleteDownload: offline.map { controller in { controller.delete(book: book.id) } })
    }
}

/// Series metadata block (`SeriesContent` header: cover, status, counts, summary, chips).
struct SeriesHeader: View {
    let series: KomgaSeries
    let library: KomgaLibrary?
    let navigate: (Destination) -> Void
    @State private var summaryExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                ThumbnailView(.seriesDefault(series.id))
                    .aspectRatio(0.703, contentMode: .fit)
                    .frame(width: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 6) {
                    Text(series.metadata.title).font(.title2.bold())
                    if let library { Text(library.name).foregroundStyle(.secondary) }
                    HStack {
                        Text(series.metadata.status.rawValue.capitalized)
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.tint.opacity(0.15), in: Capsule())
                        if let direction = series.metadata.readingDirection {
                            Text(direction.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("\(series.booksCount) books · \(series.booksUnreadCount) unread")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if !series.metadata.publisher.isEmpty {
                        Text(series.metadata.publisher).font(.subheadline)
                    }
                    if let year = series.releaseYear { Text(verbatim: String(year)).font(.subheadline) }
                }
            }
            let summary = series.metadata.summary.isEmpty ? series.booksMetadata.summary : series.metadata.summary
            if !summary.isEmpty {
                Text(summary)
                    .lineLimit(summaryExpanded ? nil : 4)
                    .onTapGesture { summaryExpanded.toggle() }
            }
            // Tags and genres browse; authors do not — there is no author destination.
            ChipRow(title: "Genres", values: series.metadata.genres) { navigate(.facet(.genre($0))) }
            ChipRow(title: "Tags", values: series.metadata.tags) { navigate(.facet(.tag($0))) }
            ChipRow(title: "Authors", values: Array(Set(series.booksMetadata.authors.map(\.name))).sorted())
        }
    }
}
