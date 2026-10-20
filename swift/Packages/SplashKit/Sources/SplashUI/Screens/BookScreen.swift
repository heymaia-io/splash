import SplashCore
import KomgaAPI
import Observation
import SwiftUI

/// Port of `BookViewModel.kt` (+ `BookReadListsState`).
@MainActor
@Observable
public final class BookViewModel {
    public let bookId: KomgaBookId
    public private(set) var state: LoadState<Void> = .uninitialized
    public private(set) var book: SplashBook?
    public private(set) var readLists: [KomgaReadList] = []
    /// The book's pages for the thumbnail grid; stays `.uninitialized` while the media is not ready.
    public private(set) var pages: LoadState<[KomgaBookPage]> = .uninitialized
    public private(set) var actionError: String?
    public private(set) var isDeleting = false

    private let api: any KomgaApi
    private let authState: KomgaAuthenticationState
    private let events: KomgaEventSource
    /// False when `api` is the offline store, whose `deleteBook` only drops the local download.
    private let allowsServerDelete: Bool
    private var eventTask: Task<Void, Never>?
    @ObservationIgnored private lazy var reloader = ReloadScheduler(cooldown: .seconds(1)) { [weak self] in
        await self?.loadBook()
    }

    /// A provider, not a snapshot: re-read per fetch so unlocking reveals the item without a rebuild.
    private let hiddenFilter: @MainActor () -> HiddenContentFilter

    init(bookId: KomgaBookId, api: any KomgaApi, authState: KomgaAuthenticationState, events: KomgaEventSource,
         allowsServerDelete: Bool = true,
         hiddenFilter: @escaping @MainActor () -> HiddenContentFilter = { .disabled }) {
        self.bookId = bookId
        self.api = api
        self.authState = authState
        self.events = events
        self.allowsServerDelete = allowsServerDelete
        self.hiddenFilter = hiddenFilter
    }

    public var library: KomgaLibrary? { book.flatMap { b in authState.libraries.first { $0.id == b.libraryId } } }

    /// Deleting a file is an ADMIN-only Komga call; other roles never see the action.
    public var canDelete: Bool { allowsServerDelete && (authState.authenticatedUser?.isAdmin ?? false) }

    public func initialize() async {
        guard state.isUninitialized else { return }
        eventTask = listen(to: events) { [weak self] event in
            guard let self else { return }
            switch event {
            case .bookChanged(let p) where p.bookId == self.bookId: self.reloader.request()
            case .readProgressChanged(let p) where p.bookId == self.bookId: self.reloader.request()
            case .readProgressDeleted(let p) where p.bookId == self.bookId: self.reloader.request()
            // Our own delete: reloading would only surface a 404 while the screen is being popped.
            case .bookDeleted(let p) where p.bookId == self.bookId: break
            default: break
            }
        }
        await loadBook()
        async let lists = api.bookApi.getAllReadListsByBook(bookId)
        await loadPagesIfNeeded()
        readLists = (try? await lists) ?? []
    }

    public func reload() async {
        await loadBook()
        await loadPagesIfNeeded()
    }

    /// Fetches the page list once per analysed version of the book. EPUBs have no image pages unless Komga
    /// marks them DiViNa-compatible, so they keep the grid hidden.
    public func loadPagesIfNeeded() async {
        guard pages.isUninitialized, let book, book.media.status == .ready,
              book.media.mediaProfile != .epub || book.media.epubDivinaCompatible
        else { return }
        pages = .loading
        do {
            pages = .success(try await api.bookApi.getBookPages(bookId))
        } catch {
            if error.isCancellation { pages = .uninitialized } else { pages = .error(error) }
        }
    }

    /// Deletes the file on the server and empties the library trash. Returns true when the file is gone,
    /// even if emptying the trash failed — that failure is reported through `actionError` instead.
    public func deleteBook() async -> Bool {
        guard let book, canDelete, !isDeleting else { return false }
        isDeleting = true
        actionError = nil
        defer { isDeleting = false }
        do {
            try await BookDeleter.deleteAndEmptyTrash(book, api: api, events: events)
            return true
        } catch let error as BookDeleter.TrashNotEmptied {
            actionError = error.localizedDescription
            return true
        } catch {
            if !error.isCancellation { actionError = error.localizedDescription }
            return false
        }
    }

