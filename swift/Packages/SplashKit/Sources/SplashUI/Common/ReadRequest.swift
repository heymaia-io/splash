import KomgaAPI

/// What a screen asks the root to open in the reader: a book, and optionally the page to start on.
///
/// One value carries both through the single `onRead` closure and doubles as the `fullScreenCover(item:)`
/// state in `AppRootView`, so the requested page cannot drift apart from the book being presented.
struct ReadRequest: Identifiable, Hashable {
    let book: SplashBook
    /// 1-based page to open on; `nil` resumes from the saved read progress.
    var page: Int? = nil

    var id: KomgaBookId { book.id }
}
