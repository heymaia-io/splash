# Graph Report - .  (2026-09-17)

## Corpus Check
- 38 files · ~120,990 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 4488 nodes · 11648 edges · 233 communities (190 shown, 43 thin omitted)
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 982 edges (avg confidence: 0.81)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Komga API Surface
- Reader Image Pipeline
- Offline Data Store
- Offline Komga APIs
- Premium Entitlement & Paywall
- Thumbnail Loading
- Offline Series & Books
- Keychain & Secrets
- Module Imports
- Readium JSON
- UIKit Reader Views
- Paged Requests
- User & Activity Models
- Settings Models
- Navigation Shell
- Offline Controller & Downloads
- Content Cards
- Offline Book Models
- Book Wire Models
- Server Events
- Library Screen & Filtering
- XXH3 File Hashing
- Series Wire Models
- Reader View Model
- Remote Book API
- Date & Duration Coding
- Home Shelves & Filtering
- Sync Manager Tests
- Series Screen
- Settings Screens
- Continuous Reader
- Search & Query Enums
- Offline Search SQL
- Collections & Read Lists API
- Paged Reader
- App Entry Point
- Search Conditions
- Offline Book DTOs
- Offline Sync Actions
- Book & Oneshot Screens
- Thumbnail Loader Tests
- Offline Series Records
- App Module
- View Model Factory
- Sorting
- Offline Repositories
- Collection Screens
- GRDBRead Progress Repository
- Offline Records
- Reader View
- Remote Misc Apis
- Settings State
- GRDBSeries Dto Repository
- Cards
- Privacy Controller Tests
- Privacy Controller
- URLSession Download Manager
- Search Screen
- Login View Model
- Hidden Content Filter Tests
- GRDBSettings Stores
- Library
- Test Imports
- Search Condition
- Offline Downloads
- Main Navigator
- Komga Cookie Store
- Search Condition
- Search Operator
- Task Data
- Komga HTTPClient
- Search Operator
- Offline Book Api
- Book Content Extractors
- User
- Task Queue Tests
- Test Support
- Hidden Content Filter
- port map
- Offline Komga Api
- Book Download
- Identifiers
- Offline Domain Adapters
- Offline Repository Protocols
- Settings View
- Splash App
- wire format
- Settings Store Tests
- GRDBBook Repositories
- App Root View
- GRDBServer Repositories
- GRDBServer Repositories
- Offline Task Queue
- Book Download Service
- Sync Manager
- Main Screen View Model
- Library Server User Actions
- Private Content Settings
- Offline Komga Api Tests
- Premium Access Policy
- Load State & Reloading
- Offline Settings
- Privacy State Storage
- GRDBBook Repositories
- Page Image Loader
- Migration Tests
- Remote Misc Apis
- Offline Migrations
- Fixture Server Offline Tests
- Offline Repository Tests
- GRDBSeries Repositories
- Model Decoding Tests
- Home Screen Filter
- Hidden Downloads Tests
- Support
- Readium Epub Reader
- PRIVACY FEATURE PROMPT
- Readium
- Server
- Settings Models
- GRDBServer Repositories
- Offline Task Emitter
- Task Processor
- Hide Menu Action
- Library Screen
- Readium Epub Reader
- Offline Domain Adapters
- Pdf Page Extractor
- Epub Reader Model
- Test Support
- Reader Tests
- Reader Image Tests
- Readium Epub Reader
- README
- App Module
- PRIVACY FEATURE PROMPT
- Paywall View
- Page
- Multipart Form
- Book Actions
- Download Path Builder
- Login View
- Privacy Test Doubles
- Readium Epub Reader
- Window Size Class
- README
- Device Authentication
- PRIVACY FEATURE PROMPT
- Readium Epub Reader
- Offline Komga Api
- Search Operator
- Server Sent Event Parser
- Offline Read Progress
- TRADEMARKS
- Readium Epub Reader
- Remote SSESession
- Book Download
- Offline Fallback View
- Offline Record Tests
- Login View Model Tests
- CLAUDE
- Server
- Readium Epub Reader
- App Module
- PRIVACY FEATURE PROMPT
- Download Views
- Komga Authentication State
- Async Broadcaster
- README
- App Module
- Search Operator
- Hidden Download Rows
- Book Actions
- GRDBSettings Stores
- Task Processor
- Licenses View
- setup
- PRIVACY FEATURE PROMPT
- Komga HTTPClient
- Komga HTTPClient
- Home Screen Filter
- port map
- generate library
- Server
- Komga Authentication State
- Login View Model
- Unit Tests
- Task Queue Tests
- wire contract check
- port map
- PRIVACY FEATURE PROMPT
- Server
- Support
- Package
- Offline Module
- Login View Model
- Test Clock
- Content
- EpubReaderSettingsRepository
- KomgaSeries
- Mutex
- OfflineEntitlementStore
- DatabaseMigrator
- Set
- DatabaseWriter
- PersistenceContainer
- KomgaSeries
- Duration
- KomgaSeries
- LoadState
- Int64
- KomgaSeries
- AsyncStream
- Bool
- String
- T
- LocalizedStringKey
- OfflineEntitlementStore
- LoadState
- KomgaSeries
- LoadState
- KomgaSeries
- LoadState
- KomgaSeries
- LoadState
- KomgaSeries
- LoadState
- KomgaSeries
- LoadState
- KomgaUser
- WritableKeyPath
- Database
- Set

## God Nodes (most connected - your core abstractions)
1. `KomgaBookId` - 253 edges
2. `KomgaAPI` - 173 edges
3. `KomgaLibraryId` - 123 edges
4. `KomgaSeriesId` - 118 edges
5. `KomgaUserId` - 83 edges
6. `OfflineDataStore` - 77 edges
7. `KomgaPageRequest` - 75 edges
8. `KomgaEvent` - 73 edges
9. `Page` - 71 edges
10. `OfflineActions` - 60 edges

## Surprising Connections (you probably didn't know these)
- `PrivacyBanner` --semantically_similar_to--> `OfflineBanner`  [INFERRED] [semantically similar]
  PRIVACY_FEATURE_PROMPT.md → swift/Packages/SplashKit/Sources/SplashUI/Offline/DownloadViews.swift
- `GRDBPrivacyStore` --semantically_similar_to--> `GRDBHomeScreenFilterStore`  [INFERRED] [semantically similar]
  PRIVACY_FEATURE_PROMPT.md → swift/Packages/SplashKit/Sources/SplashDB/Settings/GRDBSettingsStores.swift
- `PrivacySettingsView` --conceptually_related_to--> `SettingsView`  [INFERRED]
  PRIVACY_FEATURE_PROMPT.md → swift/Packages/SplashKit/Sources/SplashUI/Settings/SettingsView.swift
- `Long-press gesture beside the "All Libraries" chip` --conceptually_related_to--> `LibraryScreen`  [INFERRED]
  PRIVACY_FEATURE_PROMPT.md → swift/Packages/SplashKit/Sources/SplashUI/Screens/LibraryScreen.swift
