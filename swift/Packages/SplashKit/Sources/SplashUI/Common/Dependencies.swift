import Foundation
import SplashCore
import KomgaAPI

public typealias KomgaEventSource = KomgaEventBroadcaster
public typealias KomgaEventValue = KomgaEvent

/// Port of `ViewModelFactory.kt` (Factory pattern): the single place that knows which dependencies each
/// screen model needs. Screens receive protocols only (`any KomgaApi`), never concrete remote/offline types
/// — the rule the plan marks as blocking for offline mode (Phase 10).
@MainActor
public final class ViewModelFactory {
    public let apiProvider: @MainActor () -> any KomgaApi
    public let settings: CommonSettingsRepository
    public let imageReaderSettings: ImageReaderSettingsRepository
    public let homeFilters: HomeScreenFilterRepository
    public let authState: KomgaAuthenticationState
    public let events: KomgaEventSource
    public let thumbnails: ThumbnailLoader?
    /// The private-content set. Screens read it per fetch so hiding something refreshes them live.
    public let hiddenContent: HiddenContentRepository

    public init(
        apiProvider: @escaping @MainActor () -> any KomgaApi,
        settings: CommonSettingsRepository,
        imageReaderSettings: ImageReaderSettingsRepository,
        homeFilters: HomeScreenFilterRepository,
        authState: KomgaAuthenticationState,
        events: KomgaEventSource,
        thumbnails: ThumbnailLoader?,
        // Defaults to an inert in-memory set so previews and tests need not wire privacy at all.
        hiddenContent: HiddenContentRepository = SettingsState(initial: HiddenContent(), save: { _ in })
    ) {
        self.apiProvider = apiProvider
        self.settings = settings
        self.imageReaderSettings = imageReaderSettings
        self.homeFilters = homeFilters
        self.authState = authState
        self.events = events
        self.thumbnails = thumbnails
        self.hiddenContent = hiddenContent
    }

    /// A *provider*, not a snapshot: screens call it on every fetch so hiding something takes effect
    /// without rebuilding the view model. `mode` is `.onlyHidden` only inside the private area.
    ///
    /// Centralising the multi-server guard here means no screen can forget it — ids recorded against one
    /// Komga server are never applied to another, where they could collide with unrelated content.
    func hiddenFilter(_ mode: HiddenContentMode = .excludeHidden) -> @MainActor () -> HiddenContentFilter {
        let repository = hiddenContent
        let settings = self.settings
        return {
            let hidden = repository.value
            guard hidden.applies(to: settings.value.serverUrl) else { return .disabled }
            return HiddenContentFilter(hidden: hidden, mode: mode)
        }
    }

    /// Emits whenever the private set changes, so browsing screens can reload themselves.
    func hiddenChanges() -> AsyncStream<HiddenContent> { hiddenContent.values() }

    var api: any KomgaApi { apiProvider() }

    func homeViewModel() -> HomeViewModel {
        HomeViewModel(
            api: api, filters: homeFilters, events: events, authState: authState,
            hiddenFilter: hiddenFilter(), hiddenChanges: { [hiddenContent] in hiddenContent.values() })
    }

    func libraryViewModel(
        libraryId: KomgaLibraryId?, api: (any KomgaApi)? = nil, hiddenMode: HiddenContentMode = .excludeHidden
    ) -> LibraryViewModel {
        LibraryViewModel(
            api: api ?? self.api, libraryId: libraryId, authState: authState, settings: settings, events: events,
            hiddenFilter: hiddenFilter(hiddenMode), hiddenChanges: { [hiddenContent] in hiddenContent.values() })
    }

    func seriesViewModel(
        seriesId: KomgaSeriesId, api: (any KomgaApi)? = nil, hiddenMode: HiddenContentMode = .excludeHidden
    ) -> SeriesViewModel {
        SeriesViewModel(seriesId: seriesId, api: api ?? self.api, authState: authState, settings: settings,
                        events: events, hiddenFilter: hiddenFilter(hiddenMode))
    }

    func bookViewModel(
        bookId: KomgaBookId, api: (any KomgaApi)? = nil, hiddenMode: HiddenContentMode = .excludeHidden
    ) -> BookViewModel {
        BookViewModel(bookId: bookId, api: api ?? self.api, authState: authState, events: events,
                      hiddenFilter: hiddenFilter(hiddenMode))
    }

    func oneshotViewModel(
        seriesId: KomgaSeriesId, api: (any KomgaApi)? = nil, hiddenMode: HiddenContentMode = .excludeHidden
    ) -> OneshotViewModel {
        OneshotViewModel(seriesId: seriesId, api: api ?? self.api, authState: authState, events: events,
                         hiddenFilter: hiddenFilter(hiddenMode))
    }

    func collectionViewModel(
        collectionId: KomgaCollectionId, hiddenMode: HiddenContentMode = .excludeHidden
    ) -> CollectionViewModel {
        CollectionViewModel(collectionId: collectionId, api: api, settings: settings, events: events,
                            hiddenFilter: hiddenFilter(hiddenMode))
    }

    func readListViewModel(
        readListId: KomgaReadListId, hiddenMode: HiddenContentMode = .excludeHidden
    ) -> ReadListViewModel {
        ReadListViewModel(readListId: readListId, api: api, settings: settings, events: events,
                          hiddenFilter: hiddenFilter(hiddenMode))
    }

    /// `api` overrides the active API for this reader only — used to read a downloaded book from the
    /// offline store while the rest of the app stays online.
    public func readerViewModel(
        bookId: KomgaBookId, siblings: BookSiblingsContext = .series, api: (any KomgaApi)? = nil
    ) -> ReaderViewModel {
        ReaderViewModel(bookId: bookId, api: api ?? self.api, settings: imageReaderSettings, siblings: siblings)
    }

    func privateCatalogViewModel() -> PrivateCatalogViewModel {
        PrivateCatalogViewModel(api: api, authState: authState, hiddenFilter: hiddenFilter(.onlyHidden))
    }

    func searchViewModel(query: String?, hiddenMode: HiddenContentMode = .excludeHidden) -> SearchViewModel {
        SearchViewModel(api: api, initialQuery: query ?? "", hiddenFilter: hiddenFilter(hiddenMode))
    }
}
