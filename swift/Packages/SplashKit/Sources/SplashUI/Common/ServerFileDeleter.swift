import KomgaAPI
import SwiftUI
import Synchronization

/// Something whose file(s) can be deleted on the Komga server (strategy: the deleter is the same for books
/// and series, only the requests, the lookup and the confirming events differ).
protocol DeleteTarget: Sendable {
    var id: String { get }
    var libraryId: KomgaLibraryId { get }
    var title: String { get }
    func request(_ api: any KomgaApi) async throws
    /// True once the server no longer serves the item, or serves it flagged `deleted` (Komga's trash).
    func isGone(_ api: any KomgaApi) async throws -> Bool
    /// True for an event proving Komga's delete task ran for this item.
    func isConfirmed(by event: KomgaEvent) -> Bool
}

struct BookTarget: DeleteTarget {
    let book: SplashBook
    var id: String { book.id.rawValue }
    var libraryId: KomgaLibraryId { book.libraryId }
    var title: String { book.metadata.title }

    func request(_ api: any KomgaApi) async throws { try await api.bookApi.deleteBook(book.id) }

    func isGone(_ api: any KomgaApi) async throws -> Bool {
        try await ServerFileDeleter.treatingNotFoundAsGone { try await api.bookApi.getOne(book.id).deleted }
    }

    func isConfirmed(by event: KomgaEvent) -> Bool {
        switch event {
        case .bookChanged(let p), .bookDeleted(let p): p.bookId == book.id
        default: false
        }
    }
}

struct SeriesTarget: DeleteTarget {
    let series: KomgaSeries
    var id: String { series.id.rawValue }
    var libraryId: KomgaLibraryId { series.libraryId }
    var title: String { series.metadata.title }

    func request(_ api: any KomgaApi) async throws { try await api.seriesApi.delete(series.id) }

    func isGone(_ api: any KomgaApi) async throws -> Bool {
        try await ServerFileDeleter.treatingNotFoundAsGone { try await api.seriesApi.getOneSeries(series.id).deleted }
    }

    func isConfirmed(by event: KomgaEvent) -> Bool {
        switch event {
        case .seriesChanged(let p), .seriesDeleted(let p): p.seriesId == series.id
        default: false
        }
    }
}

/// Removes books or series from the Komga server for good: delete the files, then empty the trash of every
/// affected library so the items do not linger as "Unavailable" until the next manual clean-up. Komga has no
/// restorable recycle bin for user-initiated deletes, which is why the UI asks for confirmation first.
///
/// `DELETE /books/{id}/file` and `DELETE /series/{id}/file` are accepted (202) and carried out by a server
/// task that deletes the file and then *soft-deletes* the item (`deleted = true`, announced by a `…Changed`
/// event); the real `…Deleted` event only comes when the trash is emptied. So the call waits for a
/// confirming event per item, with `timeout` (shared by the whole batch) as the fallback when events never
/// arrive (SSE down, slow server), and then looks every item up: Komga accepts the request even when its
/// task later fails (typically a read-only library folder) and emits nothing in that case, so only a 404 or
/// a `deleted` flag proves the file is gone. Emptying the trash is best effort and reported separately.
enum ServerFileDeleter {
    struct TrashNotEmptied: Error {
        let underlying: any Error
    }

    /// The server accepted the delete but the item is still there.
    struct NotDeleted: Error {}

    struct BatchResult {
        var deleted: [any DeleteTarget] = []
        var failures: [(target: any DeleteTarget, error: any Error)] = []
        var trashError: (any Error)?

        /// One user-facing line for everything that went wrong, or nil when the batch fully succeeded.
        var errorSummary: String? {
            var parts: [String] = failures.map { "\($0.target.title): \($0.error.localizedDescription)" }
            if let trashError {
                parts.append(TrashNotEmptied(underlying: trashError).localizedDescription)
            }
            return parts.isEmpty ? nil : parts.joined(separator: "\n")
        }
    }

    /// Single-item convenience over `delete(_:)`: throws the item's failure, or `TrashNotEmptied` once the
    /// file is already gone.
    @MainActor
    static func deleteAndEmptyTrash(
        _ target: any DeleteTarget, api: any KomgaApi, events: KomgaEventSource, timeout: Duration = .seconds(10)
    ) async throws {
        let result = await delete([target], api: api, events: events, timeout: timeout)
        if let failure = result.failures.first { throw failure.error }
        if let trashError = result.trashError { throw TrashNotEmptied(underlying: trashError) }
    }

