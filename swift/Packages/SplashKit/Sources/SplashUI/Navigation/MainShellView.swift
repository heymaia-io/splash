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
    case settings

    public var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .library: "Library"
        case .downloads: "Downloads"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .library: "books.vertical"
        case .downloads: "arrow.down.circle"
        case .settings: "gearshape"
        }
    }

    /// The destination a tab resets to when it is selected.
    var root: Destination {
        switch self {
        case .home: .home
        case .library: .library(nil)
        case .downloads: .downloads
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
        // replaceAll => fresh stack, like Voyager. Keyed on the unlock state too: revealing or locking
        // writes nothing to any repository, so no `values()` subscription fires and the screens would
        // otherwise keep showing the results they fetched under the previous filter.
        .id(ShellIdentity(root: model.navigator.root, isUnlocked: privacy?.isUnlocked ?? false))
    }

    private struct ShellIdentity: Hashable {
        let root: Destination
        let isUnlocked: Bool
    }

    /// Only the *root* of a tab carries the tab picker and the search field: pushed screens get the usual
    /// back button and their own title instead.
    private var rootScreen: some View {
        content(model.navigator.root)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    MainTabPicker(selection: tabBinding)
                }
            }
            .modifier(GlobalSearchField(query: $model.searchQuery, isEnabled: isSearchable, submit: submitSearch))
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
        case .settings, .search: false
        default: true
        }
    }

    private func submitSearch() {
        let term = model.searchQuery.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        model.searchQuery = ""
        model.navigator.push(.search(term))
    }
}

// MARK: - Tab picker

/// Segmented picker sized to its labels. iOS 26 draws toolbar content as floating glass, so no background
/// is applied here — doing so would stack a second capsule inside the system's.
private struct MainTabPicker: View {
    @Binding var selection: MainTab
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Picker("Section", selection: $selection) {
            ForEach(MainTab.allCases) { tab in
                // Four words do not fit across a phone; icons carry the same four destinations there.
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
    let submit: () -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .searchable(text: $query, prompt: Text("Search all libraries"))
                .onSubmit(of: .search, submit)
        } else {
            content
        }
    }
}
