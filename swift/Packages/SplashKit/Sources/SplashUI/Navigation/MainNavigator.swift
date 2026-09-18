import KomgaAPI
import Observation

/// Screens of the inner (main) navigator — one case per Voyager `Screen` in komelia-ui.
public enum Destination: Hashable, Sendable {
    case home
    /// `LibraryScreen(libraryId)`; `nil` = all libraries.
    case library(KomgaLibraryId?)
    case series(KomgaSeriesId)
    case oneshot(KomgaSeriesId)
    case book(KomgaBookId)
    case collection(KomgaCollectionId)
    case readList(KomgaReadListId)
    case search(String?)
    /// [NUEVO] Everything carrying one metadata value — reached by tapping a tag or genre chip.
    case facet(BrowseFacet)
    /// Tab roots that are not Komga content (`MainTab.downloads` / `.settings`).
    case downloads
    case settings
}

/// [NUEVO] A metadata value to browse by. It owns the conditions it stands for (value object), so the
/// destination, the factory and the screen stay one copy each however many facets are added.
public enum BrowseFacet: Hashable, Sendable {
    case tag(String)
    case genre(String)

    public var value: String {
        switch self {
        case .tag(let value), .genre(let value): value
        }
    }

    public var seriesCondition: SeriesCondition {
        switch self {
        case .tag(let value): .tag(.isEqualTo(value))
        case .genre(let value): .genre(.isEqualTo(value))
        }
    }

    /// `nil` when the facet cannot apply to books: Komga has no book-level genre.
    public var bookCondition: BookCondition? {
        switch self {
        case .tag(let value): .tag(.isEqualTo(value))
        case .genre: nil
        }
    }
}

/// Explicit stack navigator mirroring Voyager's `Navigator` API (`push`, `pop`, `replace`, `replaceAll`,
/// `popUntil`). SwiftUI's `NavigationStack` binds to `stack`; `root` is the stack's root view.
/// Keeping this explicit preserves the original semantics where nav-rail selection *discards* the stack
/// (`navigator.replaceAll(...)`) instead of SwiftUI's per-column stack retention.
@MainActor
@Observable
public final class MainNavigator {
    public var root: Destination
    public var stack: [Destination] = []

    public init(root: Destination = .home) {
        self.root = root
    }

    public var lastItem: Destination { stack.last ?? root }

    public func push(_ destination: Destination) { stack.append(destination) }

    public func pop() {
        if !stack.isEmpty { stack.removeLast() }
    }

    public func replace(_ destination: Destination) {
        if stack.isEmpty { root = destination } else { stack[stack.count - 1] = destination }
    }

    public func replaceAll(_ destination: Destination) {
        root = destination
        stack = []
    }

    /// Drops everything pushed on top of the current tab, keeping the tab itself.
    public func popToRoot() { stack = [] }

    /// Pops until `predicate` matches the top item; returns false (stack unchanged below root) if none did.
    @discardableResult
    public func popUntil(_ predicate: (Destination) -> Bool) -> Bool {
        while !stack.isEmpty {
            if predicate(stack.last!) { return true }
            stack.removeLast()
        }
        return predicate(root)
    }
}