    /// Runs a single-item delete and maps its outcome for a screen: whether the file is gone, plus the message
    /// to show. A trash clean-up failure still counts as gone — the delete itself succeeded.
    @MainActor
    static func outcome(of operation: () async throws -> Void) async -> (isGone: Bool, message: String?) {
        do {
            try await operation()
            return (true, nil)
        } catch let error as TrashNotEmptied {
            return (true, error.localizedDescription)
        } catch {
            return (false, error.isCancellation ? nil : error.localizedDescription)
        }
    }

    @MainActor
    static func delete(
        _ targets: [any DeleteTarget], api: any KomgaApi, events: KomgaEventSource, timeout: Duration = .seconds(10)
    ) async -> BatchResult {
        // Subscribe before the first request: a fast server could otherwise emit the event before we listen.
        let stream = events.subscribe()
        var result = BatchResult()
        var accepted: [any DeleteTarget] = []
        // Sequential on purpose: Komga queues each delete as a task anyway, so parallel requests gain nothing.
        for target in targets {
            do {
                try await target.request(api)
                accepted.append(target)
            } catch {
                result.failures.append((target, error))
            }
        }

        _ = await waitForConfirmations(of: accepted, on: stream, timeout: timeout)
        // Always verify, event or not: a `…Changed` event also fires for unrelated edits.
        for target in accepted {
            do {
                if try await target.isGone(api) {
                    result.deleted.append(target)
                } else {
                    result.failures.append((target, NotDeleted()))
                }
            } catch {
                result.failures.append((target, error))
            }
        }

        var seenLibraries = Set<KomgaLibraryId>()
        for target in result.deleted where seenLibraries.insert(target.libraryId).inserted {
            do {
                try await api.libraryApi.emptyTrash(target.libraryId)
            } catch {
                result.trashError = result.trashError ?? error
            }
        }
        return result
    }

    /// Runs a lookup that answers "is it flagged deleted?"; a 404 means the item is gone altogether.
    static func treatingNotFoundAsGone(_ lookup: () async throws -> Bool) async throws -> Bool {
        do {
            return try await lookup()
        } catch KomgaAPIError.httpStatus(let code, _) where code == 404 {
            return true
        }
    }

    /// Returns the ids for which no confirming event arrived before `timeout`.
    private static func waitForConfirmations(
        of targets: [any DeleteTarget], on stream: AsyncStream<KomgaEvent>, timeout: Duration
    ) async -> Set<String> {
        let ids = Set(targets.map(\.id))
        guard !ids.isEmpty else { return [] }
        let seen = SeenIds()
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await event in stream {
                    guard let target = targets.first(where: { $0.isConfirmed(by: event) }) else { continue }
                    if seen.insert(target.id) == ids.count { return }
                }
            }
            group.addTask { try? await Task.sleep(for: timeout) }
            await group.next()
            group.cancelAll()
        }
        return ids.subtracting(seen.ids)
    }

    /// Ids confirmed by the event stream, shared between the listening task and the caller.
    private final class SeenIds: Sendable {
        private let storage = Mutex<Set<String>>([])
        var ids: Set<String> { storage.withLock { $0 } }
        /// Returns how many distinct ids have been seen so far.
        func insert(_ id: String) -> Int { storage.withLock { $0.insert(id); return $0.count } }
    }
}

/// Copy shared by every place that confirms a server-side delete, so the warning reads the same everywhere.
enum BookDeleteDialog {
    static func title(for book: SplashBook) -> String {
        String(localized: "Delete \u{201C}\(book.metadata.title)\u{201D}?")
    }
    static func title(for series: KomgaSeries) -> String {
        String(localized: "Delete series \u{201C}\(series.metadata.title)\u{201D}?")
    }
    static func warning(for series: KomgaSeries) -> LocalizedStringKey {
        "All \(series.booksCount) books and the series folder are removed from the server's disk and cannot be recovered. Komga has no recycle bin for this."
    }
    static func title(count: Int) -> String {
        String(localized: "Delete \(count) books?")
    }
    static var confirm: LocalizedStringKey { "Delete file from server" }
    static var warning: LocalizedStringKey {
        "The file is removed from the server's disk and cannot be recovered. Komga has no recycle bin for this."
    }
}

extension ServerFileDeleter.TrashNotEmptied: LocalizedError {
    var errorDescription: String? {
        String(localized: "The files were deleted, but the library trash could not be emptied: \(underlying.localizedDescription)")
    }
}

extension ServerFileDeleter.NotDeleted: LocalizedError {
    var errorDescription: String? {
        String(localized: "The server accepted the request but did not delete the file. Check that Komga has write access to the library folder.")
    }
}
