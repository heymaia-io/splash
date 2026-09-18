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
    /// Supplied by the composition root so it resolves to `PrivacyController.filter()` — the one place that
    /// knows both what is hidden *and* whether the private area is currently unlocked.
    private let hiddenFilterProvider: @MainActor () -> HiddenContentFilter
    /// Emits whenever the private set changes, so browsing screens reload themselves.
    private let hiddenChangesProvider: @MainActor () -> AsyncStream<PrivacyState>

    public init(
        apiProvider: @escaping @MainActor () -> any KomgaApi,
        settings: CommonSettingsRepository,
        imageReaderSettings: ImageReaderSettingsRepository,
        homeFilters: HomeScreenFilterRepository,
        authState: KomgaAuthenticationState,
        events: KomgaEventSource,
        thumbnails: ThumbnailLoader?,
        // Defaults to "nothing hidden" so previews and tests need not wire privacy at all.
        hiddenFilter: @escaping @MainActor () -> HiddenContentFilter = { .disabled },
        hiddenChanges: @escaping @MainActor () -> AsyncStream<PrivacyState> = { noHiddenChanges }
    ) {
        self.apiProvider = apiProvider
        self.settings = settings
        self.imageReaderSettings = imageReaderSettings
        self.homeFilters = homeFilters
        self.authState = authState
        self.events = events
        self.thumbnails = thumbnails
        self.hiddenFilterProvider = hiddenFilter
        self.hiddenChangesProvider = hiddenChanges
    }

    var api: any KomgaApi { apiProvider() }

    /// A **provider, not a snapshot**: screens call it on every fetch, so both hiding something and unlocking
    /// the private area take effect without rebuilding the view model.
    ///
    /// It must resolve to `PrivacyController.filter()` and nothing else. A second copy of the rule here is
    /// precisely how unlocking stopped revealing anything: the copy knew what was hidden but not that it had
    /// been revealed, so every screen kept filtering.
    var hiddenFilter: @MainActor () -> HiddenContentFilter { hiddenFilterProvider }

    var hiddenChanges: @MainActor () -> AsyncStream<PrivacyState> { hiddenChangesProvider }

    func homeViewModel() -> HomeViewModel {
        HomeViewModel(
            api: api, filters: homeFilters, events: events, authState: authState,
            hiddenFilter: hiddenFilter, hiddenChanges: hiddenChanges)
    }

    func libraryViewModel(libraryId: KomgaLibraryId?) -> LibraryViewModel {
        LibraryViewModel(
            api: api, libraryId: libraryId, authState: authState, settings: settings, events: events,
            hiddenFilter: hiddenFilter, hiddenChanges: hiddenChanges)
    }

    func seriesViewModel(
        seriesId: KomgaSeriesId, api: (any KomgaApi)? = nil, offlineApi: (any KomgaApi)? = nil,
        downloadFilter: BookDownloadFilter = .all
    ) -> SeriesViewModel {
        SeriesViewModel(seriesId: seriesId, api: api ?? self.api, authState: authState, settings: settings,
                        events: events, offlineApi: offlineApi, downloadFilter: downloadFilter,
                        hiddenFilter: hiddenFilter, hiddenChanges: hiddenChanges)
    }

    func bookViewModel(bookId: KomgaBookId, api: (any KomgaApi)? = nil) -> BookViewModel {
        BookViewModel(bookId: bookId, api: api ?? self.api, authState: authState, events: events,
                      hiddenFilter: hiddenFilter)
    }

    func oneshotViewModel(seriesId: KomgaSeriesId, api: (any KomgaApi)? = nil) -> OneshotViewModel {
        OneshotViewModel(seriesId: seriesId, api: api ?? self.api, authState: authState, events: events,
                         hiddenFilter: hiddenFilter)
    }

    func collectionViewModel(collectionId: KomgaCollectionId) -> CollectionViewModel {
        CollectionViewModel(collectionId: collectionId, api: api, settings: settings, events: events,
                            hiddenFilter: hiddenFilter)
    }

    func readListViewModel(readListId: KomgaReadListId) -> ReadListViewModel {
        ReadListViewModel(readListId: readListId, api: api, settings: settings, events: events,
                          hiddenFilter: hiddenFilter)
    }

    /// `api` overrides the active API for this reader only — used to read a downloaded book from the
    /// offline store while the rest of the app stays online.
    public func readerViewModel(
        bookId: KomgaBookId, siblings: BookSiblingsContext = .series, api: (any KomgaApi)? = nil
    ) -> ReaderViewModel {
        ReaderViewModel(bookId: bookId, api: api ?? self.api, settings: imageReaderSettings, siblings: siblings)
    }

    func facetViewModel(_ facet: BrowseFacet) -> FacetBrowseViewModel {
        FacetBrowseViewModel(facet: facet, api: api, settings: settings, hiddenFilter: hiddenFilter,
                             hiddenChanges: hiddenChanges)
    }

    func searchViewModel(query: String?) -> SearchViewModel {
        SearchViewModel(api: api, initialQuery: query ?? "", hiddenFilter: hiddenFilter)
    }
}