- `Chokepoint: SeriesScreen.loadBooks (bookConditions exact, paging stays right)` --conceptually_related_to--> `SeriesViewModel`  [INFERRED]
  PRIVACY_FEATURE_PROMPT.md → swift/Packages/SplashKit/Sources/SplashUI/Screens/SeriesScreen.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **SplashKit target stack in dependency order** — readme_komgaapi, readme_komgaremote, readme_splashcore, readme_splashoffline, readme_splashdb, readme_splashimage, readme_splashui, readme_splashappshared, readme_dependency_direction [EXTRACTED 1.00]
- **Offline reading flow: download, verify, serve, sync** — readme_offline_mode, docs_port_map_phase_f10, docs_port_map_phase_f11, docs_port_map_phase_f12, docs_wire_format_no_range_support, readme_splashoffline, readme_splashdb [INFERRED 0.85]
- **Komga API protocol surface (107 operations)** — docs_wire_format_remotebookapi, docs_wire_format_remoteseriesapi, docs_wire_format_remotelibraryapi, docs_wire_format_remotecollectionsapi, docs_wire_format_remotereadlistapi, docs_wire_format_remotereferentialapi, docs_wire_format_remoteuserapi, docs_wire_format_remotesettingsapi, docs_wire_format_remotetaskapi, docs_wire_format_remoteactuatorapi, docs_wire_format_remoteannouncementsapi, docs_wire_format_remotefilesystemapi, docs_wire_format_remotessesession [EXTRACTED 1.00]
- **Single-source-of-truth filter flow (controller → provider → filter → chokepoints)** — privacy_feature_prompt_privacycontroller, privacy_feature_prompt_hiddencontentfilter, swift_packages_splashkit_sources_splashui_common_dependencies_viewmodelfactory, privacy_feature_prompt_filter_chokepoints, privacy_feature_prompt_single_source_of_truth [INFERRED 0.85]
- **Reveal / unlock authentication flow** — privacy_feature_prompt_privacyrevealgesture, privacy_feature_prompt_deviceauthenticating, privacy_feature_prompt_localdeviceauthenticator, privacy_feature_prompt_privacycontroller, privacy_feature_prompt_paywallcontext, privacy_feature_prompt_silent_failure_no_oracle [INFERRED 0.85]
- **Discarded approaches, each with the bug it reintroduces** — privacy_feature_prompt_antipattern_private_tab, privacy_feature_prompt_antipattern_hiddencontentmode, privacy_feature_prompt_antipattern_client_side_filter_evaluator, privacy_feature_prompt_antipattern_duplicate_filter_rule, privacy_feature_prompt_antipattern_serverurl_stamp, privacy_feature_prompt_antipattern_app_level_pin, privacy_feature_prompt_antipattern_overfetch_splicing [EXTRACTED 1.00]

## Communities (233 total, 43 thin omitted)

### Community 0 - "Komga API Surface"
Cohesion: 0.04
Nodes (52): Filtering lives in view models, not in an API decorator, KomgaActuatorApi, KomgaBookApi, KomgaCollectionsApi, KomgaFileSystemApi, KomgaLibraryApi, KomgaReadListApi, KomgaReferentialApi (+44 more)

### Community 1 - "Reader Image Pipeline"
Cohesion: 0.05
Nodes (41): PageRenderer, PDFPageRenderer, RasterPageRenderer, Bool, CGFloat, CGImage, CGImageSource, CGPDFDocument (+33 more)

### Community 2 - "Offline Data Store"
Cohesion: 0.06
Nodes (24): KomgaAPIError, decoding, httpStatus, invalidResponse, .isNotFound, .isUnauthorized, .statusCode, unsupported (+16 more)

### Community 3 - "Offline Komga APIs"
Cohesion: 0.07
Nodes (19): KomgaCollection, KomgaCollectionCreateRequest, KomgaCollectionUpdateRequest, KomgaReadList, KomgaReadListCreateRequest, KomgaReadListQuery, KomgaReadListThumbnail, KomgaReadListUpdateRequest (+11 more)

### Community 4 - "Premium Entitlement & Paywall"
Cohesion: 0.05
Nodes (39): Equatable, LocalizedError, Product, DataState, authenticationRequired, loaded, Benefit, PaywallContext (+31 more)

### Community 5 - "Thumbnail Loading"
Cohesion: 0.06
Nodes (41): ContentMode, NSString, .offlineApi, CGImageBox, Configuration, .`default`, DecodedImage, .pixelSize (+33 more)

### Community 6 - "Offline Series & Books"
Cohesion: 0.06
Nodes (15): KomgaSeriesId, RemoteSeriesApi, Data, KomgaHTTPClient, KomgaSeriesThumbnail, String, GRDBBookRepository, OfflineSeriesApi (+7 more)

### Community 7 - "Keychain & Secrets"
Cohesion: 0.08
Nodes (25): Security, ApiKeyStore, .apiKey, ServerURL, String, InMemorySecretsRepository, KeychainClient, KeychainError (+17 more)

### Community 8 - "Module Imports"
Cohesion: 0.07
Nodes (5): Foundation, GRDB, KomgaAPI, SplashOffline, Synchronization

### Community 9 - "Readium JSON"
Cohesion: 0.06
Nodes (45): JSONValue, array, bool, null, number, object, string, R2Device (+37 more)

### Community 10 - "UIKit Reader Views"
Cohesion: 0.09
Nodes (24): CGPoint, NSCoder, .pages, Configuration, ContinuousStripView, Coordinator, PagedSpreadView, SpreadScrollView (+16 more)

### Community 11 - "Paged Requests"
Cohesion: 0.08
Nodes (23): KomgaBookSearch, KomgaPageRequest, .queryItems, Page, Pageable, Sort, Bool, Decoder (+15 more)

### Community 12 - "User & Activity Models"
Cohesion: 0.07
Nodes (40): Encodable, KeyedEncodingContainer, PatchValue, .isUnset, none, some, unset, Bool (+32 more)

### Community 13 - "Settings Models"
Cohesion: 0.05
Nodes (49): CaseIterable, AppTheme, dark, darker, light, BooksLayout, grid, list (+41 more)

### Community 14 - "Navigation Shell"
Cohesion: 0.06
Nodes (38): GlobalSearchField, MainShellView, .body, .isSearchable, .rootScreen, .tabBinding, MainTab, home (+30 more)

### Community 15 - "Offline Controller & Downloads"
Cohesion: 0.08
Nodes (31): AnyObject, DownloadEvent, Int64, OfflineDownloads, Chokepoint: DownloadViews activeTransfers + settings download list, PrivacyBanner, downloads, .body (+23 more)

### Community 16 - "Content Cards"
Cohesion: 0.06
Nodes (42): Footer, Overlay, BookCard, .body, .isHidden, .progressBar, CollectionCard, .body (+34 more)

### Community 17 - "Offline Book Models"
Cohesion: 0.08
Nodes (29): GRDBThumbnailBookRepository, .bookThumbnails, CodingKeys, type, EpubTocEntry, KomgaBook, KomgaBookPage, KomgaBookThumbnail (+21 more)

### Community 18 - "Book Wire Models"
Cohesion: 0.11
Nodes (31): Identifiable, KomgaBook, KomgaBookMetadata, KomgaBookMetadataUpdateRequest, KomgaBookPage, KomgaBookReadProgressUpdateRequest, KomgaBookThumbnail, KomgaMediaStatus (+23 more)

