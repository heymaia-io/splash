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

    public init(
        apiProvider: @escaping @MainActor () -> any KomgaApi,
        settings: CommonSettingsRepository,
        imageReaderSettings: ImageReaderSettingsRepository,
        homeFilters: HomeScreenFilterRepository,
        authState: KomgaAuthenticationState,
        events: KomgaEventSource,
        thumbnails: ThumbnailLoader?
    ) {
        self.apiProvider = apiProvider
        self.settings = settings
        self.imageReaderSettings = imageReaderSettings
        self.homeFilters = homeFilters
        self.authState = authState
        self.events = events
        self.thumbnails = thumbnails
    }

    var api: any KomgaApi { apiProvider() }

    func homeViewModel() -> HomeViewModel {
        HomeViewModel(api: api, filters: homeFilters, events: events)
    }

    func libraryViewModel(libraryId: KomgaLibraryId?) -> LibraryViewModel {
        LibraryViewModel(api: api, libraryId: libraryId, authState: authState, settings: settings, events: events)
    }

    func seriesViewModel(seriesId: KomgaSeriesId, api: (any KomgaApi)? = nil) -> SeriesViewModel {
        SeriesViewModel(seriesId: seriesId, api: api ?? self.api, authState: authState, settings: settings,
                        events: events)
    }

    func bookViewModel(bookId: KomgaBookId, api: (any KomgaApi)? = nil) -> BookViewModel {
        BookViewModel(bookId: bookId, api: api ?? self.api, authState: authState, events: events)
    }

    func oneshotViewModel(seriesId: KomgaSeriesId, api: (any KomgaApi)? = nil) -> OneshotViewModel {
        OneshotViewModel(seriesId: seriesId, api: api ?? self.api, authState: authState, events: events)
    }

    func collectionViewModel(collectionId: KomgaCollectionId) -> CollectionViewModel {
        CollectionViewModel(collectionId: collectionId, api: api, settings: settings, events: events)
    }

    func readListViewModel(readListId: KomgaReadListId) -> ReadListViewModel {
        ReadListViewModel(readListId: readListId, api: api, settings: settings, events: events)
    }

    /// `api` overrides the active API for this reader only — used to read a downloaded book from the
    /// offline store while the rest of the app stays online.
    public func readerViewModel(
        bookId: KomgaBookId, siblings: BookSiblingsContext = .series, api: (any KomgaApi)? = nil
    ) -> ReaderViewModel {
        ReaderViewModel(bookId: bookId, api: api ?? self.api, settings: imageReaderSettings, siblings: siblings)
    }

    func searchViewModel(query: String?) -> SearchViewModel {
        SearchViewModel(api: api, initialQuery: query ?? "")
    }
}
