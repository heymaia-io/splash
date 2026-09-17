import KomgaAPI
import SwiftUI

/// Port of `MainScreen.kt`.
///
/// DESIGN DEVIATION (plan Phase 4, documented on purpose): the Kotlin app picks `MobileLayout` vs
/// `DesktopLayout` by *platform*, so phones and tablets would both get the mobile layout. On iOS the layout
/// is chosen by *window width*: compact → mobile layout (bottom bar + libraries drawer), otherwise → the
/// desktop layout expressed as a `NavigationSplitView` (sidebar permanently visible at `FULL` width,
/// collapsible below it, like the Kotlin nav rail / modal drawer split).
public struct MainShellView<Content: View>: View {
    @Bindable var model: MainScreenViewModel
    let onOpenSettings: () -> Void
    let content: (Destination) -> Content

    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    public init(
        model: MainScreenViewModel, onOpenSettings: @escaping () -> Void,
        @ViewBuilder content: @escaping (Destination) -> Content
    ) {
        self.model = model
        self.onOpenSettings = onOpenSettings
        self.content = content
    }

    public var body: some View {
        GeometryReader { proxy in
            let width = WindowSizeClass.from(width: proxy.size.width)
            Group {
                if width == .compact {
                    mobileLayout
                } else {
                    desktopLayout(width: width)
                }
            }
            .onChange(of: width, initial: true) { _, newWidth in
                columnVisibility = newWidth == .full ? .all : .detailOnly
            }
        }
    }

    // MARK: Mobile

    private var mobileLayout: some View {
        VStack(spacing: 0) {
            detailStack
            Divider()
            HStack {
                CompactNavButton(title: "Libraries", systemImage: "books.vertical", isSelected: false) {
                    model.toggleNavBar()
                }
                CompactNavButton(title: "Home", systemImage: "house", isSelected: model.navigator.lastItem == .home) {
                    model.navigator.replaceAll(.home)
                }
                CompactNavButton(title: "Search", systemImage: "magnifyingglass", isSelected: isSearch) {
                    model.navigator.push(.search(nil))
                }
                CompactNavButton(title: "Settings", systemImage: "gearshape", isSelected: false, action: onOpenSettings)
            }
            .padding(.top, 6)
            .background(.bar)
        }
        .sheet(isPresented: $model.isNavBarOpen) {
            NavigationStack {
                LibrariesNavList(model: model, onSelect: { model.isNavBarOpen = false })
                    .navigationTitle("Libraries")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var isSearch: Bool {
        if case .search = model.navigator.lastItem { true } else { false }
    }

    // MARK: Desktop / iPad

    private func desktopLayout(width: WindowSizeClass) -> some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List {
                Section {
                    NavRow(title: "Home", systemImage: "house", selected: model.navigator.root == .home) {
                        select(.home, width: width)
                    }
                    NavRow(title: "Libraries", systemImage: "books.vertical",
                           selected: model.navigator.root == .library(nil)) {
                        select(.library(nil), width: width)
                    }
                }
                Section("Libraries") {
                    ForEach(model.libraries) { library in
                        NavRow(title: library.name, systemImage: "folder",
                               selected: model.navigator.root == .library(library.id)) {
                            select(.library(library.id), width: width)
                        }
                    }
                }
                if let status = model.taskQueueStatus, status.count > 0 {
                    Section {
                        Label("\(status.count) tasks in queue", systemImage: "hourglass")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    NavRow(title: "Settings", systemImage: "gearshape", selected: false, action: onOpenSettings)
                }
            }
            .navigationTitle("Komelia")
        } detail: {
            detailStack
        }
    }

    private func select(_ destination: Destination, width: WindowSizeClass) {
        model.navigator.replaceAll(destination)
        if width != .full { columnVisibility = .detailOnly }
    }

    // MARK: Shared

    private var detailStack: some View {
        NavigationStack(path: Bindable(model.navigator).stack) {
            content(model.navigator.root)
                .navigationDestination(for: Destination.self) { content($0) }
        }
        .id(model.navigator.root)  // replaceAll => fresh stack, like Voyager
    }
}

struct LibrariesNavList: View {
    let model: MainScreenViewModel
    let onSelect: () -> Void

    var body: some View {
        List {
            NavRow(title: "All libraries", systemImage: "books.vertical",
                   selected: model.navigator.root == .library(nil)) {
                model.navigator.replaceAll(.library(nil))
                onSelect()
            }
            ForEach(model.libraries) { library in
                NavRow(title: library.name, systemImage: "folder",
                       selected: model.navigator.root == .library(library.id)) {
                    model.navigator.replaceAll(.library(library.id))
                    onSelect()
                }
            }
        }
    }
}

struct NavRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let selected: Bool
    let action: () -> Void

    init(title: LocalizedStringKey, systemImage: String, selected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.selected = selected
        self.action = action
    }

    init(title: String, systemImage: String, selected: Bool, action: @escaping () -> Void) {
        self.init(title: LocalizedStringKey(stringLiteral: title), systemImage: systemImage, selected: selected,
                  action: action)
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct CompactNavButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage).font(.title3)
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