### Community 19 - "Server Events"
Cohesion: 0.06
Nodes (34): KomgaEvent, bookAdded, bookChanged, bookDeleted, bookImported, collectionAdded, collectionChanged, collectionDeleted (+26 more)

### Community 20 - "Library Screen & Filtering"
Cohesion: 0.09
Nodes (31): .hiddenFilter, LibraryScreen, .body, .libraryPicker, .seriesTab, LibraryViewModel, .cardWidth, .libraries (+23 more)

### Community 21 - "XXH3 File Hashing"
Cohesion: 0.15
Nodes (16): FileHasher, Hash128, Data, Int, String, UInt8, URL, XXH3 (+8 more)

### Community 22 - "Series Wire Models"
Cohesion: 0.11
Nodes (28): links, KomgaAlternativeTitle, KomgaAuthor, KomgaReadingDirection, leftToRight, rightToLeft, vertical, webtoon (+20 more)

### Community 23 - "Reader View Model"
Cohesion: 0.09
Nodes (22): KomgaApi, ReaderType, continuous, paged, panels, RemoteImportSource, KomgaBookPage, BookSiblingsContext (+14 more)

### Community 24 - "Remote Book API"
Cohesion: 0.08
Nodes (11): RemoteBookApi, Bool, Data, Int, KomgaBook, KomgaBookPage, KomgaBookThumbnail, KomgaHTTPClient (+3 more)

### Community 25 - "Date & Duration Coding"
Cohesion: 0.09
Nodes (20): KomgaDuration, .isoString, KomgaInstant, KomgaJSON, KomgaLocalDate, .description, LenientEnum, Date (+12 more)

### Community 26 - "Home Shelves & Filtering"
Cohesion: 0.08
Nodes (31): HomeScreenFilter, Anti-pattern: client-side evaluator of HomeScreenFilter conditions, Chokepoint: HomeViewModel.fetch (5 branches), HomeScreen, .body, .content, .filterChips, .visibleSections (+23 more)

### Community 27 - "Sync Manager Tests"
Cohesion: 0.11
Nodes (11): KomgaBookId, RecordingBookApi, .progressWrites, Bool, Data, Int, KomgaBookPage, KomgaBookThumbnail (+3 more)

### Community 28 - "Series Screen"
Cohesion: 0.11
Nodes (23): SeriesScreen, .body, .nextBook, SeriesViewModel, .cardWidth, CGFloat, CommonSettingsRepository, Destination (+15 more)

### Community 29 - "Settings Screens"
Cohesion: 0.09
Nodes (33): ColorScheme, KomgaAuthenticationActivity, KomgaServerInfo, KomgaSettings, KomgaSettingsUpdateRequest, KomgaUser, Chokepoint: SettingsView (ServerSettingsView, AccountSettingsView.libraryAccess, MediaAnalysisView), AboutView (+25 more)

### Community 30 - "Continuous Reader"
Cohesion: 0.10
Nodes (20): Range, images, ContinuousReaderModel, .isVertical, Bool, CGFloat, CGRect, CGSize (+12 more)

### Community 31 - "Search & Query Enums"
Cohesion: 0.13
Nodes (36): Codable, Hashable, Sendable, CopyMode, copy, hardlink, move, KomgaReadStatus (+28 more)

### Community 32 - "Offline Search SQL"
Cohesion: 0.14
Nodes (16): EqualityOp, isEqualTo, isNotEqualTo, BookSearchHelper, SeriesSearchHelper, SQL, SearchSQL, Bool (+8 more)

### Community 33 - "Collections & Read Lists API"
Cohesion: 0.12
Nodes (11): KomgaCollectionThumbnail, Int, Int64, KomgaCollectionId, RemoteCollectionsApi, Bool, Data, KomgaHTTPClient (+3 more)

### Community 34 - "Paged Reader"
Cohesion: 0.13
Nodes (18): Index, Collection, LoadedPage, .id, PagedReaderModel, .currentPageNumber, .pageCount, Bool (+10 more)

### Community 35 - "App Entry Point"
Cohesion: 0.12
Nodes (7): Observation, SplashAppShared, SplashCore, SplashEpubKit, SplashImage, SwiftUI, UIKit

### Community 36 - "Search Conditions"
Cohesion: 0.07
Nodes (30): SearchValue, AuthorMatch, PosterMatch, PosterType, generated, sidecar, userUploaded, SeriesCondition (+22 more)

### Community 37 - "Offline Book DTOs"
Cohesion: 0.14
Nodes (15): KomgaUserId, GRDBBookDtoRepository, Bool, Database, SplashBook, SQL, String, GRDBSeriesDtoRepository (+7 more)

### Community 38 - "Offline Sync Actions"
Cohesion: 0.15
Nodes (25): BookDeleteAction, BookMarkRemoteDeletedAction, OfflineActionEnvironment, .isOffline, Bool, LibraryDeleteAction, LibraryKomgaImportAction, MediaServerDeleteAction (+17 more)

### Community 39 - "Book & Oneshot Screens"
Cohesion: 0.12
Nodes (26): BookDetails, .body, .progressLabel, .readButtonTitle, BookScreen, .body, BookViewModel, .library (+18 more)

### Community 40 - "Thumbnail Loader Tests"
Cohesion: 0.09
Nodes (9): CountingBookApi, .calls, Bool, Data, Int, KomgaBookPage, KomgaBookThumbnail, SplashBook (+1 more)

### Community 41 - "Offline Series Records"
Cohesion: 0.10
Nodes (17): .series, .seriesThumbnails, GRDBSeriesRepository, GRDBThumbnailSeriesRepository, KomgaSeries, KomgaSeriesThumbnail, OfflineSeries, OfflineThumbnailSeries (+9 more)

### Community 42 - "App Module"
Cohesion: 0.11
Nodes (19): ApiKeyStore, EpubReaderSettingsRepository, EpubSource, KomgaCookieStore, OfflineModule, OfflineSettingsStateRepository, RemoteKomgaApi, AppModule (+11 more)

### Community 43 - "View Model Factory"
Cohesion: 0.09
Nodes (23): BookSiblingsContext, Anti-pattern: a second copy of the "should I filter?" rule, One source of truth for "should I filter?", ReaderViewModel, AsyncStream, CommonSettingsRepository, HiddenContentFilter, HomeScreenFilterRepository (+15 more)

### Community 44 - "Sorting"
Cohesion: 0.11
Nodes (9): Direction, asc, desc, KomgaBooksSort, KomgaSeriesSort, KomgaSort, KomgaUserSort, Order (+1 more)

### Community 45 - "Offline Repositories"
Cohesion: 0.10
Nodes (22): GRDBOfflineRepositories, .bookDtos, .books, .mediaServers, .referential, .seriesDtos, Database, OfflineReferentialRepository (+14 more)

### Community 46 - "Collection Screens"
Cohesion: 0.12
Nodes (27): Card, CardGrid, .body, CGFloat, CollectionScreen, .body, CollectionViewModel, .cardWidth (+19 more)

### Community 47 - "GRDBRead Progress Repository"
Cohesion: 0.10
Nodes (12): .readProgress, GRDBReadProgressRepository, Database, Date, SQL, Int, OfflineReadProgress, .komgaReadProgress (+4 more)

