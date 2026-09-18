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
    let onRead: (SplashBook) -> Void

    var body: some View {
        switch destination {
        case .home:
            HomeScreen(model: factory.homeViewModel(), navigate: navigate, cardWidth: cardWidth)
        case .library(let id):
            LibraryScreen(model: factory.libraryViewModel(libraryId: id), navigate: navigate,
                          selectLibrary: { navigator.replaceAll(.library($0)) })
                .id(id)
        case .series(let id):
            SeriesScreen(model: factory.seriesViewModel(seriesId: id, api: api),
                         navigate: navigate, onRead: onRead)
        case .oneshot(let id):
            OneshotScreen(model: factory.oneshotViewModel(seriesId: id, api: api),
                          navigate: navigate, onRead: onRead)
        case .book(let id):
            BookScreen(model: factory.bookViewModel(bookId: id, api: api),
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
        }
    }

    private var cardWidth: CGFloat { CGFloat(factory.settings.value.cardWidth) }

    private func navigate(_ destination: Destination) {
        navigator.push(destination)
    }
}
