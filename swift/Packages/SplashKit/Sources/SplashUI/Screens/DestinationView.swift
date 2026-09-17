import SplashCore
import KomgaAPI
import SwiftUI

/// Maps a `Destination` to its screen (Voyager `Screen.Content()` equivalent). Each screen model is created
/// once per destination instance by `@State` inside the screen view.
struct DestinationView: View {
    let destination: Destination
    let factory: ViewModelFactory
    let navigator: MainNavigator
    let onRead: (SplashBook) -> Void

    var body: some View {
        switch destination {
        case .home:
            HomeScreen(model: factory.homeViewModel(), navigate: navigate, cardWidth: cardWidth)
        case .library(let id):
            LibraryScreen(model: factory.libraryViewModel(libraryId: id), navigate: navigate)
                .id(id)
        case .series(let id):
            SeriesScreen(model: factory.seriesViewModel(seriesId: id), navigate: navigate, onRead: onRead)
        case .oneshot(let id):
            OneshotScreen(model: factory.oneshotViewModel(seriesId: id), navigate: navigate, onRead: onRead)
        case .book(let id):
            BookScreen(model: factory.bookViewModel(bookId: id), navigate: navigate, onRead: onRead)
        case .collection(let id):
            CollectionScreen(model: factory.collectionViewModel(collectionId: id), navigate: navigate)
        case .readList(let id):
            ReadListScreen(model: factory.readListViewModel(readListId: id), navigate: navigate)
        case .search(let query):
            SearchScreen(model: factory.searchViewModel(query: query), cardWidth: cardWidth, navigate: navigate)
        }
    }

    private var cardWidth: CGFloat { CGFloat(factory.settings.value.cardWidth) }

    private func navigate(_ destination: Destination) {
        navigator.push(destination)
    }
}