### Community 48 - "Offline Records"
Cohesion: 0.21
Nodes (22): DatabaseColumnDecodingStrategy, DatabaseColumnEncodingStrategy, OfflineBookMetadataRecord, OfflineBookRecord, OfflineMediaPageRecord, OfflineMediaRecord, OfflineReadProgressRecord, OfflineRecord (+14 more)

### Community 49 - "Reader View"
Cohesion: 0.12
Nodes (19): PreferenceKey, ContinuousStripViewStep, ReaderView, .body, .closeButton, .content, .currentPage, .flashOverlay (+11 more)

### Community 50 - "Remote Misc Apis"
Cohesion: 0.10
Nodes (11): KomgaAnnouncementsApi, KomgaSettingsApi, OfflineBookStateProvider, RemoteReadListApi, SplashBook, RemoteActuatorApi, RemoteAnnouncementsApi, RemoteFileSystemApi (+3 more)

### Community 51 - "Settings State"
Cohesion: 0.12
Nodes (17): escaping, AsyncSerialLock, InMemorySettingsStore, SettingsState, .value, async, AsyncStream, KeyPath (+9 more)

### Community 52 - "GRDBSeries Dto Repository"
Cohesion: 0.18
Nodes (6): KomgaLibraryId, RemoteLibraryApi, KomgaLibrary, GRDBReferentialRepository, Int, String

### Community 53 - "Cards"
Cohesion: 0.10
Nodes (20): ClosedRange, Row, ErrorView, .body, Item, gap, page, PaginationBar (+12 more)

### Community 54 - "Privacy Controller Tests"
Cohesion: 0.18
Nodes (8): Decoder, ScenePhase, PrivacyState, TimeInterval, Box, PrivacyControllerTests, Date, T

### Community 55 - "Privacy Controller"
Cohesion: 0.10
Nodes (21): Element, DeviceAuthenticating, EnvironmentValues, PrivacyController, .hasHiddenContent, .hidden, .lockPolicy, .lockTimeout (+13 more)

### Community 56 - "URLSession Download Manager"
Cohesion: 0.13
Nodes (11): OperationQueue, RequestProvider, Bool, Int64, String, URLSession, TaskInfo, URLSessionDownloadManager (+3 more)

### Community 57 - "Search Screen"
Cohesion: 0.09
Nodes (26): Chokepoint: SearchScreen (conditions + visible on both queries), LoadState, error, .isLoading, .isUninitialized, loading, success, uninitialized (+18 more)

### Community 58 - "Login View Model"
Cohesion: 0.16
Nodes (10): LoginSession, LoginViewModel, MainActor, Never, Task, Void, LoginViewModelTests, Duration (+2 more)

### Community 59 - "Hidden Content Filter Tests"
Cohesion: 0.14
Nodes (8): HiddenContentFilterTests, HiddenContentFilter, KomgaBookId, KomgaLibrary, KomgaLibraryId, KomgaSeriesId, SplashBook, String

### Community 60 - "GRDBSettings Stores"
Cohesion: 0.12
Nodes (12): DatabaseWriter, Filter, PersistenceContainer, SettingsStore, State, GRDBEpubReaderSettingsStore, GRDBHomeScreenFilterStore, GRDBImageReaderSettingsStore (+4 more)

### Community 61 - "Library"
Cohesion: 0.13
Nodes (20): DirectoryListing, DirectoryPath, DirectoryRequest, KomgaLibrary, KomgaLibraryCreateRequest, KomgaLibraryUpdateRequest, ScanInterval, daily (+12 more)

### Community 62 - "Test Imports"
Cohesion: 0.12
Nodes (5): KomgaRemote, SplashDB, SplashUI, LicensesTests, Testing

### Community 63 - "Search Condition"
Cohesion: 0.08
Nodes (20): BookCondition, allOf, anyOf, author, deleted, libraryId, mediaProfile, mediaStatus (+12 more)

### Community 64 - "Offline Downloads"
Cohesion: 0.11
Nodes (10): BookDeleteFilesAction, Bool, String, URL, OfflineDownloads, Int64, URL, OfflineFileLocator (+2 more)

### Community 65 - "Main Navigator"
Cohesion: 0.11
Nodes (20): Destination, book, collection, downloads, home, library, oneshot, readList (+12 more)

### Community 66 - "Komga Cookie Store"
Cohesion: 0.17
Nodes (10): HTTPCookie, KomgaCookiePersistence, KomgaCookieStore, .hasRememberMe, Bool, HTTPURLResponse, String, URL (+2 more)

### Community 67 - "Search Condition"
Cohesion: 0.08
Nodes (26): Key, ageRating, allOf, anyOf, author, collectionId, complete, deleted (+18 more)

### Community 68 - "Search Operator"
Cohesion: 0.10
Nodes (19): EqualityNullableOp, isEqualTo, isNotEqualTo, isNotNull, isNull, NumericNullableOp, greaterThan, isEqualTo (+11 more)

### Community 69 - "Task Data"
Cohesion: 0.08
Nodes (23): CodingKeys, bookId, file, libraryId, seriesId, type, Status, new (+15 more)

### Community 70 - "Komga HTTPClient"
Cohesion: 0.18
Nodes (13): Body, String, KomgaHTTPClient, .currentBaseURL, Data, HTTPURLResponse, JSONEncoder, T (+5 more)

### Community 71 - "Search Operator"
Cohesion: 0.17
Nodes (14): DecodingError, KeyedDecodingContainer, Decoder, BooleanOp, isFalse, isTrue, decodeOperatorName(), OperatorKeys (+6 more)

### Community 72 - "Offline Book Api"
Cohesion: 0.12
Nodes (7): OfflineBookApi, .userId, Bool, Data, Int, KomgaBookThumbnail, String

### Community 73 - "Book Content Extractors"
Cohesion: 0.19
Nodes (13): Archive, ReadiumZIPFoundation, BookContentExtractors, CachedArchive, DataBuffer, DivinaExtractor, EpubExtractor, Data (+5 more)

### Community 74 - "User"
Cohesion: 0.09
Nodes (22): CodingKeys, ageRestriction, author, configurationSource, contentHtml, databaseSource, dateModified, description (+14 more)

### Community 75 - "Task Queue Tests"
Cohesion: 0.20
Nodes (10): KomgaEventBroadcaster, OfflineKomgaApi, FakeDownloadManager, .cancelled, .launched, Bool, TaskQueueTests, OfflineTestEnvironment (+2 more)

### Community 76 - "Test Support"
Cohesion: 0.14
Nodes (12): SyncManagerTests, Fixtures, StubImportSource, Date, Int, KomgaBook, KomgaBookPage, KomgaLibrary (+4 more)

### Community 77 - "Hidden Content Filter"
Cohesion: 0.13
Nodes (16): BookCondition, SeriesCondition, HiddenContent, .isEmpty, Bool, KomgaBookId, KomgaLibraryId, KomgaSeriesId (+8 more)

### Community 78 - "port map"
Cohesion: 0.11
Nodes (22): ApiKeyStore, Search condition helpers, KomgaHTTPClient, KomgaSort, OfflineBookStateProvider, PatchValue, F10 — offline API, F12 — sync (+14 more)

