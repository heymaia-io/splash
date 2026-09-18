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
    public private(set) var collections: [KomgaCollection] = []
    public private(set) var actionError: String?

    private let api: any KomgaApi
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

    private let hiddenFilter: @MainActor () -> HiddenContentFilter

    init(seriesId: KomgaSeriesId, api: any KomgaApi, authState: KomgaAuthenticationState,
         settings: CommonSettingsRepository, events: KomgaEventSource,
         hiddenFilter: @escaping @MainActor () -> HiddenContentFilter = { .disabled }) {
        self.hiddenFilter = hiddenFilter
        self.seriesId = seriesId
        self.api = api
        self.authState = authState
        self.settings = settings
        self.events = events
    }

    public var library: KomgaLibrary? { series.flatMap { s in authState.libraries.first { $0.id == s.libraryId } } }
    public var cardWidth: CGFloat { CGFloat(settings.value.cardWidth) }

    public func initialize() async {
        guard state.isUninitialized else { return }
        eventTask = listen(to: events) { [weak self] event in self?.handle(event) }
        await loadSeries()
        async let books: Void = loadBooks(page: 1)
        async let collections: Void = loadCollections()
        _ = await (books, collections)
    }

    public func reload() async {
        await loadSeries()
        await loadBooks(page: 1)
    }

    public func onPageChange(_ page: Int) async { await loadBooks(page: page) }
    public func onSortChange() async { await loadBooks(page: 1) }

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
            actionError = error.localizedDescription
        }
    }

    // MARK: Loading

    private func loadSeries() async {
        if series == nil { state = .loading }
        do {
            var loaded = try await api.seriesApi.getOneSeries(seriesId)
            loaded.metadata.tags.sort()  // `withSortedTags()`
            loaded.metadata.genres.sort()
            series = loaded
            state = .success(())
        } catch {
            state = .error(error)
        }
    }

    func loadBooks(page: Int) async {
        let hidden = hiddenFilter()
        do {
            // Book exclusion *is* exact server-side (`BookCondition` has both library and series ids), so
            // pagination stays correct here — unlike series lists.
            let result = try await api.bookApi.getBookList(
                search: KomgaBookSearch(
                    condition: .allOf([.seriesId(.isEqualTo(seriesId))] + hidden.bookConditions)),
                pageRequest: KomgaPageRequest(
                    pageIndex: page - 1, size: settings.value.bookPageLoadSize, sort: sort.komgaSort))
            books = hidden.visible(result.content)
            currentPage = result.number + 1
            totalPages = max(result.totalPages, 1)
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func loadCollections() async {
        collections = (try? await api.seriesApi.getAllCollectionsBySeries(seriesId)) ?? []
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
                SeriesHeader(series: series, library: model.library)
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
                Divider()
                HideMenuButton(target: .series(model.seriesId))
                if let offline, !offline.isOfflineMode {
                    Divider()
                    Button { offline.download(series: model.seriesId) } label: {
                        Label("Download series", systemImage: "arrow.down.circle")
                    }
                    if model.books.contains(where: \.downloaded) {
                        Button("Delete downloaded books", role: .destructive) { offline.delete(series: model.seriesId) }
                    }
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
        .onChange(of: model.sort) { Task { await model.onSortChange() } }
    }

    /// First unfinished book on the current page (Kotlin's "read" shortcut picks the in-progress/unread one).
    private var nextBook: SplashBook? {
        model.books.first { $0.readProgress?.completed != true }
    }

    @ViewBuilder private func bookMenu(_ book: SplashBook) -> some View {
        Button { onRead(book) } label: { Label("Read", systemImage: "book") }
        HideMenuButton(target: .book(book.id, isDownloaded: book.downloaded))
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
    }
}

/// Series metadata block (`SeriesContent` header: cover, status, counts, summary, chips).
struct SeriesHeader: View {
    let series: KomgaSeries
    let library: KomgaLibrary?
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
            ChipRow(title: "Genres", values: series.metadata.genres)
            ChipRow(title: "Tags", values: series.metadata.tags)
            ChipRow(title: "Authors", values: Array(Set(series.booksMetadata.authors.map(\.name))).sorted())
        }
    }
}

struct ChipRow: View {
    let title: LocalizedStringKey
    let values: [String]

    var body: some View {
        if !values.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption.bold()).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(values, id: \.self) { value in
                            Text(value).font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
            }
        }
    }
}
