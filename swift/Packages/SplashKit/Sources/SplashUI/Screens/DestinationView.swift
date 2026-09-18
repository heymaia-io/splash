import SplashCore
import KomgaAPI
import SwiftUI

/// Maps a `Destination` to its screen (Voyager `Screen.Content()` equivalent). Each screen model is created
/// once per destination instance by `@State` inside the screen view.
struct DestinationView: View {
    let destination: Destination
    let factory: ViewModelFactory
    let navigator: MainNavigator
    /// Non-nil inside the Downloads tab: every screen there reads from the offline store, so browsing what
    /// you have downloaded never touches the network. `nil` everywhere else = use the active API.
    let api: (any KomgaApi)?
    /// `.onlyHidden` inside the private area, so a hidden book in an otherwise visible series still lists.
    let hiddenMode: HiddenContentMode
    let onRead: (SplashBook) -> Void
    @Environment(\.privacy) private var privacy

    var body: some View {
        switch destination {
        case .home:
            HomeScreen(model: factory.homeViewModel(), navigate: navigate, cardWidth: cardWidth)
        case .library(let id):
            LibraryScreen(model: factory.libraryViewModel(libraryId: id), navigate: navigate,
                          selectLibrary: { navigator.replaceAll(.library($0)) })
                .id(id)
        case .series(let id):
            SeriesScreen(model: factory.seriesViewModel(seriesId: id, api: api, hiddenMode: hiddenMode),
                         navigate: navigate, onRead: onRead)
        case .oneshot(let id):
            OneshotScreen(model: factory.oneshotViewModel(seriesId: id, api: api, hiddenMode: hiddenMode),
                          navigate: navigate, onRead: onRead)
        case .book(let id):
            BookScreen(model: factory.bookViewModel(bookId: id, api: api, hiddenMode: hiddenMode),
                       navigate: navigate, onRead: onRead)
        case .collection(let id):
            CollectionScreen(model: factory.collectionViewModel(collectionId: id), navigate: navigate)
        case .readList(let id):
            ReadListScreen(model: factory.readListViewModel(readListId: id), navigate: navigate)
        case .search(let query):
            SearchScreen(model: factory.searchViewModel(query: query), cardWidth: cardWidth, navigate: navigate)
        case .downloads:
            DownloadsView(cardWidth: cardWidth, navigate: navigate)
        case .settings:
            // Resolved by `AppRootView`, which holds the composition root this view does not see.
            EmptyView()
        // Defence in depth: these render nothing at all if the area has re-locked under us. The shell also
        // unwinds the stack on lock, so this should be unreachable — which is exactly why it is cheap.
        case .privateHome where isUnlocked:
            PrivateHomeScreen(model: factory.privateHomeViewModel(), cardWidth: cardWidth, navigate: navigate)
        case .privateLibrary(let id) where isUnlocked:
            LibraryScreen(
                model: factory.libraryViewModel(libraryId: id, hiddenMode: .onlyHidden), navigate: navigate,
                selectLibrary: { navigator.replaceAll($0.map { Destination.privateLibrary($0) } ?? .privateHome) })
                .id(id)
        case .privateSearch(let query) where isUnlocked:
            PrivateSearchScreen(
                model: factory.privateSearchViewModel(query: query), cardWidth: cardWidth,
                navigate: navigate)
        case .privateHome, .privateLibrary, .privateSearch:
            EmptyView()
        }
    }

    private var cardWidth: CGFloat { CGFloat(factory.settings.value.cardWidth) }
    private var isUnlocked: Bool { privacy?.isUnlocked == true }

    private func navigate(_ destination: Destination) {
        navigator.push(destination)
    }
}