### Community 79 - "Offline Komga Api"
Cohesion: 0.11
Nodes (12): .errorResponse, OfflineSettingsApi, Encodable, Sendable, String, T, WireValues, ServerInfoDecodingTests (+4 more)

### Community 80 - "Book Download"
Cohesion: 0.13
Nodes (15): GRDBBookDownloadRepository, .downloads, Row, BookDownload, .fractionCompleted, .id, Status, complete (+7 more)

### Community 81 - "Identifiers"
Cohesion: 0.11
Nodes (8): ExpressibleByStringLiteral, RawRepresentable, KomgaAnnouncementId, KomgaIdentifier, .description, .value, String, OfflineAnnouncementsApi

### Community 82 - "Offline Domain Adapters"
Cohesion: 0.13
Nodes (12): SettingsState, OfflineSettingsStateRepository, .dataSyncDate, .downloadDirectory, .isOfflineModeEnabled, .readProgressSyncDate, .serverId, .userId (+4 more)

### Community 83 - "Offline Repository Protocols"
Cohesion: 0.10
Nodes (8): R2Progression, KomgaBookPage, OfflineError, .description, fileUnavailable, integrityCheckFailed, invalidArgument, invalidState

### Community 84 - "Settings View"
Cohesion: 0.15
Nodes (17): .value, .body, AppearanceSettingsView, .body, ImageReaderSettingsView, .body, SeriesCardPreview, .body (+9 more)

### Community 85 - "Splash App"
Cohesion: 0.14
Nodes (16): App, NSObject, Scene, AppBootstrap, AppDelegate, BootstrapView, .body, SplashApp (+8 more)

### Community 86 - "wire format"
Cohesion: 0.19
Nodes (20): KomgaCookieStore, Komga wire format contract table, Cookie session login, EPUB read-progress restriction, Genres returned lowercased, RemoteActuatorApi, RemoteAnnouncementsApi, RemoteBookApi (+12 more)

### Community 87 - "Settings Store Tests"
Cohesion: 0.24
Nodes (6): AppSettings, AppSettingsRow, GRDBAppSettingsStore, AppSettings, SettingsStateTests, SettingsStoreTests

### Community 88 - "GRDBBook Repositories"
Cohesion: 0.16
Nodes (10): BookMetadataChildren, GRDBBookMetadataRepository, String, .bookMetadata, GroupedRows, Database, SQL, String (+2 more)

### Community 89 - "App Root View"
Cohesion: 0.21
Nodes (12): EpubReaderModel, LoginSession, LoginViewModel, MainNavigator, Deep-link guard in AppRootView.open(_:), AppRootView, .body, AppSession (+4 more)

### Community 90 - "GRDBServer Repositories"
Cohesion: 0.16
Nodes (9): roles, .libraries, .users, GRDBUserRepository, KomgaUser, OfflineUser, Bool, KomgaUser (+1 more)

### Community 91 - "GRDBServer Repositories"
Cohesion: 0.22
Nodes (6): OfflineMediaServerRecord, GRDBMediaServerRepository, KomgaLibrary, OfflineMediaServer, OfflineMediaServerId, String

### Community 92 - "Offline Task Queue"
Cohesion: 0.20
Nodes (10): OfflineTaskRecord, Status, new, running, OfflineTaskQueue, Bool, DatabaseWriter, Int (+2 more)

### Community 93 - "Book Download Service"
Cohesion: 0.18
Nodes (12): BookDownloadService, .fileLocator, OfflineRemoteContext, PreparedDownload, Bool, KomgaBook, KomgaLibrary, KomgaSeries (+4 more)

### Community 94 - "Sync Manager"
Cohesion: 0.27
Nodes (9): Result, Bool, KomgaUser, Never, Task, TimeInterval, SyncManager, .settings (+1 more)

### Community 95 - "Main Screen View Model"
Cohesion: 0.18
Nodes (8): MainScreenViewModel, .libraries, AsyncStream, KomgaLibrary, Never, Task, Void, MainNavigationTests

### Community 96 - "Library Server User Actions"
Cohesion: 0.18
Nodes (6): DeletionOutcome, String, KomgaLibrary, String, SeriesDeleteManyAction, OfflineRepositories

### Community 97 - "Private Content Settings"
Cohesion: 0.16
Nodes (14): PrivacyLockPolicy, afterTimeout, onLeaving, untilAppQuits, Kind, book, library, series (+6 more)

### Community 98 - "Offline Komga Api Tests"
Cohesion: 0.20
Nodes (4): OfflineKomgaApiTests, GeneratedMedia, CGSize, Data

### Community 99 - "Premium Access Policy"
Cohesion: 0.18
Nodes (10): DownloadManagerConfiguration, SecretsRepository, Storage, PremiumEntitlementStore, SplashDatabase, ThumbnailLoader, AlwaysUnlockedPolicy, .isUnlocked (+2 more)

### Community 100 - "Load State & Reloading"
Cohesion: 0.20
Nodes (11): Duration, listen(), listenHidden(), ReloadScheduler, .isEnabled, KomgaEventSource, MainActor, Never (+3 more)

### Community 101 - "Offline Settings"
Cohesion: 0.18
Nodes (11): FetchableRecord, PersistableRecord, SettingsStore, GRDBOfflineSettingsStore, OfflineSettings, OfflineSettingsRow, Bool, DatabaseWriter (+3 more)

### Community 102 - "Privacy State Storage"
Cohesion: 0.18
Nodes (8): CodingKeys, byServer, lockPolicy, lockTimeout, String, Void, PrivacyStoreTests, SplashDatabase

### Community 103 - "GRDBBook Repositories"
Cohesion: 0.13
Nodes (9): GRDBLogJournalRepository, GRDBMediaRepository, Database, .logJournal, .media, OfflineJSON, Encodable, String (+1 more)

### Community 104 - "Page Image Loader"
Cohesion: 0.26
Nodes (8): PageId, .description, PageImageLoader, Data, Int, String, Task, .id

### Community 105 - "Migration Tests"
Cohesion: 0.14
Nodes (10): Database, DatabaseMigrator, Decode failure silently erases the hidden set, GRDBPrivacyStore, Known limit: hidden-id list is plaintext in splash.sqlite (obscurity, not a vault), AppMigrations, .migrator, String (+2 more)

### Community 106 - "Remote Misc Apis"
Cohesion: 0.18
Nodes (3): RemoteUserApi, Bool, KomgaUser

### Community 107 - "Offline Migrations"
Cohesion: 0.16
Nodes (11): OfflineMigrations, .migrator, DatabaseMigrator, Set, String, SplashDatabase, Configuration, DatabaseWriter (+3 more)

### Community 108 - "Fixture Server Offline Tests"
Cohesion: 0.23
Nodes (8): DownloadManagerConfiguration, Duration, Int, URLSessionConfiguration, OfflineModule, FixtureServerOfflineTests, OfflineFixtureServer, Bool

### Community 109 - "Offline Repository Tests"
Cohesion: 0.20
Nodes (6): GRDBOfflineDataStore, DatabaseWriter, Sendable, T, OfflineRepositoryTests, String