    public func markAsRead() async {
        await perform { try await $0.bookApi.markReadProgress(self.bookId, request: .init(completed: true)) }
    }

    public func markAsUnread() async {
        await perform { try await $0.bookApi.deleteReadProgress(self.bookId) }
    }

    private func perform(_ action: @escaping (any KomgaApi) async throws -> Void) async {
        do {
            actionError = nil
            try await action(api)
            await loadBook()
        } catch {
            if !error.isCancellation { actionError = error.localizedDescription }
        }
    }

    func loadBook() async {
        if book == nil { state = .loading }
        do {
            let loaded = try await api.bookApi.getOne(bookId)
            // A detail screen bypasses every listing, so it has to refuse a hidden item itself — reached by
            // a stale navigation stack, or by opening a book directly. The error is the ordinary 404 the
            // server would give for a book that does not exist: no separate "this is private" state, which
            // would confirm to a snooper that there is something here.
            guard !hiddenFilter().isHidden(book: loaded) else {
                book = nil
                throw KomgaAPIError.httpStatus(code: 404, body: Data())
            }
            // A re-analysis changes the page list, so let the grid fetch it again.
            if let previous = book, previous.media.pagesCount != loaded.media.pagesCount
                || previous.media.status != loaded.media.status {
                pages = .uninitialized
            }
            book = loaded
            state = .success(())
        } catch {
            if !error.isCancellation { state = .error(error) }
        }
    }
}

/// Port of `BookScreenContent.kt` / `BookInfoContent.kt`.
struct BookScreen: View {
    @State var model: BookViewModel
    let navigate: (Destination) -> Void
    let onRead: (ReadRequest) -> Void
    /// Called once the book no longer exists on the server, so the owner can leave this screen.
    var onDeleted: () -> Void = {}

    var body: some View {
        Group {
            switch model.state {
            case .error(let error) where model.book == nil:
                ScreenErrorView(error: error, retry: { Task { await model.reload() } })
            case _ where model.book == nil:
                ProgressView()
            default:
                if let book = model.book { BookDetails(book: book, library: model.library, model: model,
                                                       navigate: navigate, onRead: onRead, onDeleted: onDeleted) }
            }
        }
        .navigationTitle(model.book?.metadata.title ?? "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await model.initialize() }
        .refreshable { await model.reload() }
    }
}

struct BookDetails: View {
    let book: SplashBook
    let library: KomgaLibrary?
    let model: BookViewModel
    let navigate: (Destination) -> Void
    let onRead: (ReadRequest) -> Void
    let onDeleted: () -> Void
    @Environment(\.offlineController) private var offline
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    ThumbnailView(.bookDefault(book.id))
                        .aspectRatio(0.703, contentMode: .fit)
                        .frame(width: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 6) {
                        if !book.oneshot {
                            Button(book.seriesTitle) { navigate(.series(book.seriesId)) }
                                .font(.subheadline)
                        }
                        Text(book.metadata.title).font(.title2.bold())
                        if !book.oneshot {
                            Text("Book \(book.metadata.number)").foregroundStyle(.secondary)
                        }
                        Text("\(book.media.pagesCount) pages · \(book.size)").font(.subheadline)
                        if let release = book.metadata.releaseDate {
                            Text(verbatim: release.description).font(.subheadline).foregroundStyle(.secondary)
                        }
                        progressLabel
                        Button { onRead(ReadRequest(book: book)) } label: {
                            Label(readButtonTitle, systemImage: "book")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(book.media.status != .ready)
                        BookDownloadButton(book: book)
                    }
                }
                if let error = model.actionError {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
                if !book.metadata.summary.isEmpty { Text(book.metadata.summary) }
                ChipRow(title: "Authors", values: book.metadata.authors.map { "\($0.name) (\($0.role))" })
                ChipRow(title: "Tags", values: book.metadata.tags.sorted()) { navigate(.facet(.tag($0))) }
                if !model.readLists.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Read lists").font(.headline)
                        ForEach(model.readLists) { list in
                            Button(list.name) { navigate(.readList(list.id)) }
                        }
                    }
                }
                GroupBox("File") {
                    LabeledContent("Path", value: book.url)
                    LabeledContent("Format", value: book.media.mediaType ?? "—")
                    if let library { LabeledContent("Library", value: library.name) }
                }
                .font(.footnote)
                if !model.pages.isUninitialized {
                    Text("Pages").font(.headline)
                    BookPagesGrid(bookId: book.id, pages: model.pages) { page in
                        onRead(ReadRequest(book: book, page: page))
                    }
                }
            }
            .padding()
        }
        .toolbar {
            if model.isDeleting {
                ProgressView()
            } else {
                Menu {
                    Button("Mark as read") { Task { await model.markAsRead() } }
                    Button("Mark as unread") { Task { await model.markAsUnread() } }
                    HideMenuButton(
                        target: .book(book.id), downloadedBook: book,
                        onDeleteDownload: offline.map { controller in { controller.delete(book: book.id) } })
                    if model.canDelete {
                        Divider()
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Delete book", systemImage: "trash")
                        }
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            BookDeleteDialog.title(for: book), isPresented: $confirmDelete, titleVisibility: .visible
        ) {
            Button(BookDeleteDialog.confirm, role: .destructive) {
                Task { if await model.deleteBook() { onDeleted() } }
            }
        } message: {
            Text(BookDeleteDialog.warning)
        }
    }

    private var readButtonTitle: LocalizedStringKey {
        guard let progress = book.readProgress else { return "Read" }
        return progress.completed ? "Read again" : "Continue (page \(progress.page))"
    }

    @ViewBuilder private var progressLabel: some View {
        if let progress = book.readProgress {
            if progress.completed {
                Label("Read", systemImage: "checkmark.circle").font(.subheadline).foregroundStyle(.green)
            } else {
                ProgressView(value: Double(progress.page), total: Double(max(book.media.pagesCount, 1)))
                    .frame(maxWidth: 200)
            }
        }
    }
}

