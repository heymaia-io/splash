import SplashCore
import KomgaAPI
import Observation
import SwiftUI

/// Port of `CollectionViewModel.kt`.
@MainActor
@Observable
public final class CollectionViewModel {
    public let collectionId: KomgaCollectionId
    public private(set) var state: LoadState<Void> = .uninitialized
    public private(set) var collection: KomgaCollection?
    public private(set) var series: [KomgaSeries] = []
    public private(set) var currentPage = 1
    public private(set) var totalPages = 1

    private let api: any KomgaApi
    private let settings: CommonSettingsRepository
    private let events: KomgaEventSource
    private var eventTask: Task<Void, Never>?
    @ObservationIgnored private lazy var reloader = ReloadScheduler(cooldown: .seconds(1)) { [weak self] in
        guard let self else { return }
        await self.load(page: self.currentPage)
    }

    init(collectionId: KomgaCollectionId, api: any KomgaApi, settings: CommonSettingsRepository,
         events: KomgaEventSource) {
        self.collectionId = collectionId
        self.api = api
        self.settings = settings
        self.events = events
    }

    var cardWidth: CGFloat { CGFloat(settings.value.cardWidth) }

    public func initialize() async {
        guard state.isUninitialized else { return }
        eventTask = listen(to: events) { [weak self] event in
            guard let self else { return }
            switch event {
            case .collectionChanged(let p) where p.collectionId == self.collectionId: self.reloader.request()
            case .seriesChanged(let p) where self.series.contains(where: { $0.id == p.seriesId }):
                self.reloader.request()
            default: break
            }
        }
        await load(page: 1)
    }

    public func load(page: Int) async {
        if collection == nil { state = .loading }
        do {
            async let collection = api.collectionsApi.getOne(collectionId)
            async let series = api.collectionsApi.getSeriesForCollection(
                collectionId, query: nil,
                pageRequest: KomgaPageRequest(pageIndex: page - 1, size: settings.value.seriesPageLoadSize))
            self.collection = try await collection
            let result = try await series
            self.series = result.content
            currentPage = result.number + 1
            totalPages = max(result.totalPages, 1)
            state = .success(())
        } catch {
            state = .error(error)
        }
    }
}

struct CollectionScreen: View {
    @State var model: CollectionViewModel
    let navigate: (Destination) -> Void

    var body: some View {
        ScrollView {
            if case .error(let error) = model.state {
                ErrorView(error: error) { Task { await model.load(page: 1) } }
            }
            CardGrid(items: model.series, cardWidth: model.cardWidth) { item in
                Button { navigate(item.oneshot ? .oneshot(item.id) : .series(item.id)) } label: {
                    SeriesCard(series: item)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical)
            PaginationBar(currentPage: model.currentPage, totalPages: model.totalPages) { page in
                Task { await model.load(page: page) }
            }
        }
        .overlay { if model.state.isLoading { ProgressView() } }
        .navigationTitle(model.collection?.name ?? "")
        .task { await model.initialize() }
        .refreshable { await model.load(page: 1) }
    }
}

/// Port of `ReadListViewModel.kt`.
@MainActor
@Observable
public final class ReadListViewModel {
    public let readListId: KomgaReadListId
    public private(set) var state: LoadState<Void> = .uninitialized
    public private(set) var readList: KomgaReadList?
    public private(set) var books: [SplashBook] = []
    public private(set) var currentPage = 1
    public private(set) var totalPages = 1

    private let api: any KomgaApi
    private let settings: CommonSettingsRepository
    private let events: KomgaEventSource
    private var eventTask: Task<Void, Never>?
    @ObservationIgnored private lazy var reloader = ReloadScheduler(cooldown: .seconds(1)) { [weak self] in
        guard let self else { return }
        await self.load(page: self.currentPage)
    }

    init(readListId: KomgaReadListId, api: any KomgaApi, settings: CommonSettingsRepository,
         events: KomgaEventSource) {
        self.readListId = readListId
        self.api = api
        self.settings = settings
        self.events = events
    }

    var cardWidth: CGFloat { CGFloat(settings.value.cardWidth) }

    public func initialize() async {
        guard state.isUninitialized else { return }
        eventTask = listen(to: events) { [weak self] event in
            guard let self else { return }
            switch event {
            case .readListChanged(let p) where p.readListId == self.readListId: self.reloader.request()
            case .readProgressChanged(let p), .readProgressDeleted(let p):
                if self.books.contains(where: { $0.id == p.bookId }) { self.reloader.request() }
            default: break
            }
        }
        await load(page: 1)
    }

    public func load(page: Int) async {
        if readList == nil { state = .loading }
        do {
            async let readList = api.readListApi.getOne(readListId)
            async let books = api.readListApi.getBooksForReadList(
                readListId, query: nil,
                pageRequest: KomgaPageRequest(pageIndex: page - 1, size: settings.value.bookPageLoadSize))
            self.readList = try await readList
            let result = try await books
            self.books = result.content
            currentPage = result.number + 1
            totalPages = max(result.totalPages, 1)
            state = .success(())
        } catch {
            state = .error(error)
        }
    }
}

struct ReadListScreen: View {
    @State var model: ReadListViewModel
    let navigate: (Destination) -> Void

    var body: some View {
        ScrollView {
            if let summary = model.readList?.summary, !summary.isEmpty {
                Text(summary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
            }
            if case .error(let error) = model.state {
                ErrorView(error: error) { Task { await model.load(page: 1) } }
            }
            CardGrid(items: model.books, cardWidth: model.cardWidth) { book in
                Button { navigate(.book(book.id)) } label: { BookCard(book: book, showSeries: true) }
                    .buttonStyle(.plain)
            }
            .padding(.vertical)
            PaginationBar(currentPage: model.currentPage, totalPages: model.totalPages) { page in
                Task { await model.load(page: page) }
            }
        }
        .overlay { if model.state.isLoading { ProgressView() } }
        .navigationTitle(model.readList?.name ?? "")
        .task { await model.initialize() }
        .refreshable { await model.load(page: 1) }
    }
}