### Community 110 - "GRDBSeries Repositories"
Cohesion: 0.18
Nodes (9): .bookMetadataAggregations, .seriesMetadata, GRDBBookMetadataAggregationRepository, GRDBSeriesMetadataRepository, SeriesMetadataChildren, Database, String, OfflineBookMetadataAggregationRepository (+1 more)

### Community 111 - "Model Decoding Tests"
Cohesion: 0.21
Nodes (5): Fixture, Data, String, ModelDecodingTests, String

### Community 112 - "Home Screen Filter"
Cohesion: 0.13
Nodes (15): HomeScreenFilter, booksCustom, booksOnDeck, .id, .isBookFilter, .label, .order, .pageRequest (+7 more)

### Community 113 - "Hidden Downloads Tests"
Cohesion: 0.24
Nodes (7): HiddenDownloadsTests, BookDownload, HiddenContentFilter, KomgaBookId, KomgaLibraryId, KomgaSeriesId, String

### Community 114 - "Support"
Cohesion: 0.23
Nodes (12): ContinuousClock, Error, .isKomgaNotFound, .isKomgaUnauthorized, .isServerUnreachable, Job, State, CheckedContinuation (+4 more)

### Community 115 - "Readium Epub Reader"
Cohesion: 0.20
Nodes (11): Navigator, NavigatorError, Locator, .epubLocation, EpubLocation, locationChanged(), Double, Int (+3 more)

### Community 116 - "PRIVACY FEATURE PROMPT"
Cohesion: 0.14
Nodes (14): Authenticate before checking the purchase, On lock, reset navigator to Home and clear the search query, Long-press gesture beside the "All Libraries" chip, Version-row help page for App Review guideline 2.3.1, "Hide and delete download" action, HideMenuButton, isUnlocked is memory-only so process death re-locks, Known limit: downloaded files of hidden books stay readable on disk (+6 more)

### Community 117 - "Readium"
Cohesion: 0.14
Nodes (14): CodingKeys, context, href, koboSpan, landmarks, locations, metadata, pageList (+6 more)

### Community 118 - "Server"
Cohesion: 0.20
Nodes (12): BuildKeys, name, version, CommitKeys, id, time, KomgaServerInfo, Date (+4 more)

### Community 119 - "Settings Models"
Cohesion: 0.22
Nodes (10): LayoutScaleType, fitHeight, fitWidth, original, screen, SpreadLayout, Bool, CGFloat (+2 more)

### Community 120 - "GRDBServer Repositories"
Cohesion: 0.27
Nodes (7): OfflineLibraryRecord, GRDBLibraryRepository, OfflineLibrary, .id, .name, .seriesCover, KomgaLibrary

### Community 121 - "Offline Task Emitter"
Cohesion: 0.44
Nodes (4): OfflineTaskEmitter, Int, String, TaskEntry

### Community 122 - "Task Processor"
Cohesion: 0.26
Nodes (6): CheckedContinuation, Int, Never, Task, Void, TaskProcessor

### Community 123 - "Hide Menu Action"
Cohesion: 0.18
Nodes (12): HideMenuButton, .body, Bool, KomgaBookId, KomgaLibraryId, KomgaSeriesId, SplashBook, Void (+4 more)

### Community 124 - "Library Screen"
Cohesion: 0.14
Nodes (14): SeriesSortOption, dateAddedAsc, dateAddedDesc, .id, .komgaSort, .label, releaseDateAsc, releaseDateDesc (+6 more)

### Community 125 - "Readium Epub Reader"
Cohesion: 0.17
Nodes (10): DefaultHTTPClient, DefaultHTTPClientDelegate, HTTPRequest, HTTPRequestConvertible, HTTPResult, Publication, KomgaAuthDelegate, PublicationLoader (+2 more)

### Community 126 - "Offline Domain Adapters"
Cohesion: 0.27
Nodes (4): GRDBOfflineTasksRepository, DatabaseWriter, Int, String

### Community 127 - "Pdf Page Extractor"
Cohesion: 0.28
Nodes (7): CachedDocument, PdfPageExtractor, CGPDFDocument, CGPDFPage, Data, Int, URL

### Community 128 - "Epub Reader Model"
Cohesion: 0.22
Nodes (12): EnvironmentValues, EpubReaderModel, EpubReaderPresenting, EpubSource, local, Bool, EpubReaderSettingsRepository, LoadState (+4 more)

### Community 129 - "Test Support"
Cohesion: 0.22
Nodes (9): EventRecorder, .values, AsyncStream, Bool, Duration, Element, Never, Task (+1 more)

### Community 130 - "Reader Tests"
Cohesion: 0.27
Nodes (5): ReaderIntegrationTests, ReaderLogicTests, Int, Set, String

### Community 131 - "Reader Image Tests"
Cohesion: 0.24
Nodes (4): CoreGraphics, CryptoKit, ImageIO, UniformTypeIdentifiers

### Community 132 - "Readium Epub Reader"
Cohesion: 0.26
Nodes (9): DirectionalNavigationAdapter, EPUBNavigatorDelegate, EPUBNavigatorViewController, Coordinator, EPUBNavigatorRepresentable, NavigatorController, Context, UIViewController (+1 more)

### Community 133 - "README"
Cohesion: 0.23
Nodes (12): AppModule, KomgaApi (protocol), F1 — KomgaAPI + RemoteAPI, F3 — persistence (GRDB), One SPM package, one target per Gradle module, Protocol-only dependency direction, KomgaAPI, SplashAppShared (+4 more)

### Community 134 - "App Module"
Cohesion: 0.23
Nodes (7): KomgaEventBroadcaster, KomgaSSESession, LiveEventsController, KomgaEvent, Never, Task, Void

### Community 135 - "PRIVACY FEATURE PROMPT"
Cohesion: 0.23
Nodes (12): Anti-pattern: HiddenContentMode / .onlyHidden inverse filter, Anti-pattern: over-fetching or page-splicing to fix the pagination count, Anti-pattern: a "Private" tab or parallel screen, Entirely client-side; nothing sent to Komga, Server conditions are an optimisation; visible(_:) is the guard, HiddenContentFilter, Hiding inheritance (library → series → book), libraryAllowList returns nil when nothing is excluded (+4 more)

### Community 136 - "Paywall View"
Cohesion: 0.20
Nodes (10): PaywallContext, BenefitRow, .body, PaywallView, .body, .context, .priceBlock, LocalizedStringResource (+2 more)

### Community 137 - "Page"
Cohesion: 0.17
Nodes (12): CodingKeys, content, empty, first, last, number, numberOfElements, pageable (+4 more)

### Community 138 - "Multipart Form"
Cohesion: 0.30
Nodes (7): KomgaHTTPClient, MultipartForm, .contentType, Bool, Data, String, T

### Community 139 - "Book Actions"
Cohesion: 0.32
Nodes (6): BookKomgaImportAction, RemoteData, Date, KomgaBook, KomgaSeries, OfflineImportSource

### Community 140 - "Download Path Builder"
Cohesion: 0.30
Nodes (4): DownloadPathBuilder, String, URL, DownloadPathBuilderTests

### Community 141 - "Login View"
Cohesion: 0.18
Nodes (9): Field, apiKey, password, url, user, LoginView, .body, .form (+1 more)

