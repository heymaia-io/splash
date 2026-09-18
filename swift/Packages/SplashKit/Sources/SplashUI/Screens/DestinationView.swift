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
    /// Always the offline store, whatever tab this is. A series screen uses it to answer "Downloaded"
    /// exactly, rather than trimming a page of remote results.
    var offlineApi: (any KomgaApi)?
    /// Which books a series opens on. The Downloads tab opens on what you have downloaded.
    var downloadFilter: BookDownloadFilter = .all
    /// [NUEVO] Persists the library switcher's choice so the Library tab reopens on it. Supplied by the
    /// composition root, which owns the `MainScreenViewModel` this view does not see.
    var rememberLibrary: (KomgaLibraryId?) -> Void = { _ in }
    let onRead: (SplashBook) -> Void

    var body: some View {
        switch destination {
        case .home:
            HomeScreen(model: factory.homeViewModel(), navigate: navigate, cardWidth: cardWidth)
        case .library(let id):
            LibraryScreen(
                model: factory.libraryViewModel(libraryId: id), navigate: navigate,
                selectLibrary: {
                    rememberLibrary($0)
                    navigator.replaceAll(.library($0))
                })
                .id(id)
        case .series(let id):
            SeriesScreen(
                model: factory.seriesViewModel(
                    seriesId: id, api: api, offlineApi: offlineApi, downloadFilter: downloadFilter),
                navigate: navigate, onRead: onRead)
        case .oneshot(let id):
            OneshotScreen(model: factory.oneshotViewModel(seriesId: id, api: api), navigate: navigate,
                          onRead: onRead)
        case .book(let id):
            BookScreen(model: factory.bookViewModel(bookId: id, api: api), navigate: navigate, onRead: onRead)
        case .collection(let id):
            CollectionScreen(model: factory.collectionViewModel(collectionId: id), navigate: navigate)
        case .readList(let id):
            ReadListScreen(model: factory.readListViewModel(readListId: id), navigate: navigate)
        case .search(let query):
            SearchScreen(model: factory.searchViewModel(query: query), cardWidth: cardWidth, navigate: navigate)
        case .facet(let facet):
            FacetBrowseScreen(model: factory.facetViewModel(facet), navigate: navigate)
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
