import Foundation

/// Refreshing a paged list after a mutation (delete, rename, mark read) must leave the reader on the page
/// they were on. Only when the mutation emptied that page — the last item of the last page was deleted — is
/// the list pulled back to the new last page, so it never lands on an empty one.
///
/// One rule shared by every paged screen; pull-to-refresh and filter/sort changes deliberately do not use it,
/// because those are meant to start over from page 1.
enum PagePreservingReload {
    /// - Parameters:
    ///   - page: the page to come back to.
    ///   - totalPages: read *after* `load`, which is what updates it from the server's answer.
    ///   - load: fetches and publishes one page (and the server's page count).
    @MainActor
    static func run(
        page: Int,
        totalPages: @MainActor () -> Int,
        load: @MainActor (Int) async -> Void
    ) async {
        await load(page)
        let last = max(totalPages(), 1)
        if page > last { await load(last) }
    }
}