### Community 142 - "Privacy Test Doubles"
Cohesion: 0.24
Nodes (6): FakeAccessPolicy, FakeDeviceAuthenticator, Bool, MainActor, String, Void

### Community 143 - "Readium Epub Reader"
Cohesion: 0.25
Nodes (8): AnyView, ReadiumShared, .background, ReadiumEpubReaderView, .body, .overlay, Bool, Void

### Community 144 - "Window Size Class"
Cohesion: 0.18
Nodes (8): Comparable, Int, CGFloat, WindowSizeClass, compact, expanded, full, medium

### Community 145 - "README"
Cohesion: 0.20
Nodes (11): F0 — foundations + wire contract, F11 — downloads, Book file download ignores Range, splash-komga compose service, Optional personal library mount, Komga fixture server (fixtures/komga), openapi.json snapshot, Fixture seed data (+3 more)

### Community 146 - "Device Authentication"
Cohesion: 0.24
Nodes (6): LAContext, LAPolicy, LocalAuthentication, LocalDeviceAuthenticator, Bool, String

### Community 147 - "PRIVACY FEATURE PROMPT"
Cohesion: 0.18
Nodes (10): Chokepoint: AppModule.downloadedSeries() (Downloads tab + offline fallback shelf), Chokepoint: BookScreen / OneshotViewModel refuses to render a hidden item, Chokepoint: collection and read-list view models (client-side visible), Chokepoint: LibraryScreen (loadSeriesPage, collections, read lists, item counts, libraries), Chokepoint: SeriesScreen.loadBooks (bookConditions exact, paging stays right), Do not filter: UsersView, AuthenticationActivityView, AnnouncementsView, Filter chokepoints (§4), View models take the filter as a provider, not a snapshot (+2 more)

### Community 148 - "Readium Epub Reader"
Cohesion: 0.24
Nodes (9): ReadiumNavigator, ReadiumStreamer, EpubReaderSettings.ColumnCount, .readium, EpubReaderSettings.FontFamily, .readium, EpubReaderSettings.Theme, .readium (+1 more)

### Community 149 - "Offline Komga Api"
Cohesion: 0.22
Nodes (4): KomgaSSESession, AsyncStream, OfflineSSESession, AsyncStream

### Community 150 - "Search Operator"
Cohesion: 0.18
Nodes (11): StringOp, beginsWith, contains, doesNotBeginWith, doesNotContain, doesNotEndWith, endsWith, isEqualTo (+3 more)

### Community 151 - "Server Sent Event Parser"
Cohesion: 0.35
Nodes (5): ServerSentEvent, ServerSentEventParser, S, String, UInt8

### Community 152 - "Offline Read Progress"
Cohesion: 0.31
Nodes (8): EntryType, debug, error, info, OfflineLogEntry, Date, String, UUID

### Community 153 - "TRADEMARKS"
Cohesion: 0.20
Nodes (10): Deliberate deviations from Komelia, F16 — offline purchase, Repeated author=name,role filter, Lenient Spring Page<T> decoding, Repeatable sort parameter, Komelia, Apache License 2.0, Splash brand features (+2 more)

### Community 154 - "Readium Epub Reader"
Cohesion: 0.24
Nodes (8): Manifest, EpubOpenError, .errorDescription, invalidURL, open, retrieve, ManifestRelativizer, String

### Community 155 - "Remote SSESession"
Cohesion: 0.29
Nodes (7): RemoteSSESession, AsyncStream, Duration, KomgaHTTPClient, Never, Task, Void

### Community 156 - "Book Download"
Cohesion: 0.20
Nodes (8): DownloadEvent, bookDownloadCancelled, bookDownloadCompleted, bookDownloadError, bookDownloadProgress, .bookId, AsyncStream, AsyncStream

### Community 157 - "Offline Fallback View"
Cohesion: 0.31
Nodes (9): DownloadsShelf, OfflineFallbackView, .body, .message, ScreenErrorView, .body, CGFloat, KomgaSeries (+1 more)

### Community 158 - "Offline Record Tests"
Cohesion: 0.31
Nodes (5): OfflineRecordTests, insertBook(), makeBook(), Database, String

### Community 159 - "Login View Model Tests"
Cohesion: 0.31
Nodes (6): FixtureAvailability, Bool, CommonSettingsRepository, String, URL, TestSession

### Community 160 - "CLAUDE"
Cohesion: 0.25
Nodes (9): Komelia god nodes, Graph structural diagnostics, graphify query/path/explain workflow, Komelia Gradle module map, CMake native superbuild, Privacy policy (no data collection), CLAUDE.md project guide, graphify-out knowledge graph (+1 more)

### Community 161 - "Server"
Cohesion: 0.22
Nodes (9): CodingKey, GitKeys, branch, commit, JavaKeys, vendor, version, Keys (+1 more)

### Community 162 - "Readium Epub Reader"
Cohesion: 0.31
Nodes (8): EPUBPreferences, EpubReaderSettings, .readiumPreferences, EpubSettingsSheet, .body, Binding, T, WritableKeyPath

### Community 163 - "App Module"
Cohesion: 0.33
Nodes (5): Mutex, ApiHolder, .current, ServerURLHolder, URL

### Community 164 - "PRIVACY FEATURE PROMPT"
Cohesion: 0.22
Nodes (9): Anti-pattern: a serverUrl stamp on a single flat set, Hidden ids are keyed by server, HiddenContent, Never lock on .inactive, PrivacyLockPolicy, PrivacySettingsView, PrivacyState, PrivateCatalogViewModel (+1 more)

### Community 165 - "Download Views"
Cohesion: 0.28
Nodes (5): DownloadsSettingsView, .body, OfflineUserChoice, KomgaUserId, String

### Community 166 - "Komga Authentication State"
Cohesion: 0.33
Nodes (3): KomgaAuthenticationState, KomgaLibrary, KomgaUser

### Community 167 - "Async Broadcaster"
Cohesion: 0.36
Nodes (4): AsyncBroadcaster, AsyncStream, Element, Void

### Community 168 - "README"
Cohesion: 0.32
Nodes (8): F15 — EPUB, F9 — reader, Adaptive UI, komga-client, Readers (paged, continuous, EPUB, PDF), Readium swift-toolkit, Splash, SplashEpubKit

### Community 169 - "App Module"
Cohesion: 0.46
Nodes (3): KomgaCookiePersistence, SecretsCookiePersistence, String

### Community 170 - "Search Operator"
Cohesion: 0.25
Nodes (8): DateOp, after, before, isInTheLast, isNotInTheLast, isNotNull, isNull, Date

### Community 171 - "Hidden Download Rows"
Cohesion: 0.25
Nodes (6): KomgaLibraryId, KomgaSeriesId, HiddenContentFilter, BookDownload, KomgaLibraryId, KomgaSeriesId

### Community 173 - "GRDBSettings Stores"
Cohesion: 0.33
Nodes (6): CustomStringConvertible, E, Error, String, UnknownEnumValue, .description

### Community 174 - "Task Processor"
Cohesion: 0.52
Nodes (4): PlatformDownloadManager, OfflineTasksRepository, async, TaskHandler

