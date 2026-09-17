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
