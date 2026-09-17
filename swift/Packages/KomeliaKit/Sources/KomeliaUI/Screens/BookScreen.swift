import KomeliaCore
import KomgaAPI
import Observation
import SwiftUI

/// Port of `BookViewModel.kt` (+ `BookReadListsState`).
@MainActor
@Observable
public final class BookViewModel {
    public let bookId: KomgaBookId
    public private(set) var state: LoadState<Void> = .uninitialized
    public private(set) var book: KomeliaBook?
    public private(set) var readLists: [KomgaReadList] = []
    public private(set) var actionError: String?

    private let api: any KomgaApi
    private let authState: KomgaAuthenticationState
    private let events: KomgaEventSource
    private var eventTask: Task<Void, Never>?
    @ObservationIgnored private lazy var reloader = ReloadScheduler(cooldown: .seconds(1)) { [weak self] in
        await self?.loadBook()
    }

    init(bookId: KomgaBookId, api: any KomgaApi, authState: KomgaAuthenticationState, events: KomgaEventSource) {
        self.bookId = bookId
        self.api = api
        self.authState = authState
        self.events = events
    }

    public var library: KomgaLibrary? { book.flatMap { b in authState.libraries.first { $0.id == b.libraryId } } }

    public func initialize() async {
        guard state.isUninitialized else { return }
        eventTask = listen(to: events) { [weak self] event in
            guard let self else { return }
            switch event {
            case .bookChanged(let p) where p.bookId == self.bookId: self.reloader.request()
            case .readProgressChanged(let p) where p.bookId == self.bookId: self.reloader.request()
            case .readProgressDeleted(let p) where p.bookId == self.bookId: self.reloader.request()
            default: break
            }
        }
        await loadBook()
        readLists = (try? await api.bookApi.getAllReadListsByBook(bookId)) ?? []
    }

    public func reload() async { await loadBook() }

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
            actionError = error.localizedDescription
        }
    }

    func loadBook() async {
        if book == nil { state = .loading }
        do {
            book = try await api.bookApi.getOne(bookId)
            state = .success(())
        } catch {
            state = .error(error)
        }
    }
}

/// Port of `BookScreenContent.kt` / `BookInfoContent.kt`.
struct BookScreen: View {
    @State var model: BookViewModel
    let navigate: (Destination) -> Void
    let onRead: (KomeliaBook) -> Void

    var body: some View {
        Group {
            switch model.state {
            case .error(let error) where model.book == nil:
                ErrorView(error: error) { Task { await model.reload() } }
            case _ where model.book == nil:
                ProgressView()
            default:
                if let book = model.book { BookDetails(book: book, library: model.library, model: model,
                                                       navigate: navigate, onRead: onRead) }
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
    let book: KomeliaBook
    let library: KomgaLibrary?
    let model: BookViewModel
    let navigate: (Destination) -> Void
    let onRead: (KomeliaBook) -> Void

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
                        Button { onRead(book) } label: {
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
                ChipRow(title: "Tags", values: book.metadata.tags.sorted())
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
            }
            .padding()
        }
        .toolbar {
            Menu {
                Button("Mark as read") { Task { await model.markAsRead() } }
                Button("Mark as unread") { Task { await model.markAsUnread() } }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
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

    init(seriesId: KomgaSeriesId, api: any KomgaApi, authState: KomgaAuthenticationState, events: KomgaEventSource) {
        self.seriesId = seriesId
        self.api = api
        self.authState = authState
        self.events = events
    }

    public func initialize() async {
        guard state.isUninitialized else { return }
        state = .loading
        do {
            let books = try await api.bookApi.getBookList(
                search: KomgaBookSearch(condition: .allOfBooks(.seriesId(.isEqualTo(seriesId)))),
                pageRequest: KomgaPageRequest(size: 1))
            guard let book = books.content.first else { throw KomgaAPIError.httpStatus(code: 404, body: Data()) }
            bookModel = BookViewModel(bookId: book.id, api: api, authState: authState, events: events)
            state = .success(())
        } catch {
            state = .error(error)
        }
    }
}

struct OneshotScreen: View {
    @State var model: OneshotViewModel
    let navigate: (Destination) -> Void
    let onRead: (KomeliaBook) -> Void

    var body: some View {
        Group {
            if let bookModel = model.bookModel {
                BookScreen(model: bookModel, navigate: navigate, onRead: onRead)
            } else if case .error(let error) = model.state {
                ErrorView(error: error) {}
            } else {
                ProgressView()
            }
        }
        .task { await model.initialize() }
    }
}