/// Port of `OneshotViewModel.kt`: a oneshot series is shown as its single book.
@MainActor
@Observable
public final class OneshotViewModel {
    public let seriesId: KomgaSeriesId
    public private(set) var state: LoadState<Void> = .uninitialized
    public private(set) var bookModel: BookViewModel?

    private let api: any KomgaApi
    private let authState: KomgaAuthenticationState
    private let events: KomgaEventSource
    private let allowsServerDelete: Bool

    private let hiddenFilter: @MainActor () -> HiddenContentFilter

    init(seriesId: KomgaSeriesId, api: any KomgaApi, authState: KomgaAuthenticationState, events: KomgaEventSource,
         allowsServerDelete: Bool = true,
         hiddenFilter: @escaping @MainActor () -> HiddenContentFilter = { .disabled }) {
        self.seriesId = seriesId
        self.api = api
        self.authState = authState
        self.events = events
        self.allowsServerDelete = allowsServerDelete
        self.hiddenFilter = hiddenFilter
    }

    public func initialize() async {
        guard state.isUninitialized else { return }
        state = .loading
        do {
            let hidden = hiddenFilter()
            let conditions: [BookCondition] = [.seriesId(.isEqualTo(seriesId))] + hidden.bookConditions
            let books = try await api.bookApi.getBookList(
                search: KomgaBookSearch(condition: .allOf(conditions)), pageRequest: KomgaPageRequest(size: 1))
            // A hidden oneshot is indistinguishable from one that does not exist — same 404, no oracle.
            guard let book = hidden.visible(books.content).first else {
                throw KomgaAPIError.httpStatus(code: 404, body: Data())
            }
            bookModel = BookViewModel(
                bookId: book.id, api: api, authState: authState, events: events,
                allowsServerDelete: allowsServerDelete, hiddenFilter: hiddenFilter)
            state = .success(())
        } catch {
            if !error.isCancellation { state = .error(error) }
        }
    }
}

struct OneshotScreen: View {
    @State var model: OneshotViewModel
    let navigate: (Destination) -> Void
    let onRead: (ReadRequest) -> Void
    var onDeleted: () -> Void = {}

    var body: some View {
        Group {
            if let bookModel = model.bookModel {
                BookScreen(model: bookModel, navigate: navigate, onRead: onRead, onDeleted: onDeleted)
            } else if case .error(let error) = model.state {
                ErrorView(error: error) {}
            } else {
                ProgressView()
            }
        }
        .task { await model.initialize() }
    }
}
