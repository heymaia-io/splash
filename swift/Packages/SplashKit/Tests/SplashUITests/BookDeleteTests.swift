import Foundation
import KomgaAPI
import Synchronization
import Testing
@testable import SplashCore
@testable import SplashUI

/// Deleting a book is the one irreversible action in the app, so the sequence is pinned down: the server
/// call, waiting for Komga to actually move the book to its trash, then emptying that trash — and never
/// offering any of it to a user Komga would refuse anyway.
final class GoneIds: @unchecked Sendable {
    private let ids = Mutex<Set<String>>([])
    func insert(_ id: String) { ids.withLock { _ = $0.insert(id) } }
    func contains(_ id: String) -> Bool { ids.withLock { $0.contains(id) } }
}

@MainActor
@Suite struct BookDeleteTests {
    @MainActor private struct Harness {
        let books = RecordingBookApi()
        let library = RecordingLibraryApi()
        let events = KomgaEventBroadcaster()
        let auth = KomgaAuthenticationState()
        /// Ids Komga has "deleted" so far: `getOne` then serves them flagged `deleted`, like its trash does.
        let gone = GoneIds()
        let book: SplashBook

        init(book: SplashBook = Fixture.book(), admin: Bool = true) {
            self.book = book
            let gone = self.gone
            books.onGetOne = { id in gone.contains(id.rawValue) ? Fixture.book(id.rawValue, deleted: true) : book }
            books.onGetBookPages = { _ in Fixture.pages(book.media.pagesCount) }
            auth.setStateValues(user: Fixture.user(admin: admin), libraries: [])
        }

        var api: StubKomgaApi { StubKomgaApi(bookApi: books, libraryApi: library) }

        func model(allowsServerDelete: Bool = true) -> BookViewModel {
            BookViewModel(bookId: book.id, api: api, authState: auth, events: events,
                          allowsServerDelete: allowsServerDelete)
        }

    }

    /// Komga's real sequence: the delete task removes the file, soft-deletes the book (`deleted = true`) and
    /// announces it with `bookChanged`; `bookDeleted` only follows once the trash is emptied.
    @Test func deletesTheFileThenEmptiesTheLibraryTrashOnceKomgaConfirms() async throws {
        let h = Harness()
        let (events, gone) = (h.events, h.gone)
        let (id, seriesId, libraryId) = (h.book.id, h.book.seriesId, h.book.libraryId)
        h.books.onDeleteBook = { _ in
            Task {
                try await Task.sleep(for: .milliseconds(20))
                gone.insert(id.rawValue)
                events.emit(.bookChanged(.init(bookId: id, seriesId: seriesId, libraryId: libraryId)))
            }
        }
        let model = h.model()
        await model.initialize()

        let deleted = await model.deleteBook()

        #expect(deleted)
        #expect(h.books.calls == [.deleteBook(h.book.id)])
        #expect(h.library.emptiedTrash == [h.book.libraryId])
        #expect(model.actionError == nil)
        #expect(!model.isDeleting)
    }

    @Test func fallsBackToATimeoutWhenTheEventNeverArrives() async throws {
        let h = Harness()
        // No event, but the book is provably gone (flagged deleted), so the timeout fallback counts as success.
        let (gone, id) = (h.gone, h.book.id)
        h.books.onDeleteBook = { _ in gone.insert(id.rawValue) }
        try await ServerFileDeleter.deleteAndEmptyTrash(
            BookTarget(book: h.book), api: h.api, events: h.events, timeout: .milliseconds(50))
        #expect(h.books.calls == [.deleteBook(h.book.id)])
        #expect(h.library.emptiedTrash == [h.book.libraryId])
    }

    @Test func aBookThatIsNotFoundAnymoreCountsAsGone() async throws {
        let h = Harness()
        h.books.onGetOne = { _ in throw KomgaAPIError.httpStatus(code: 404, body: Data()) }
        try await ServerFileDeleter.deleteAndEmptyTrash(
            BookTarget(book: h.book), api: h.api, events: h.events, timeout: .milliseconds(50))
        #expect(h.library.emptiedTrash == [h.book.libraryId])
    }

    @Test func reportsAFailureWhenKomgaAcceptedTheDeleteButTheBookIsStillThere() async {
        // The silent failure seen on a real server: 202 accepted, no event, file still on disk.
        let h = Harness()
        let result = await ServerFileDeleter.delete(
            [BookTarget(book: h.book)], api: h.api, events: h.events, timeout: .milliseconds(50))
        #expect(result.deleted.isEmpty)
        #expect(result.failures.first?.error is ServerFileDeleter.NotDeleted)
        #expect(result.errorSummary != nil)
        #expect(h.library.emptiedTrash.isEmpty)
    }