### Community 175 - "Licenses View"
Cohesion: 0.38
Nodes (5): Entry, .id, LicensesView, .body, String

### Community 177 - "PRIVACY FEATURE PROMPT"
Cohesion: 0.40
Nodes (6): Anti-pattern: an app-level PIN when the device has no passcode, Use .deviceOwnerAuthentication with a fresh LAContext per call, DeviceAuthenticating, NSFaceIDUsageDescription in both Debug and Release, Known limit: no device passcode → no feature, LocalDeviceAuthenticator

### Community 178 - "Komga HTTPClient"
Cohesion: 0.47
Nodes (3): Array, Bool, S

### Community 179 - "Komga HTTPClient"
Cohesion: 0.33
Nodes (6): HTTPMethod, delete, get, patch, post, put

### Community 180 - "Home Screen Filter"
Cohesion: 0.33
Nodes (3): KomgaSort, Decoder, Encoder

### Community 181 - "port map"
Cohesion: 0.60
Nodes (5): KomgaEvent, KomgaEventBroadcaster, F7 — SSE + live updates, RemoteSSESession, Live updates via SSE

### Community 182 - "generate library"
Cohesion: 0.60
Nodes (4): cbz(), main(), page(), Path

### Community 183 - "Server"
Cohesion: 0.40
Nodes (5): RootKeys, build, git, java, os

### Community 184 - "Komga Authentication State"
Cohesion: 0.50
Nodes (4): Double, T, TimeoutError, withTimeout()

### Community 185 - "Login View Model"
Cohesion: 0.40
Nodes (5): LoadState, error, loading, success, uninitialized

### Community 187 - "Task Queue Tests"
Cohesion: 0.40
Nodes (5): State, CheckedContinuation, Never, Set, Void

### Community 188 - "wire contract check"
Cohesion: 0.70
Nodes (4): collect(), main(), normalize(), spec_index()

### Community 189 - "port map"
Cohesion: 0.50
Nodes (4): F8 — image engine, ThumbnailLoader, Unknown thumbnail id maps to nil, SplashImage

### Community 190 - "PRIVACY FEATURE PROMPT"
Cohesion: 0.50
Nodes (4): SPLASH_UNLOCK_PREMIUM debug bypass, Premium* naming for the shared one-time purchase, PremiumProduct, Do not change the product id

### Community 191 - "Server"
Cohesion: 0.50
Nodes (4): OSKeys, arch, name, version

### Community 195 - "Login View Model"
Cohesion: 0.67
Nodes (3): Mode, apiKey, credentials

## Ambiguous Edges - Review These
- `CLAUDE.md project guide` → `Splash`  [AMBIGUOUS]
  CLAUDE.md · relation: references
- `PrivacyBlur` → `Known limit: thumbnail cache retains hidden covers`  [AMBIGUOUS]
  PRIVACY_FEATURE_PROMPT.md · relation: conceptually_related_to
- `PrivateCatalogViewModel` → `Anti-pattern: a "Private" tab or parallel screen`  [AMBIGUOUS]
  PRIVACY_FEATURE_PROMPT.md · relation: conceptually_related_to

## Knowledge Gaps
- **613 isolated node(s):** `ReadiumStreamer`, `invalidURL`, `open`, `.errorDescription`, `.readium` (+608 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **43 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `CLAUDE.md project guide` and `Splash`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `PrivacyBlur` and `Known limit: thumbnail cache retains hidden covers`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `PrivateCatalogViewModel` and `Anti-pattern: a "Private" tab or parallel screen`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `KomgaAPI` connect `Module Imports` to `Komga API Surface`, `Epub Reader Model`, `Reader Image Tests`, `Thumbnail Loading`, `App Module`, `Offline Book Models`, `Readium Epub Reader`, `Library Screen & Filtering`, `Reader View Model`, `Home Shelves & Filtering`, `Sync Manager Tests`, `Series Screen`, `Settings Screens`, `Login View Model Tests`, `App Entry Point`, `App Module`, `Komga Authentication State`, `Offline Sync Actions`, `Book & Oneshot Screens`, `Offline Series Records`, `App Module`, `View Model Factory`, `Book Actions`, `Offline Repositories`, `Collection Screens`, `GRDBRead Progress Repository`, `Home Screen Filter`, `Komga Authentication State`, `Search Screen`, `Test Imports`, `Main Navigator`, `Book Content Extractors`, `Task Queue Tests`, `App Root View`, `GRDBServer Repositories`, `Book Download Service`, `Sync Manager`, `Private Content Settings`, `Page Image Loader`?**
  _High betweenness centrality (0.116) - this node is a cross-community bridge._
- **Why does `KomgaBookId` connect `Sync Manager Tests` to `Komga API Surface`, `Offline Data Store`, `Offline Komga APIs`, `Reader Tests`, `Thumbnail Loading`, `Offline Series & Books`, `User & Activity Models`, `Offline Book Models`, `Book Wire Models`, `Server Events`, `Reader View Model`, `Remote Book API`, `Book Download`, `Search & Query Enums`, `Paged Reader`, `Offline Book DTOs`, `Offline Sync Actions`, `Thumbnail Loader Tests`, `Book Actions`, `Offline Repositories`, `Task Processor`, `GRDBRead Progress Repository`, `Offline Records`, `Remote Misc Apis`, `Settings State`, `URLSession Download Manager`, `Task Queue Tests`, `Offline Downloads`, `Main Navigator`, `Task Data`, `Offline Book Api`, `Task Queue Tests`, `Test Support`, `Book Download`, `Identifiers`, `Offline Repository Protocols`, `GRDBBook Repositories`, `Book Download Service`, `Sync Manager`, `GRDBBook Repositories`, `Page Image Loader`, `Offline Repository Tests`, `Support`, `Offline Task Emitter`?**
  _High betweenness centrality (0.091) - this node is a cross-community bridge._
- **Why does `Foundation` connect `Module Imports` to `Komga API Surface`, `Reader Image Pipeline`, `Offline Komga APIs`, `Reader Image Tests`, `Premium Entitlement & Paywall`, `Keychain & Secrets`, `Readium JSON`, `Multipart Form`, `Paged Requests`, `User & Activity Models`, `Settings Models`, `Download Path Builder`, `Offline Book Models`, `Book Wire Models`, `PRIVACY FEATURE PROMPT`, `Device Authentication`, `Offline Komga Api`, `Series Wire Models`, `Server Sent Event Parser`, `XXH3 File Hashing`, `Date & Duration Coding`, `App Entry Point`, `Search Conditions`, `Offline Sync Actions`, `Offline Series Records`, `Sorting`, `Book Actions`, `Offline Repositories`, `Offline Records`, `Home Screen Filter`, `Komga Authentication State`, `Library`, `Test Imports`, `Komga Cookie Store`, `Search Operator`, `Book Content Extractors`, `GRDBServer Repositories`, `Book Download Service`, `Premium Access Policy`, `Load State & Reloading`, `Page Image Loader`, `Server`?**
  _High betweenness centrality (0.061) - this node is a cross-community bridge._
- **What connects `ReadiumStreamer`, `invalidURL`, `open` to the rest of the system?**
  _613 weakly-connected nodes found - possible documentation gaps or missing edges._