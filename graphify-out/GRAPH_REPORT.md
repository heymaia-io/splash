# Graph Report - .  (2026-09-17)

## Corpus Check
- 184 files · ~111,028 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 4097 nodes · 11132 edges · 168 communities (161 shown, 7 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 1025 edges (avg confidence: 0.81)
- Token cost: 92,000 input · 8,103 output

## Community Hubs (Navigation)
- Book Thumbnails & Metadata
- Komga API Surface
- App Settings Models
- Navigation Destinations
- Identifiers & API Errors
- Server Event Payloads
- Auth State & Library Screen
- Paged Requests
- Remote HTTP Clients
- Offline GRDB Repositories
- UIKit Reader Views
- Read Lists
- Offline API Implementations
- Content Cards
- Keychain & Secrets
- Book Wire Models
- Purchases & Entitlement
- Home Filters & Shelves
- Offline Delete Actions
- View Model Factory & Filter Rule
- Readium JSON
- Offline Thumbnails
- URLSessionDownloadManager
- PatchValue
- XXH3
- RecordingBookApi
- PrivacyController
- KomgaLibraryId
- AppRootView
- SeriesCondition
- Sendable
- ContinuousReaderModel
- OfflineReadProgress
- SearchSQL
- ThumbnailLoader
- String
- OfflineSeries
- KomgaCollectionId
- KomgaAuthor
- RemoteKomgaApi
- SeriesViewModel
- RemoteBookApi
- ReaderViewModel
- OfflineRecord
- ReaderView
- OfflineError
- KomgaHTTPClient
- ThumbnailRequest
- SettingsState
- PagedReaderModel
- OfflineController
- seeded()
- KomgaSort
- RemoteSSESession
- PDFPageRenderer
- BookViewModel
- BookCondition
- DateOp
- makeDecoder()
- ScanInterval
- AppModule
- KomgaUserId
- Key
- NumericNullableOp
- downloadReadSyncAndDeleteFixtureHero()
- TaskData
- decode()
- KomgaCookieStore
- SplashCore
- init()
- AppMigrations
- EpubReaderModel
- ReloadScheduler
- Port map (Komelia Kotlin → Splash Swift)
- Testing
- OfflineLibrary
- OfflineTestEnvironment
- SettingsView
- PageId
- OfflineSettingsStateRepository
- OfflineMediaServerId
- ReaderImage
- SyncManager
- PaginationBar
- Komga wire format contract table
- CodingKeys
- inMemory()
- BookDownload
- ImageReaderSettings
- OfflineUser
- OfflineTaskRecord
- ReaderImageFactory
- BookDownloadService
- AppBootstrap
- KomgaIdentifier
- Filter
- OfflineBook
- SearchViewModel
- Synchronization
- RemoteUserApi
- ApiKeyStore
- GRDBBookMetadataAggregationRepository
- EncodingTests
- ReaderType
- decode()
- CoreGraphics
- EPUBNavigatorRepresentable
- OfflineSettings
- init()
- DownloadEvent
- CodingKeys
- KomgaServerInfo
- LayoutScaleType
- OfflineTaskEmitter
- persisted()
- insertBook()
- KomgaAuthDelegate
- OfflineEvents
- OfflineFileLocator
- SeriesSortOption
- EventRecorder
- SplashKit (local SPM package)
- CodingKeys
- KomgaEventBroadcaster
- uploadThumbnail()
- relativePath()
- PdfPageExtractor
- LoginView
- WindowSizeClass
- Komga fixture server (fixtures/komga)
- PaywallView
- StringOp
- GRDBOfflineTasksRepository
- OfflineRepositories
- OfflineAccessPolicy
- Splash trademark and brand policy
- EpubOpenError
- ReadiumEpubReader
- decode()
- OfflineDownloads
- LicensesView
- TestSession
- CLAUDE.md project guide
- CodingKey
- EpubSettingsSheet
- execute()
- AsyncBroadcaster
- Splash
- ReadiumEpubReaderView
- SyncReadProgressAction
- StubImportSource
- setup.sh
- append()
- HomeScreenFilter
- TransitionPage
- Live updates via SSE
- cbz()
- OfflineBanner
- RootKeys
- KomgaAuthenticationState
- MemoryPersistence
- State
- wire_contract_check.py
- ReadiumEpubReaderPresenter
- ThumbnailLoader
- PremiumProduct
- OSKeys
- PackageDescription

## God Nodes (most connected - your core abstractions)
1. `KomgaBookId` - 264 edges
2. `KomgaAPI` - 162 edges
3. `KomgaLibraryId` - 128 edges
4. `KomgaSeriesId` - 126 edges
5. `KomgaPageRequest` - 88 edges
6. `KomgaUserId` - 87 edges
7. `OfflineDataStore` - 77 edges
8. `KomgaEvent` - 76 edges
9. `Page` - 71 edges
10. `KomgaAPIError` - 60 edges

## Surprising Connections (you probably didn't know these)
- `GRDBPrivacyStore` --semantically_similar_to--> `GRDBHomeScreenFilterStore`  [INFERRED] [semantically similar]
  PRIVACY_FEATURE_PROMPT.md → swift/Packages/SplashKit/Sources/SplashDB/Settings/GRDBSettingsStores.swift
- `PrivacyBanner` --semantically_similar_to--> `OfflineBanner`  [INFERRED] [semantically similar]
  PRIVACY_FEATURE_PROMPT.md → swift/Packages/SplashKit/Sources/SplashUI/Offline/DownloadViews.swift
- `Chokepoint: AppModule.downloadedSeries() (Downloads tab + offline fallback shelf)` --conceptually_related_to--> `AppModule`  [INFERRED]
  PRIVACY_FEATURE_PROMPT.md → swift/Packages/SplashKit/Sources/SplashAppShared/AppModule.swift
- `Chokepoint: BookScreen / OneshotViewModel refuses to render a hidden item` --conceptually_related_to--> `OneshotViewModel`  [INFERRED]
  PRIVACY_FEATURE_PROMPT.md → swift/Packages/SplashKit/Sources/SplashUI/Screens/BookScreen.swift
- `Long-press gesture beside the "All Libraries" chip` --conceptually_related_to--> `LibraryScreen`  [INFERRED]
  PRIVACY_FEATURE_PROMPT.md → swift/Packages/SplashKit/Sources/SplashUI/Screens/LibraryScreen.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **SplashKit target stack in dependency order** — readme_komgaapi, readme_komgaremote, readme_splashcore, readme_splashoffline, readme_splashdb, readme_splashimage, readme_splashui, readme_splashappshared, readme_dependency_direction [EXTRACTED 1.00]
- **Offline reading flow: download, verify, serve, sync** — readme_offline_mode, docs_port_map_phase_f10, docs_port_map_phase_f11, docs_port_map_phase_f12, docs_wire_format_no_range_support, readme_splashoffline, readme_splashdb [INFERRED 0.85]
- **Komga API protocol surface (107 operations)** — docs_wire_format_remotebookapi, docs_wire_format_remoteseriesapi, docs_wire_format_remotelibraryapi, docs_wire_format_remotecollectionsapi, docs_wire_format_remotereadlistapi, docs_wire_format_remotereferentialapi, docs_wire_format_remoteuserapi, docs_wire_format_remotesettingsapi, docs_wire_format_remotetaskapi, docs_wire_format_remoteactuatorapi, docs_wire_format_remoteannouncementsapi, docs_wire_format_remotefilesystemapi, docs_wire_format_remotessesession [EXTRACTED 1.00]
- **Single-source-of-truth filter flow (controller → provider → filter → chokepoints)** — privacy_feature_prompt_privacycontroller, privacy_feature_prompt_hiddencontentfilter, swift_packages_splashkit_sources_splashui_common_dependencies_viewmodelfactory, privacy_feature_prompt_filter_chokepoints, privacy_feature_prompt_single_source_of_truth [INFERRED 0.85]
- **Reveal / unlock authentication flow** — privacy_feature_prompt_privacyrevealgesture, privacy_feature_prompt_deviceauthenticating, privacy_feature_prompt_localdeviceauthenticator, privacy_feature_prompt_privacycontroller, privacy_feature_prompt_paywallcontext, privacy_feature_prompt_silent_failure_no_oracle [INFERRED 0.85]
- **Discarded approaches, each with the bug it reintroduces** — privacy_feature_prompt_antipattern_private_tab, privacy_feature_prompt_antipattern_hiddencontentmode, privacy_feature_prompt_antipattern_client_side_filter_evaluator, privacy_feature_prompt_antipattern_duplicate_filter_rule, privacy_feature_prompt_antipattern_serverurl_stamp, privacy_feature_prompt_antipattern_app_level_pin, privacy_feature_prompt_antipattern_overfetch_splicing [EXTRACTED 1.00]

## Communities (168 total, 7 thin omitted)

### Community 0 - "Book Thumbnails & Metadata"
Cohesion: 0.05
Nodes (19): KomgaBookMetadataUpdateRequest, KomgaBookId, KomgaThumbnailId, OfflineBookApi, .userId, Bool, Data, Int (+11 more)

### Community 1 - "Komga API Surface"
Cohesion: 0.04
Nodes (47): Filtering lives in view models, not in an API decorator, KomgaSSESession, KomgaActuatorApi, KomgaBookApi, KomgaCollectionsApi, KomgaFileSystemApi, KomgaLibraryApi, KomgaReadListApi (+39 more)

### Community 2 - "App Settings Models"
Cohesion: 0.03
Nodes (63): CaseIterable, AppTheme, dark, darker, light, BooksLayout, grid, list (+55 more)

### Community 3 - "Navigation Destinations"
Cohesion: 0.05
Nodes (46): Content, Destination, book, collection, downloads, home, library, oneshot (+38 more)

### Community 4 - "Identifiers & API Errors"
Cohesion: 0.06
Nodes (25): KomgaSeriesId, KomgaAPIError, decoding, httpStatus, invalidResponse, .isNotFound, .isUnauthorized, .statusCode (+17 more)

### Community 5 - "Server Event Payloads"
Cohesion: 0.06
Nodes (57): Codable, Hashable, LenientEnum, BookImportedPayload, BookPayload, CollectionPayload, KomgaEvent, bookAdded (+49 more)

### Community 6 - "Auth State & Library Screen"
Cohesion: 0.06
Nodes (35): Chokepoint: LibraryScreen (loadSeriesPage, collections, read lists, item counts, libraries), KomgaApi, DataState, authenticationRequired, loaded, KomgaAuthenticationState, KomgaLibrary, KomgaUser (+27 more)

### Community 7 - "Paged Requests"
Cohesion: 0.08
Nodes (24): KomgaBookSearch, KomgaPageRequest, .queryItems, Page, Pageable, Sort, Bool, Decoder (+16 more)

### Community 8 - "Remote HTTP Clients"
Cohesion: 0.08
Nodes (5): Foundation, GRDB, KomgaAPI, ReadiumZIPFoundation, SplashOffline

### Community 9 - "Offline GRDB Repositories"
Cohesion: 0.06
Nodes (34): BookMetadataChildren, GRDBBookMetadataRepository, GRDBLogJournalRepository, GRDBMediaRepository, Database, String, GRDBOfflineRepositories, .bookDtos (+26 more)

### Community 10 - "UIKit Reader Views"
Cohesion: 0.09
Nodes (25): CGPoint, Equatable, NSCoder, .pages, Configuration, ContinuousStripView, Coordinator, PagedSpreadView (+17 more)

### Community 11 - "Read Lists"
Cohesion: 0.07
Nodes (11): KomgaReadList, KomgaReadListId, OfflineBookStateProvider, RemoteReadListApi, SplashBook, OfflineCollectionsApi, OfflineReadListApi, Bool (+3 more)

### Community 12 - "Offline API Implementations"
Cohesion: 0.08
Nodes (10): DatabaseOfflineBookStateProvider, OfflineLibraryApi, OfflineReferentialApi, OfflineUserApi, Bool, KomgaLibrary, KomgaUser, String (+2 more)

### Community 13 - "Content Cards"
Cohesion: 0.06
Nodes (44): Card, Footer, Overlay, BookCard, .body, .progressBar, CardGrid, .body (+36 more)

### Community 14 - "Keychain & Secrets"
Cohesion: 0.09
Nodes (20): Security, InMemorySecretsRepository, KeychainClient, KeychainError, status, KeychainSecretsRepository, Kind, apiKey (+12 more)

### Community 15 - "Book Wire Models"
Cohesion: 0.09
Nodes (40): Identifiable, CopyMode, copy, hardlink, move, KomgaBook, KomgaBookMetadata, KomgaBookPage (+32 more)

### Community 16 - "Purchases & Entitlement"
Cohesion: 0.07
Nodes (27): LocalizedError, Product, StoreKit, init(), loadProduct(), OfflineProduct, OfflineProductInfo, OfflineStoreProvider (+19 more)

### Community 17 - "Home Filters & Shelves"
Cohesion: 0.06
Nodes (41): Anti-pattern: client-side evaluator of HomeScreenFilter conditions, Chokepoint: HomeViewModel.fetch (5 branches), HomeScreenFilter, booksCustom, booksOnDeck, .id, .isBookFilter, .label (+33 more)

### Community 18 - "Offline Delete Actions"
Cohesion: 0.10
Nodes (28): BookDeleteAction, BookDeleteManyAction, BookMarkRemoteDeletedAction, DeletionOutcome, OfflineActionEnvironment, .isOffline, Bool, String (+20 more)

### Community 19 - "View Model Factory & Filter Rule"
Cohesion: 0.08
Nodes (34): Anti-pattern: a second copy of the "should I filter?" rule, One source of truth for "should I filter?", CommonSettingsRepository, HomeScreenFilterRepository, ImageReaderSettingsRepository, KomgaEventSource, MainActor, String (+26 more)

### Community 20 - "Readium JSON"
Cohesion: 0.08
Nodes (35): JSONValue, array, bool, null, number, object, string, R2Device (+27 more)

### Community 21 - "Offline Thumbnails"
Cohesion: 0.08
Nodes (27): GRDBThumbnailBookRepository, .bookThumbnails, CodingKeys, type, KomgaBook, KomgaBookPage, KomgaBookThumbnail, MediaExtension (+19 more)

### Community 22 - "URLSessionDownloadManager"
Cohesion: 0.09
Nodes (24): ContinuousClock, OperationQueue, RequestProvider, Error, .isKomgaNotFound, .isKomgaUnauthorized, .isServerUnreachable, Job (+16 more)

### Community 23 - "PatchValue"
Cohesion: 0.09
Nodes (31): Encodable, KomgaReadStatus, inProgress, read, unread, KomgaCollection, KomgaCollectionCreateRequest, KomgaCollectionQuery (+23 more)

### Community 24 - "XXH3"
Cohesion: 0.15
Nodes (16): FileHasher, Hash128, Data, Int, String, UInt8, URL, XXH3 (+8 more)

### Community 25 - "RecordingBookApi"
Cohesion: 0.07
Nodes (13): KomgaBookReadProgressUpdateRequest, URL, RecordingBookApi, .progressWrites, Bool, Data, Int, KomgaBookPage (+5 more)

### Community 26 - "PrivacyController"
Cohesion: 0.06
Nodes (41): Anti-pattern: an app-level PIN when the device has no passcode, Anti-pattern: HiddenContentMode / .onlyHidden inverse filter, Anti-pattern: over-fetching or page-splicing to fix the pagination count, Anti-pattern: a "Private" tab or parallel screen, Anti-pattern: a serverUrl stamp on a single flat set, Authenticate before checking the purchase, Entirely client-side; nothing sent to Komga, Server conditions are an optimisation; visible(_:) is the guard (+33 more)

### Community 27 - "KomgaLibraryId"
Cohesion: 0.13
Nodes (11): KomgaLibraryId, RemoteLibraryApi, KomgaLibrary, GRDBReferentialRepository, GRDBSeriesDtoRepository, Database, Int, KomgaSeries (+3 more)

### Community 28 - "AppRootView"
Cohesion: 0.09
Nodes (30): Chokepoint: AppModule.downloadedSeries() (Downloads tab + offline fallback shelf), Chokepoint: BookScreen / OneshotViewModel refuses to render a hidden item, Chokepoint: collection and read-list view models (client-side visible), Chokepoint: SeriesScreen.loadBooks (bookConditions exact, paging stays right), Chokepoint: SettingsView (ServerSettingsView, AccountSettingsView.libraryAccess, MediaAnalysisView), Deep-link guard in AppRootView.open(_:), Do not filter: UsersView, AuthenticationActivityView, AnnouncementsView, Filter chokepoints (§4) (+22 more)

### Community 29 - "SeriesCondition"
Cohesion: 0.06
Nodes (33): SearchValue, AuthorMatch, PosterMatch, PosterType, generated, sidecar, userUploaded, SeriesCondition (+25 more)

### Community 30 - "Sendable"
Cohesion: 0.14
Nodes (31): Sendable, AllowExclude, allowOnly, exclude, Author, DataViolation, KomgaAgeRestriction, .summary (+23 more)

### Community 31 - "ContinuousReaderModel"
Cohesion: 0.09
Nodes (20): Range, images, ContinuousReaderModel, .isVertical, Bool, CGFloat, CGRect, CGSize (+12 more)

### Community 32 - "OfflineReadProgress"
Cohesion: 0.09
Nodes (21): href, .readProgress, GRDBReadProgressRepository, Database, Date, SQL, ProgressMarkProgressionAction, EntryType (+13 more)

### Community 33 - "SearchSQL"
Cohesion: 0.15
Nodes (15): EqualityOp, isEqualTo, isNotEqualTo, BookSearchHelper, SeriesSearchHelper, SQL, SearchSQL, Bool (+7 more)

### Community 34 - "ThumbnailLoader"
Cohesion: 0.10
Nodes (21): NSString, .offlineApi, CGImageBox, Configuration, .`default`, DecodedImage, .pixelSize, MemoryKey (+13 more)

### Community 35 - "String"
Cohesion: 0.12
Nodes (17): String, ServerURL, LoadState, error, loading, success, uninitialized, LoginSession (+9 more)

### Community 36 - "OfflineSeries"
Cohesion: 0.10
Nodes (19): .series, .seriesThumbnails, GRDBSeriesRepository, GRDBThumbnailSeriesRepository, KomgaSeries, KomgaSeriesThumbnail, OfflineBookMetadataAggregation, OfflineSeries (+11 more)

### Community 37 - "KomgaCollectionId"
Cohesion: 0.13
Nodes (9): KomgaCollectionId, RemoteCollectionsApi, Bool, Data, KomgaHTTPClient, KomgaSeries, String, RemoteReferentialApi (+1 more)

### Community 38 - "KomgaAuthor"
Cohesion: 0.14
Nodes (25): KomgaAlternativeTitle, KomgaAuthor, KomgaReadingDirection, leftToRight, rightToLeft, vertical, webtoon, KomgaSeries (+17 more)

### Community 39 - "RemoteKomgaApi"
Cohesion: 0.10
Nodes (14): KomgaAnnouncementsApi, KomgaSettingsApi, RemoteActuatorApi, RemoteAnnouncementsApi, RemoteFileSystemApi, RemoteSettingsApi, RemoteTaskApi, Int (+6 more)

### Community 40 - "SeriesViewModel"
Cohesion: 0.12
Nodes (20): SeriesHeader, SeriesScreen, .body, .nextBook, SeriesViewModel, .cardWidth, CGFloat, CommonSettingsRepository (+12 more)

### Community 41 - "RemoteBookApi"
Cohesion: 0.09
Nodes (10): RemoteBookApi, Bool, Data, Int, KomgaBook, KomgaBookPage, KomgaBookThumbnail, KomgaHTTPClient (+2 more)

### Community 42 - "ReaderViewModel"
Cohesion: 0.12
Nodes (20): BookSiblingsContext, readList, series, PageMetadata, .id, .isLandscape, ReaderBooksState, ReaderViewModel (+12 more)

### Community 43 - "OfflineRecord"
Cohesion: 0.19
Nodes (22): DatabaseColumnDecodingStrategy, DatabaseColumnEncodingStrategy, tags, OfflineBookMetadataRecord, OfflineBookRecord, OfflineMediaPageRecord, OfflineMediaRecord, OfflineReadProgressRecord (+14 more)

### Community 44 - "ReaderView"
Cohesion: 0.11
Nodes (17): PreferenceKey, .body, ContinuousStripViewStep, ReaderView, .body, .closeButton, .content, .currentPage (+9 more)

### Community 45 - "OfflineError"
Cohesion: 0.13
Nodes (18): Archive, BookContentExtractors, CachedArchive, DataBuffer, DivinaExtractor, EpubExtractor, Data, Date (+10 more)

### Community 46 - "KomgaHTTPClient"
Cohesion: 0.12
Nodes (18): Body, HTTPMethod, delete, get, patch, post, put, KomgaHTTPClient (+10 more)

### Community 47 - "ThumbnailRequest"
Cohesion: 0.09
Nodes (24): ContentMode, Data, Int, String, ThumbnailRequest, book, bookDefault, bookPage (+16 more)

### Community 48 - "SettingsState"
Cohesion: 0.12
Nodes (17): escaping, AsyncSerialLock, InMemorySettingsStore, SettingsState, .value, async, AsyncStream, KeyPath (+9 more)

### Community 49 - "PagedReaderModel"
Cohesion: 0.12
Nodes (16): Index, Collection, LoadedPage, .id, PagedReaderModel, .currentPageNumber, .pageCount, Bool (+8 more)

### Community 50 - "OfflineController"
Cohesion: 0.12
Nodes (14): .body, DownloadRow, .body, .progressText, EnvironmentValues, String, OfflineController, .isOfflineMode (+6 more)

### Community 51 - "seeded()"
Cohesion: 0.12
Nodes (11): OfflineKomgaApiTests, Fixtures, GeneratedMedia, CGSize, Data, Date, Int, KomgaLibrary (+3 more)

### Community 52 - "KomgaSort"
Cohesion: 0.13
Nodes (7): KomgaBooksSort, KomgaSeriesSort, KomgaSort, KomgaUserSort, .defaults, .komgaSort, .body

### Community 53 - "RemoteSSESession"
Cohesion: 0.11
Nodes (15): AsyncStream, RemoteSSESession, AsyncStream, Duration, KomgaHTTPClient, Never, Task, Void (+7 more)

### Community 54 - "PDFPageRenderer"
Cohesion: 0.13
Nodes (17): PDFPageRenderer, RasterPageRenderer, Bool, CGFloat, CGImage, CGImageSource, CGPDFDocument, CGPDFPage (+9 more)

### Community 55 - "BookViewModel"
Cohesion: 0.15
Nodes (19): BookDetails, .body, .progressLabel, .readButtonTitle, BookScreen, .body, BookViewModel, OneshotScreen (+11 more)

### Community 56 - "BookCondition"
Cohesion: 0.08
Nodes (20): BookCondition, allOf, anyOf, author, deleted, libraryId, mediaProfile, mediaStatus (+12 more)

### Community 57 - "DateOp"
Cohesion: 0.10
Nodes (18): KomgaDuration, .isoString, KomgaInstant, Date, Decoder, Int, Int64, String (+10 more)

### Community 58 - "makeDecoder()"
Cohesion: 0.11
Nodes (11): .errorResponse, Fixture, Data, String, ModelDecodingTests, ServerInfoDecodingTests, String, JSONDecoderHelper (+3 more)

### Community 59 - "ScanInterval"
Cohesion: 0.14
Nodes (20): DirectoryListing, DirectoryPath, DirectoryRequest, KomgaLibrary, KomgaLibraryCreateRequest, KomgaLibraryUpdateRequest, ScanInterval, daily (+12 more)

### Community 60 - "AppModule"
Cohesion: 0.15
Nodes (7): URL, AppModule, .api, Bool, OfflineEntitlementStore, SplashBook, OfflineModule

### Community 61 - "KomgaUserId"
Cohesion: 0.17
Nodes (10): KomgaUserId, GRDBBookDtoRepository, Bool, Database, SplashBook, SQL, String, Int (+2 more)

### Community 62 - "Key"
Cohesion: 0.08
Nodes (26): Key, ageRating, allOf, anyOf, author, collectionId, complete, deleted (+18 more)

### Community 63 - "NumericNullableOp"
Cohesion: 0.10
Nodes (19): EqualityNullableOp, isEqualTo, isNotEqualTo, isNotNull, isNull, NumericNullableOp, greaterThan, isEqualTo (+11 more)

### Community 64 - "downloadReadSyncAndDeleteFixtureHero()"
Cohesion: 0.14
Nodes (14): Storage, SplashDatabase, Configuration, DatabaseWriter, URL, GRDBOfflineDataStore, DatabaseWriter, DownloadManagerConfiguration (+6 more)

### Community 65 - "TaskData"
Cohesion: 0.08
Nodes (23): CodingKeys, bookId, file, libraryId, seriesId, type, Status, new (+15 more)

### Community 66 - "decode()"
Cohesion: 0.17
Nodes (12): DecodingError, KeyedDecodingContainer, Decoder, T, decodeOperatorName(), OperatorKeys, dateTime, duration (+4 more)

### Community 67 - "KomgaCookieStore"
Cohesion: 0.18
Nodes (10): HTTPCookie, KomgaCookiePersistence, KomgaCookieStore, .hasRememberMe, Bool, HTTPURLResponse, String, URL (+2 more)

### Community 68 - "SplashCore"
Cohesion: 0.16
Nodes (6): Observation, SplashAppShared, SplashCore, SplashEpubKit, SwiftUI, UIKit

### Community 69 - "init()"
Cohesion: 0.16
Nodes (12): PlatformDownloadManager, Bool, URL, OfflineTasksRepository, async, CheckedContinuation, Int, Never (+4 more)

### Community 70 - "AppMigrations"
Cohesion: 0.10
Nodes (17): Decode failure silently erases the hidden set, GRDBPrivacyStore, Known limit: hidden-id list is plaintext in splash.sqlite (obscurity, not a vault), AppMigrations, .migrator, DatabaseMigrator, Set, String (+9 more)

### Community 71 - "EpubReaderModel"
Cohesion: 0.13
Nodes (20): Locator, .epubLocation, EnvironmentValues, EpubLocation, EpubReaderModel, EpubReaderPresenting, EpubSource, local (+12 more)

### Community 72 - "ReloadScheduler"
Cohesion: 0.11
Nodes (18): listen(), LoadState, error, .isLoading, .isUninitialized, loading, success, uninitialized (+10 more)

### Community 73 - "Port map (Komelia Kotlin → Splash Swift)"
Cohesion: 0.11
Nodes (22): ApiKeyStore, Search condition helpers, KomgaHTTPClient, KomgaSort, OfflineBookStateProvider, PatchValue, F10 — offline API, F12 — sync (+14 more)

### Community 74 - "Testing"
Cohesion: 0.16
Nodes (4): KomgaRemote, SplashDB, SplashUI, Testing

### Community 75 - "OfflineLibrary"
Cohesion: 0.16
Nodes (12): OfflineLibraryRecord, GRDBLibraryRepository, GroupedRows, Database, SQL, String, OfflineLibrary, .id (+4 more)

### Community 76 - "OfflineTestEnvironment"
Cohesion: 0.22
Nodes (9): OfflineKomgaApi, FakeDownloadManager, .cancelled, .launched, Bool, TaskQueueTests, OfflineTestEnvironment, .locator (+1 more)

### Community 77 - "SettingsView"
Cohesion: 0.15
Nodes (18): ColorScheme, AboutView, AnnouncementsView, .body, AppTheme, .colorScheme, AuthenticationActivityView, ImageReaderSettingsView (+10 more)

### Community 78 - "PageId"
Cohesion: 0.20
Nodes (12): CustomStringConvertible, PageId, .description, PageImageLoader, Data, Int, String, Task (+4 more)

### Community 79 - "OfflineSettingsStateRepository"
Cohesion: 0.13
Nodes (13): SettingsState, OfflineSettingsStateRepository, .dataSyncDate, .downloadDirectory, .isOfflineModeEnabled, .readProgressSyncDate, .serverId, .userId (+5 more)

### Community 80 - "OfflineMediaServerId"
Cohesion: 0.19
Nodes (7): OfflineMediaServerRecord, GRDBMediaServerRepository, KomgaLibrary, OfflineMediaServer, OfflineMediaServerId, String, OfflineMediaServerRepository

### Community 81 - "ReaderImage"
Cohesion: 0.19
Nodes (13): PageRenderer, PageBitmap, .pixelSize, ReaderImage, .contentSize, .isVector, ReaderLayout, Bool (+5 more)

### Community 82 - "SyncManager"
Cohesion: 0.24
Nodes (9): Result, Bool, KomgaUser, Never, Task, TimeInterval, SyncManager, .settings (+1 more)

### Community 83 - "PaginationBar"
Cohesion: 0.15
Nodes (12): ClosedRange, Item, gap, page, KomgaSeries, .releaseYear, PaginationBar, .body (+4 more)

### Community 84 - "Komga wire format contract table"
Cohesion: 0.19
Nodes (20): KomgaCookieStore, Komga wire format contract table, Cookie session login, EPUB read-progress restriction, Genres returned lowercased, RemoteActuatorApi, RemoteAnnouncementsApi, RemoteBookApi (+12 more)

### Community 85 - "CodingKeys"
Cohesion: 0.10
Nodes (20): CodingKeys, ageRestriction, author, configurationSource, contentHtml, databaseSource, dateModified, description (+12 more)

### Community 86 - "inMemory()"
Cohesion: 0.25
Nodes (5): AppSettings, AppSettingsRow, GRDBAppSettingsStore, SettingsStateTests, SettingsStoreTests

### Community 87 - "BookDownload"
Cohesion: 0.13
Nodes (14): GRDBBookDownloadRepository, .downloads, BookDownload, .fractionCompleted, .id, Status, complete, downloading (+6 more)

### Community 88 - "ImageReaderSettings"
Cohesion: 0.15
Nodes (12): E, FetchableRecord, ImageReaderSettings, Bool, Float, Int, Int64, GRDBImageReaderSettingsStore (+4 more)

### Community 89 - "OfflineUser"
Cohesion: 0.18
Nodes (9): roles, OfflineUserRecord, .libraries, GRDBUserRepository, KomgaUser, OfflineUser, Bool, KomgaUser (+1 more)

### Community 90 - "OfflineTaskRecord"
Cohesion: 0.20
Nodes (10): OfflineTaskRecord, Status, new, running, OfflineTaskQueue, Bool, DatabaseWriter, Int (+2 more)

### Community 91 - "ReaderImageFactory"
Cohesion: 0.19
Nodes (7): ReaderImageFactory, PDFReaderImageTests, ReaderImageTests, CGImage, Data, Double, Int

### Community 92 - "BookDownloadService"
Cohesion: 0.18
Nodes (12): BookDownloadService, .fileLocator, OfflineRemoteContext, PreparedDownload, Bool, KomgaBook, KomgaLibrary, KomgaSeries (+4 more)

### Community 93 - "AppBootstrap"
Cohesion: 0.16
Nodes (15): App, NSObject, Scene, AppBootstrap, AppDelegate, BootstrapView, .body, SplashApp (+7 more)

### Community 94 - "KomgaIdentifier"
Cohesion: 0.14
Nodes (7): ExpressibleByStringLiteral, RawRepresentable, KomgaAnnouncementId, KomgaIdentifier, .description, .value, String

### Community 95 - "Filter"
Cohesion: 0.15
Nodes (9): SettingsStore, GRDBEpubReaderSettingsStore, GRDBHomeScreenFilterStore, DatabaseWriter, PersistenceContainer, Value, Filter, Int (+1 more)

### Community 96 - "OfflineBook"
Cohesion: 0.18
Nodes (3): GRDBBookRepository, .books, OfflineBook

### Community 97 - "SearchViewModel"
Cohesion: 0.16
Nodes (15): Chokepoint: SearchScreen (conditions + visible on both queries), SearchScreen, .body, SearchViewModel, CGFloat, KomgaSeries, LoadState, Never (+7 more)

### Community 98 - "Synchronization"
Cohesion: 0.14
Nodes (6): OfflineBookState, SplashBook, Bool, Date, KomgaBook, Synchronization

### Community 99 - "RemoteUserApi"
Cohesion: 0.17
Nodes (3): RemoteUserApi, Bool, KomgaUser

### Community 100 - "ApiKeyStore"
Cohesion: 0.25
Nodes (6): SecretsCookiePersistence, String, ApiKeyStore, .apiKey, String, SecretsRepository

### Community 101 - "GRDBBookMetadataAggregationRepository"
Cohesion: 0.17
Nodes (9): .bookMetadataAggregations, .seriesMetadata, GRDBBookMetadataAggregationRepository, GRDBSeriesMetadataRepository, SeriesMetadataChildren, Database, String, OfflineBookMetadataAggregationRepository (+1 more)

### Community 102 - "EncodingTests"
Cohesion: 0.17
Nodes (6): KomgaJSON, Encoder, JSONEncoder, EncodingTests, encodedJSON(), T

### Community 103 - "ReaderType"
Cohesion: 0.21
Nodes (7): ReaderType, continuous, paged, panels, ReaderLogicTests, Int, Set

### Community 104 - "decode()"
Cohesion: 0.15
Nodes (7): OfflineAnnouncementsApi, OfflineSettingsApi, Encodable, Sendable, String, T, WireValues

### Community 105 - "CoreGraphics"
Cohesion: 0.22
Nodes (5): CoreGraphics, CryptoKit, ImageIO, SplashImage, UniformTypeIdentifiers

### Community 106 - "EPUBNavigatorRepresentable"
Cohesion: 0.18
Nodes (11): DirectionalNavigationAdapter, EPUBNavigatorDelegate, EPUBNavigatorViewController, Navigator, NavigatorError, Coordinator, EPUBNavigatorRepresentable, Context (+3 more)

### Community 107 - "OfflineSettings"
Cohesion: 0.21
Nodes (9): PersistableRecord, GRDBOfflineSettingsStore, OfflineSettings, OfflineSettingsRow, Bool, DatabaseWriter, Date, PersistenceContainer (+1 more)

### Community 108 - "init()"
Cohesion: 0.19
Nodes (10): ApiHolder, .current, ServerURLHolder, .get, CommonSettingsRepository, EpubReaderSettingsRepository, HomeScreenFilterRepository, ImageReaderSettingsRepository (+2 more)

### Community 109 - "DownloadEvent"
Cohesion: 0.16
Nodes (9): DownloadEvent, bookDownloadCancelled, bookDownloadCompleted, bookDownloadError, bookDownloadProgress, .bookId, AsyncStream, Int64 (+1 more)

### Community 110 - "CodingKeys"
Cohesion: 0.14
Nodes (14): CodingKeys, context, koboSpan, landmarks, links, locations, metadata, pageList (+6 more)

### Community 111 - "KomgaServerInfo"
Cohesion: 0.20
Nodes (12): BuildKeys, name, version, CommitKeys, id, time, KomgaServerInfo, Date (+4 more)

### Community 112 - "LayoutScaleType"
Cohesion: 0.22
Nodes (10): LayoutScaleType, fitHeight, fitWidth, original, screen, SpreadLayout, Bool, CGFloat (+2 more)

### Community 113 - "OfflineTaskEmitter"
Cohesion: 0.44
Nodes (4): OfflineTaskEmitter, Int, String, TaskEntry

### Community 114 - "persisted()"
Cohesion: 0.23
Nodes (11): .value, AppearanceSettingsView, .body, SeriesCardPreview, .body, Binding, CGFloat, CommonSettingsRepository (+3 more)

### Community 115 - "insertBook()"
Cohesion: 0.20
Nodes (7): OfflineRecordTests, insertBook(), makeBook(), Database, String, URL, TemporaryDatabase

### Community 116 - "KomgaAuthDelegate"
Cohesion: 0.17
Nodes (10): DefaultHTTPClient, DefaultHTTPClientDelegate, HTTPRequest, HTTPRequestConvertible, HTTPResult, Publication, KomgaAuthDelegate, PublicationLoader (+2 more)

### Community 118 - "OfflineFileLocator"
Cohesion: 0.27
Nodes (7): BookDeleteFilesAction, Bool, String, URL, OfflineFileLocator, String, URL

### Community 119 - "SeriesSortOption"
Cohesion: 0.15
Nodes (13): SeriesSortOption, dateAddedAsc, dateAddedDesc, .id, .label, releaseDateAsc, releaseDateDesc, titleAsc (+5 more)

### Community 120 - "EventRecorder"
Cohesion: 0.22
Nodes (9): EventRecorder, .values, AsyncStream, Bool, Duration, Element, Never, Task (+1 more)

### Community 121 - "SplashKit (local SPM package)"
Cohesion: 0.23
Nodes (12): AppModule, KomgaApi (protocol), F1 — KomgaAPI + RemoteAPI, F3 — persistence (GRDB), One SPM package, one target per Gradle module, Protocol-only dependency direction, KomgaAPI, SplashAppShared (+4 more)

### Community 122 - "CodingKeys"
Cohesion: 0.17
Nodes (12): CodingKeys, content, empty, first, last, number, numberOfElements, pageable (+4 more)

### Community 123 - "KomgaEventBroadcaster"
Cohesion: 0.21
Nodes (7): KomgaEventBroadcaster, LiveEventsController, RemoteBox, .api, Never, Task, Void

### Community 124 - "uploadThumbnail()"
Cohesion: 0.30
Nodes (7): KomgaHTTPClient, MultipartForm, .contentType, Bool, Data, String, T

### Community 125 - "relativePath()"
Cohesion: 0.30
Nodes (4): DownloadPathBuilder, String, URL, DownloadPathBuilderTests

### Community 126 - "PdfPageExtractor"
Cohesion: 0.32
Nodes (7): CachedDocument, PdfPageExtractor, CGPDFDocument, CGPDFPage, Data, Int, URL

### Community 127 - "LoginView"
Cohesion: 0.18
Nodes (9): Field, apiKey, password, url, user, LoginView, .body, .form (+1 more)

### Community 128 - "WindowSizeClass"
Cohesion: 0.18
Nodes (8): Comparable, Int, CGFloat, WindowSizeClass, compact, expanded, full, medium

### Community 129 - "Komga fixture server (fixtures/komga)"
Cohesion: 0.20
Nodes (11): F0 — foundations + wire contract, F11 — downloads, Book file download ignores Range, splash-komga compose service, Optional personal library mount, Komga fixture server (fixtures/komga), openapi.json snapshot, Fixture seed data (+3 more)

### Community 130 - "PaywallView"
Cohesion: 0.22
Nodes (9): PaywallContext, Benefit, .body, PaywallView, .body, .priceBlock, LocalizedStringKey, OfflineEntitlementStore (+1 more)

### Community 131 - "StringOp"
Cohesion: 0.18
Nodes (11): StringOp, beginsWith, contains, doesNotBeginWith, doesNotContain, doesNotEndWith, endsWith, isEqualTo (+3 more)

### Community 132 - "GRDBOfflineTasksRepository"
Cohesion: 0.31
Nodes (3): GRDBOfflineTasksRepository, DatabaseWriter, Int

### Community 133 - "OfflineRepositories"
Cohesion: 0.40
Nodes (3): OfflineRepositories, OfflineRepositoryTests, String

### Community 134 - "OfflineAccessPolicy"
Cohesion: 0.24
Nodes (7): AnyObject, AlwaysUnlockedPolicy, .isUnlocked, OfflineAccessPolicy, OfflineModeSwitching, Bool, Void

### Community 135 - "Splash trademark and brand policy"
Cohesion: 0.20
Nodes (10): Deliberate deviations from Komelia, F16 — offline purchase, Repeated author=name,role filter, Lenient Spring Page<T> decoding, Repeatable sort parameter, Komelia, Apache License 2.0, Splash brand features (+2 more)

### Community 136 - "EpubOpenError"
Cohesion: 0.24
Nodes (8): Manifest, EpubOpenError, .errorDescription, invalidURL, open, retrieve, ManifestRelativizer, String

### Community 137 - "ReadiumEpubReader"
Cohesion: 0.27
Nodes (9): ReadiumNavigator, ReadiumStreamer, EpubReaderSettings.ColumnCount, .readium, EpubReaderSettings.FontFamily, .readium, EpubReaderSettings.Theme, .background (+1 more)

### Community 138 - "decode()"
Cohesion: 0.24
Nodes (5): OfflineJSON, Encodable, Sendable, String, T

### Community 140 - "LicensesView"
Cohesion: 0.24
Nodes (7): Entry, .id, LicensesView, .body, String, .body, LicensesTests

### Community 141 - "TestSession"
Cohesion: 0.31
Nodes (6): FixtureAvailability, Bool, CommonSettingsRepository, String, URL, TestSession

### Community 142 - "CLAUDE.md project guide"
Cohesion: 0.25
Nodes (9): Komelia god nodes, Graph structural diagnostics, graphify query/path/explain workflow, Komelia Gradle module map, CMake native superbuild, Privacy policy (no data collection), CLAUDE.md project guide, graphify-out knowledge graph (+1 more)

### Community 143 - "CodingKey"
Cohesion: 0.22
Nodes (9): CodingKey, GitKeys, branch, commit, JavaKeys, vendor, version, Keys (+1 more)

### Community 144 - "EpubSettingsSheet"
Cohesion: 0.31
Nodes (8): EPUBPreferences, EpubReaderSettings, .readiumPreferences, EpubSettingsSheet, .body, Binding, T, WritableKeyPath

### Community 145 - "execute()"
Cohesion: 0.50
Nodes (5): BookKomgaImportAction, RemoteData, Date, KomgaBook, OfflineImportSource

### Community 146 - "AsyncBroadcaster"
Cohesion: 0.36
Nodes (4): AsyncBroadcaster, AsyncStream, Element, Void

### Community 147 - "Splash"
Cohesion: 0.32
Nodes (8): F15 — EPUB, F9 — reader, Adaptive UI, komga-client, Readers (paged, continuous, EPUB, PDF), Readium swift-toolkit, Splash, SplashEpubKit

### Community 148 - "ReadiumEpubReaderView"
Cohesion: 0.43
Nodes (6): ReadiumShared, NavigatorController, ReadiumEpubReaderView, .body, .overlay, Bool

### Community 149 - "SyncReadProgressAction"
Cohesion: 0.43
Nodes (3): Bool, KomgaUser, SyncReadProgressAction

### Community 152 - "append()"
Cohesion: 0.47
Nodes (3): Array, Bool, S

### Community 153 - "HomeScreenFilter"
Cohesion: 0.33
Nodes (3): KomgaSort, Decoder, Encoder

### Community 154 - "TransitionPage"
Cohesion: 0.33
Nodes (6): SplashBook, TransitionPage, bookEnd, bookStart, TransitionPageView, .body

### Community 155 - "Live updates via SSE"
Cohesion: 0.60
Nodes (5): KomgaEvent, KomgaEventBroadcaster, F7 — SSE + live updates, RemoteSSESession, Live updates via SSE

### Community 156 - "cbz()"
Cohesion: 0.60
Nodes (4): cbz(), main(), page(), Path

### Community 157 - "OfflineBanner"
Cohesion: 0.40
Nodes (4): Chokepoint: DownloadViews activeTransfers + settings download list, PrivacyBanner, OfflineBanner, .body

### Community 158 - "RootKeys"
Cohesion: 0.40
Nodes (5): RootKeys, build, git, java, os

### Community 159 - "KomgaAuthenticationState"
Cohesion: 0.50
Nodes (4): Double, T, TimeoutError, withTimeout()

### Community 161 - "State"
Cohesion: 0.40
Nodes (5): State, CheckedContinuation, Never, Set, Void

### Community 162 - "wire_contract_check.py"
Cohesion: 0.70
Nodes (4): collect(), main(), normalize(), spec_index()

### Community 164 - "ThumbnailLoader"
Cohesion: 0.50
Nodes (4): F8 — image engine, ThumbnailLoader, Unknown thumbnail id maps to nil, SplashImage

### Community 165 - "PremiumProduct"
Cohesion: 0.50
Nodes (4): SPLASH_UNLOCK_PREMIUM debug bypass, Premium* naming for the shared one-time purchase, PremiumProduct, Do not change the product id

### Community 166 - "OSKeys"
Cohesion: 0.50
Nodes (4): OSKeys, arch, name, version

## Ambiguous Edges - Review These
- `CLAUDE.md project guide` → `Splash`  [AMBIGUOUS]
  CLAUDE.md · relation: references
- `PrivacyBlur` → `Known limit: thumbnail cache retains hidden covers`  [AMBIGUOUS]
  PRIVACY_FEATURE_PROMPT.md · relation: conceptually_related_to
- `PrivateCatalogViewModel` → `Anti-pattern: a "Private" tab or parallel screen`  [AMBIGUOUS]
  PRIVACY_FEATURE_PROMPT.md · relation: conceptually_related_to

## Knowledge Gaps
- **588 isolated node(s):** `ReadiumStreamer`, `invalidURL`, `open`, `.errorDescription`, `.readium` (+583 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `CLAUDE.md project guide` and `Splash`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `PrivacyBlur` and `Known limit: thumbnail cache retains hidden covers`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `PrivateCatalogViewModel` and `Anti-pattern: a "Private" tab or parallel screen`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `Foundation` connect `Remote HTTP Clients` to `Komga API Surface`, `App Settings Models`, `Server Event Payloads`, `Paged Requests`, `Offline GRDB Repositories`, `Keychain & Secrets`, `Book Wire Models`, `Purchases & Entitlement`, `Offline Delete Actions`, `Readium JSON`, `Offline Thumbnails`, `PatchValue`, `XXH3`, `HomeScreenFilter`, `AppRootView`, `SeriesCondition`, `Sendable`, `KomgaAuthenticationState`, `OfflineSeries`, `KomgaAuthor`, `OfflineRecord`, `KomgaSort`, `RemoteSSESession`, `ScanInterval`, `decode()`, `KomgaCookieStore`, `SplashCore`, `init()`, `ReloadScheduler`, `Testing`, `PageId`, `ReaderImage`, `ImageReaderSettings`, `BookDownloadService`, `KomgaIdentifier`, `Synchronization`, `CoreGraphics`, `KomgaServerInfo`, `uploadThumbnail()`, `relativePath()`?**
  _High betweenness centrality (0.099) - this node is a cross-community bridge._
- **Why does `KomgaBookId` connect `Book Thumbnails & Metadata` to `Komga API Surface`, `Navigation Destinations`, `Identifiers & API Errors`, `Server Event Payloads`, `Auth State & Library Screen`, `OfflineRepositories`, `Offline GRDB Repositories`, `decode()`, `Read Lists`, `Offline API Implementations`, `OfflineDownloads`, `Book Wire Models`, `Offline Delete Actions`, `View Model Factory & Filter Rule`, `Readium JSON`, `Offline Thumbnails`, `SyncReadProgressAction`, `PatchValue`, `URLSessionDownloadManager`, `RecordingBookApi`, `StubImportSource`, `OfflineReadProgress`, `State`, `RemoteBookApi`, `ReaderViewModel`, `OfflineRecord`, `OfflineError`, `ThumbnailRequest`, `SettingsState`, `OfflineController`, `seeded()`, `BookViewModel`, `AppModule`, `KomgaUserId`, `TaskData`, `init()`, `OfflineTestEnvironment`, `PageId`, `SyncManager`, `BookDownload`, `BookDownloadService`, `KomgaIdentifier`, `OfflineBook`, `DownloadEvent`, `OfflineTaskEmitter`, `OfflineEvents`?**
  _High betweenness centrality (0.095) - this node is a cross-community bridge._
- **Why does `KomgaAPI` connect `Remote HTTP Clients` to `Komga API Surface`, `Auth State & Library Screen`, `Paged Requests`, `ReadiumEpubReader`, `Offline GRDB Repositories`, `TestSession`, `Home Filters & Shelves`, `Offline Delete Actions`, `View Model Factory & Filter Rule`, `SyncReadProgressAction`, `Offline Thumbnails`, `HomeScreenFilter`, `RecordingBookApi`, `AppRootView`, `KomgaAuthenticationState`, `ThumbnailLoader`, `OfflineSeries`, `RemoteKomgaApi`, `SeriesViewModel`, `ReaderViewModel`, `ThumbnailRequest`, `BookViewModel`, `AppModule`, `SplashCore`, `init()`, `EpubReaderModel`, `Testing`, `OfflineTestEnvironment`, `SettingsView`, `PageId`, `SyncManager`, `BookDownloadService`, `SearchViewModel`, `Synchronization`, `CoreGraphics`, `init()`, `KomgaEventBroadcaster`?**
  _High betweenness centrality (0.087) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `KomgaLibraryId` (e.g. with `HiddenContentFilter` and `.library()`) actually correct?**
  _`KomgaLibraryId` has 3 INFERRED edges - model-reasoned connections that need verification._