    @Test func anUnrelatedChangedEventDoesNotMakeAStillPresentBookCountAsDeleted() async {
        let h = Harness()
        let (events, book) = (h.events, h.book)
        h.books.onDeleteBook = { _ in
            events.emit(.bookChanged(.init(bookId: book.id, seriesId: book.seriesId, libraryId: book.libraryId)))
        }
        let result = await ServerFileDeleter.delete(
            [BookTarget(book: book)], api: h.api, events: h.events, timeout: .milliseconds(50))
        #expect(result.deleted.isEmpty)
        #expect(result.failures.first?.error is ServerFileDeleter.NotDeleted)
    }

    @Test func aFailedDeleteNeverTouchesTheTrash() async {
        let h = Harness()
        h.books.onDeleteBook = { _ in throw KomgaAPIError.httpStatus(code: 403, body: Data()) }
        let model = h.model()
        await model.initialize()

        let deleted = await model.deleteBook()

        #expect(!deleted)
        #expect(h.library.emptiedTrash.isEmpty)
        #expect(model.actionError != nil)
    }

    @Test func aFailedTrashCleanupStillCountsAsDeletedButIsReported() async {
        let h = Harness()
        let (events, gone, book) = (h.events, h.gone, h.book)
        h.books.onDeleteBook = { _ in
            gone.insert(book.id.rawValue)
            events.emit(.bookDeleted(.init(bookId: book.id, seriesId: book.seriesId, libraryId: book.libraryId)))
        }
        h.library.onEmptyTrash = { _ in throw KomgaAPIError.httpStatus(code: 500, body: Data()) }
        let model = h.model()
        await model.initialize()

        let deleted = await model.deleteBook()

        #expect(deleted)
        #expect(model.actionError?.contains("trash") == true)
    }

    @Test func aBatchKeepsGoingPastOneFailureAndEmptiesEachLibraryOnce() async {
        let a = Fixture.book("a", library: "L1"), b = Fixture.book("b", library: "L1")
        let c = Fixture.book("c", library: "L2")
        let h = Harness()
        let gone = h.gone
        h.books.onDeleteBook = { id in
            if id == b.id { throw KomgaAPIError.httpStatus(code: 500, body: Data()) }
            gone.insert(id.rawValue)
        }
        h.books.onGetOne = { id in gone.contains(id.rawValue) ? Fixture.book(id.rawValue, deleted: true) : b }

        let result = await ServerFileDeleter.delete(
            [a, b, c].map(BookTarget.init(book:)), api: h.api, events: h.events, timeout: .milliseconds(50))

        #expect(result.deleted.map(\.id) == ["a", "c"])
        #expect(result.failures.map(\.target.id) == ["b"])
        #expect(h.library.emptiedTrash == [a.libraryId, c.libraryId])
    }

    @Test func onlyAdminsOnTheLiveApiMayDelete() async {
        let admin = Harness(admin: true)
        #expect(admin.model().canDelete)
        #expect(!admin.model(allowsServerDelete: false).canDelete)

        let user = Harness(admin: false)
        let model = user.model()
        #expect(!model.canDelete)
        await model.initialize()
        let deleted = await model.deleteBook()
        #expect(!deleted)
        #expect(user.books.calls.isEmpty)
    }

    @Test func pagesLoadOnlyForReadyImageBooks() async {
        let ready = Harness()
        let readyModel = ready.model()
        await readyModel.initialize()
        #expect(readyModel.pages.value?.count == 10)

        let analysing = Harness(book: Fixture.book(status: .unknown))
        let analysingModel = analysing.model()
        await analysingModel.initialize()
        #expect(analysingModel.pages.isUninitialized)

        let epub = Harness(book: Fixture.book(mediaProfile: .epub))
        let epubModel = epub.model()
        await epubModel.initialize()
        #expect(epubModel.pages.isUninitialized)

        let fixedLayoutEpub = Harness(book: Fixture.book(mediaProfile: .epub, epubDivinaCompatible: true))
        let fixedModel = fixedLayoutEpub.model()
        await fixedModel.initialize()
        #expect(fixedModel.pages.value?.count == 10)
    }

    @Test func pageAspectRatioFallsBackToTheCoverRatio() {
        let sized = KomgaBookPage(number: 1, fileName: "", mediaType: "", width: 2000, height: 1000, sizeBytes: nil, size: "")
        #expect(BookPagesGrid.aspectRatio(of: sized) == 2)
        let unsized = KomgaBookPage(number: 1, fileName: "", mediaType: "", width: nil, height: nil, sizeBytes: nil, size: "")
        #expect(abs(BookPagesGrid.aspectRatio(of: unsized) - 0.703) < 0.001)
    }
}
