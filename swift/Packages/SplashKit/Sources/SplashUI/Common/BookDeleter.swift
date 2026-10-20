import KomgaAPI
import SwiftUI

/// Removes a book from the Komga server for good: delete its file, then empty the library's trash so the
/// book does not linger as "Unavailable" until the next manual clean-up. Komga has no restorable recycle
/// bin for user-initiated deletes, which is why the UI asks for confirmation before calling this.
///
/// `DELETE /books/{id}/file` is accepted (202) and carried out by a server task, so emptying the trash
/// straight away could run before the book has been moved there. The call therefore waits for the
/// `bookDeleted` event for this book, with `timeout` as the fallback when the event never arrives (SSE
/// down, slow server). Emptying the trash is best effort: its failure is reported to the caller only after
/// the file is already gone.
enum BookDeleter {
    struct TrashNotEmptied: Error {
        let underlying: any Error
    }

    @MainActor
    static func deleteAndEmptyTrash(
        _ book: SplashBook, api: any KomgaApi, events: KomgaEventSource, timeout: Duration = .seconds(10)
    ) async throws {
        // Subscribe before the request: a fast server could otherwise emit the event before we listen.
        let stream = events.subscribe()
        try await api.bookApi.deleteBook(book.id)
        await waitForDeletion(of: book.id, on: stream, timeout: timeout)
        do {
            try await api.libraryApi.emptyTrash(book.libraryId)
        } catch {
            throw TrashNotEmptied(underlying: error)
        }
    }

    private static func waitForDeletion(
        of bookId: KomgaBookId, on stream: AsyncStream<KomgaEvent>, timeout: Duration
    ) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await event in stream {
                    if case .bookDeleted(let payload) = event, payload.bookId == bookId { return }
                }
            }
            group.addTask { try? await Task.sleep(for: timeout) }
            await group.next()
            group.cancelAll()
        }
    }
}

/// Copy shared by every place that confirms a server-side delete, so the warning reads the same everywhere.
enum BookDeleteDialog {
    static func title(for book: SplashBook) -> String {
        String(localized: "Delete \u{201C}\(book.metadata.title)\u{201D}?")
    }
    static var confirm: LocalizedStringKey { "Delete file from server" }
    static var warning: LocalizedStringKey {
        "The file is removed from the server's disk and cannot be recovered. Komga has no recycle bin for this."
    }
}

extension BookDeleter.TrashNotEmptied: LocalizedError {
    var errorDescription: String? {
        String(localized: "The book was deleted, but the library trash could not be emptied: \(underlying.localizedDescription)")
    }
}
