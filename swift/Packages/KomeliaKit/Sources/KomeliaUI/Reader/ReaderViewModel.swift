import CoreGraphics
import Foundation
import KomeliaCore
import KomeliaImage
import KomgaAPI
import Observation

/// Where "next/previous book" comes from (`BookSiblingsContext.kt`).
public enum BookSiblingsContext: Hashable, Sendable {
    case series
    case readList(KomgaReadListId)
}

/// `PageMetadata`
public struct PageMetadata: Hashable, Sendable, Identifiable {
    public let bookId: KomgaBookId
    public let pageNumber: Int
    public let size: CGSize?

    public var id: PageId { PageId(bookId: bookId, pageNumber: pageNumber) }
    public var isLandscape: Bool { size.map { $0.width > $0.height } ?? false }
}

/// `BookState`
public struct ReaderBooksState: Sendable {
    public var currentBook: KomeliaBook
    public var currentBookPages: [PageMetadata]
    public var previousBook: KomeliaBook?
    public var previousBookPages: [PageMetadata]
    public var nextBook: KomeliaBook?
    public var nextBookPages: [PageMetadata]
}

/// Port of `ReaderState.kt` + `ReaderViewModel.kt`: loads the book and its siblings, decides the reader type,
/// persists reader settings and reports read progress.
@MainActor
@Observable
public final class ReaderViewModel {
    public private(set) var state: LoadState<Void> = .uninitialized
    public private(set) var books: ReaderBooksState?
    public private(set) var series: KomgaSeries?
    public private(set) var readerType: ReaderType = .paged
    public private(set) var readProgressPage = 1
    public private(set) var notice: String?
    /// Set when the reader should close and show a screen instead (end of the last book).
    public private(set) var exitDestination: Destination?

    public let settings: ImageReaderSettingsRepository
    public let pages: PageImageLoader
    public let imageFactory = ReaderImageFactory()
    public let markReadProgress: Bool

    private let api: any KomgaApi
    private let siblings: BookSiblingsContext
    private let initialBookId: KomgaBookId

    public init(
        bookId: KomgaBookId, api: any KomgaApi, settings: ImageReaderSettingsRepository,
        siblings: BookSiblingsContext = .series, markReadProgress: Bool = true
    ) {
        self.initialBookId = bookId
        self.api = api
        self.settings = settings
        self.siblings = siblings
        self.markReadProgress = markReadProgress
        pages = PageImageLoader(api: { [api] in api })
    }

    public var currentBook: KomeliaBook? { books?.currentBook }

    public func initialize() async {
        guard state.isUninitialized else { return }
        state = .loading
        do {
            let book = try await api.bookApi.getOne(initialBookId)
            async let bookPages = loadPages(book.id)
            async let previous = previousBook(of: book.id)
            async let next = nextBook(of: book.id)
            async let series = api.seriesApi.getOneSeries(book.seriesId)
            let (prev, nxt) = try await (previous, next)
            async let prevPages = pagesOrEmpty(prev)
            async let nextPages = pagesOrEmpty(nxt)

            books = ReaderBooksState(
                currentBook: book, currentBookPages: try await bookPages,
                previousBook: prev, previousBookPages: try await prevPages,
                nextBook: nxt, nextBookPages: try await nextPages)

            if let progress = book.readProgress, !progress.completed {
                readProgressPage = progress.page
            } else {
                readProgressPage = 1
            }
            let loadedSeries = try await series
            self.series = loadedSeries
            readerType = Self.readerType(for: loadedSeries.metadata.readingDirection, fallback: settings.value.readerType)
            state = .success(())
        } catch {
            state = .error(error)
        }
    }

    /// Series reading direction wins over the user's default (`ReaderState.initialize`). PANELS is unsupported.
    nonisolated static func readerType(for direction: KomgaReadingDirection?, fallback: ReaderType) -> ReaderType {
        switch direction {
        case .leftToRight, .rightToLeft: .paged
        case .webtoon: .continuous
        case .vertical, nil: fallback == .panels ? .paged : fallback
        }
    }

    // MARK: Progress

    /// `onProgressChange(page)` — Komga marks the book completed itself when the last page is reported.
    public func onProgressChange(page: Int) {
        readProgressPage = page
        guard markReadProgress, let book = books?.currentBook else { return }
        Task {
            do {
                try await api.bookApi.markReadProgress(book.id, request: KomgaBookReadProgressUpdateRequest(page: page))
            } catch {
                notice = error.localizedDescription
            }
        }
    }

    // MARK: Book navigation

    public func loadNextBook() async {
        guard let current = books else { return }
        guard let next = current.nextBook else {
            exitDestination = current.currentBook.oneshot
                ? .oneshot(current.currentBook.seriesId) : .series(current.currentBook.seriesId)
            return
        }
        do {
            let following = try await nextBook(of: next.id)
            let followingPages = try await pagesOrEmpty(following)
            books = ReaderBooksState(
                currentBook: next, currentBookPages: current.nextBookPages,
                previousBook: current.currentBook, previousBookPages: current.currentBookPages,
                nextBook: following, nextBookPages: followingPages)
            readProgressPage = 1
            onProgressChange(page: 1)
        } catch {
            notice = error.localizedDescription
        }
    }

    public func loadPreviousBook() async {
        guard let current = books else { return }
        guard let previous = current.previousBook else {
            notice = String(localized: "You're at the beginning of the book")
            return
        }
        do {
            let preceding = try await previousBook(of: previous.id)
            let precedingPages = try await pagesOrEmpty(preceding)
            readProgressPage = current.previousBookPages.count
            books = ReaderBooksState(
                currentBook: previous, currentBookPages: current.previousBookPages,
                previousBook: preceding, previousBookPages: precedingPages,
                nextBook: current.currentBook, nextBookPages: current.currentBookPages)
        } catch {
            notice = error.localizedDescription
        }
    }

    public func dismissNotice() { notice = nil }

    // MARK: Settings (each `on…Change` persists, like ReaderState)

    public func setReaderType(_ type: ReaderType) {
        readerType = type
        Task { try? await settings.set(\.readerType, type) }
    }

    public func update(_ transform: @escaping @Sendable (inout ImageReaderSettings) -> Void) {
        Task { try? await settings.update(transform) }
    }

    // MARK: Loading helpers

    func loadPages(_ bookId: KomgaBookId) async throws -> [PageMetadata] {
        try await api.bookApi.getBookPages(bookId).map { page in
            let size = (page.width != nil && page.height != nil)
                ? CGSize(width: page.width!, height: page.height!) : nil
            return PageMetadata(bookId: bookId, pageNumber: page.number, size: size)
        }
    }

    private func pagesOrEmpty(_ book: KomeliaBook?) async throws -> [PageMetadata] {
        guard let book else { return [] }
        return try await loadPages(book.id)
    }

    private func nextBook(of id: KomgaBookId) async throws -> KomeliaBook? {
        switch siblings {
        case .series: try await api.bookApi.getBookSiblingNext(id)
        case .readList(let list): try await api.readListApi.getBookSiblingNext(list, bookId: id)
        }
    }

    private func previousBook(of id: KomgaBookId) async throws -> KomeliaBook? {
        switch siblings {
        case .series: try await api.bookApi.getBookSiblingPrevious(id)
        case .readList(let list): try await api.readListApi.getBookSiblingPrevious(list, bookId: id)
        }
    }
}
