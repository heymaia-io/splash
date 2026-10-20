import Foundation
import KomgaAPI
import Testing
@testable import SplashCore
@testable import SplashUI

/// Deleting a book is the one irreversible action in the app, so the sequence is pinned down: the server
/// call, waiting for Komga to actually move the book to its trash, then emptying that trash — and never
/// offering any of it to a user Komga would refuse anyway.
@MainActor
@Suite struct BookDeleteTests {
    @MainActor private struct Harness {
        let books = RecordingBookApi()
        let library = RecordingLibraryApi()
        let events = KomgaEventBroadcaster()
        let auth = KomgaAuthenticationState()
        let book: SplashBook

        init(book: SplashBook = Fixture.book(), admin: Bool = true) {
            self.book = book
            books.onGetOne = { _ in book }
            books.onGetBookPages = { _ in Fixture.pages(book.media.pagesCount) }
            auth.setStateValues(user: Fixture.user(admin: admin), libraries: [])
        }

        var api: StubKomgaApi { StubKomgaApi(bookApi: books, libraryApi: library) }

        func model(allowsServerDelete: Bool = true) -> BookViewModel {
            BookViewModel(bookId: book.id, api: api, authState: auth, events: events,
                          allowsServerDelete: allowsServerDelete)
        }

        func deletedEvent() -> KomgaEvent {
            .bookDeleted(.init(bookId: book.id, seriesId: book.seriesId, libraryId: book.libraryId))
        }
    }

    @Test func deletesTheFileThenEmptiesTheLibraryTrashOnceKomgaConfirms() async throws {
        let h = Harness()
        // The delete returns 202 and Komga finishes asynchronously; the app must wait for the event.
        let (events, event) = (h.events, h.deletedEvent())
        h.books.onDeleteBook = { _ in
            Task { try await Task.sleep(for: .milliseconds(20)); events.emit(event) }
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
        try await BookDeleter.deleteAndEmptyTrash(h.book, api: h.api, events: h.events, timeout: .milliseconds(50))
        #expect(h.books.calls == [.deleteBook(h.book.id)])
        #expect(h.library.emptiedTrash == [h.book.libraryId])
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
        let (events, event) = (h.events, h.deletedEvent())
        h.books.onDeleteBook = { _ in events.emit(event) }
        h.library.onEmptyTrash = { _ in throw KomgaAPIError.httpStatus(code: 500, body: Data()) }
        let model = h.model()
        await model.initialize()

        let deleted = await model.deleteBook()

        #expect(deleted)
        #expect(model.actionError?.contains("trash") == true)
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
