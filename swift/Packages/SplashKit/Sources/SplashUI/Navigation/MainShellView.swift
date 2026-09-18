import KomgaAPI
import SwiftUI

/// The app's top-level sections.
///
/// DESIGN DEVIATION (documented on purpose): the Kotlin app puts these behind a nav rail / modal drawer
/// (`MobileLayout` vs `DesktopLayout`). On iOS they live in a single floating tab picker in the navigation
/// bar, which iOS 26 renders as the centred glass capsule the design references show.
public enum MainTab: String, CaseIterable, Identifiable, Sendable {
    case home
    case library
    case downloads
    /// Only present while the private area is unlocked — never rendered otherwise, so its very existence
    /// is not a hint.
    case privateArea
    case settings

    public var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .library: "Library"
        case .downloads: "Downloads"
        case .privateArea: "Private"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .library: "books.vertical"
        case .downloads: "arrow.down.circle"
        case .privateArea: "lock"
        case .settings: "gearshape"
        }
    }

    /// The destination a tab resets to when it is selected.
    var root: Destination {
        switch self {
        case .home: .home
        case .library: .library(nil)
        case .downloads: .downloads
        case .privateArea: .privateHome
        case .settings: .settings
        }
    }

    /// Which tab owns a root destination. `library(id)` keeps Library lit while browsing a single library;
    /// pushed content (series, book, search…) leaves the owning tab selected because only the *root* is
    /// consulted.
    static func owning(_ destination: Destination) -> MainTab? {
        switch destination {
        case .home: .home
        case .library: .library
        case .downloads: .downloads
        case .privateHome, .privateLibrary, .privateSearch: .privateArea
        case .settings: .settings
        default: nil
        }
    }
}

/// Port of `MainScreen.kt`: the floating tab picker plus the navigation stack for the selected tab.
public struct MainShellView<Content: View>: View {
    @Bindable var model: MainScreenViewModel
    let content: (Destination) -> Content
    @Environment(\.privacy) private var privacy

    public init(model: MainScreenViewModel, @ViewBuilder content: @escaping (Destination) -> Content) {
        self.model = model
        self.content = content
    }

    public var body: some View {
        NavigationStack(path: Bindable(model.navigator).stack) {
            rootScreen
                .navigationDestination(for: Destination.self) { content($0) }
        }
        .id(model.navigator.root)  // replaceAll => fresh stack, like Voyager
        .onChange(of: privacy?.isUnlocked ?? false) { _, isUnlocked in
            guard !isUnlocked else { return }
            // On re-lock, unwind unconditionally. Whether a pushed `.series` came from the private tab is
            // not decidable from the destination alone, and losing a scroll position is a far smaller
            // cost than leaving hidden content on screen.
            model.navigator.replaceAll(.home)
            model.searchQuery = ""
        }
    }

    /// Only the *root* of a tab carries the tab picker and the search field: pushed screens get the usual
    /// back button and their own title instead.
    private var rootScreen: some View {
        content(model.navigator.root)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    MainTabPicker(selection: tabBinding, tabs: tabs)
                }
            }
            .modifier(GlobalSearchField(
                query: $model.searchQuery, isEnabled: isSearchable, isPrivate: isPrivateContext,
                submit: submitSearch))
    }

    /// The Private tab exists only while unlocked. `lock()` resets the navigator in the same main-actor
    /// turn (above), so the picker never sees a selection whose tab has just disappeared.
    private var tabs: [MainTab] {
        privacy?.isUnlocked == true
            ? [.home, .library, .downloads, .privateArea, .settings]
            : [.home, .library, .downloads, .settings]
    }

    private var tabBinding: Binding<MainTab> {
        Binding(
            get: { MainTab.owning(model.navigator.root) ?? .home },
            set: { model.navigator.replaceAll($0.root) })
    }

    /// Search is global, so it rides along on every root screen — except Settings, which has nothing to
    /// search, and the search results screen itself, which owns the field that refines its own results.
    private var isSearchable: Bool {
        switch model.navigator.root {
        case .settings, .search, .privateSearch: false
        default: true
        }
    }

    /// Inside the private area the same field searches private content instead — the one place it does.
    private var isPrivateContext: Bool { model.navigator.root.isPrivate }

    private func submitSearch() {
        let term = model.searchQuery.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        model.searchQuery = ""
        model.navigator.push(isPrivateContext ? .privateSearch(term) : .search(term))
    }
}

// MARK: - Tab picker

/// Segmented picker sized to its labels. iOS 26 draws toolbar content as floating glass, so no background
/// is applied here — doing so would stack a second capsule inside the system's.
private struct MainTabPicker: View {
    @Binding var selection: MainTab
    /// Explicit rather than `allCases`: the Private tab is present only while it is unlocked.
    let tabs: [MainTab]
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Picker("Section", selection: $selection) {
            ForEach(tabs) { tab in
                // Four or five words do not fit across a phone; icons carry the same destinations there.
                if sizeClass == .compact {
                    Label(tab.title, systemImage: tab.systemImage).labelStyle(.iconOnly).tag(tab)
                } else {
                    Text(tab.title).tag(tab)
                }
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

// MARK: - Search

/// Applies `.searchable` conditionally. A plain `if` in the view body would give the two branches different
/// identities and reset the navigation stack whenever the flag flips.
private struct GlobalSearchField: ViewModifier {
    @Binding var query: String
    let isEnabled: Bool
    let isPrivate: Bool
    let submit: () -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .searchable(
                    text: $query,
                    prompt: Text(isPrivate ? "Search private" : "Search all libraries"))
                .onSubmit(of: .search, submit)
        } else {
            content
        }
    }
}
