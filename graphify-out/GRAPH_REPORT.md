# Graph Report - .  (2026-09-17)

## Corpus Check
- 194 files · ~115,480 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 4204 nodes · 11522 edges · 185 communities (177 shown, 8 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 1066 edges (avg confidence: 0.8)
- Token cost: 66,000 input · 7,158 output

## Community Hubs (Navigation)
- Navigation & Destinations
- Paged API Requests
- Komga API Protocols
- Book API Surface
- Page Rendering
- Purchases & Paywall
- Content Cards
- App Settings Models
- Remote HTTP Client
- Offline GRDB Repositories
- UIKit Reader Views
- Keychain & Secrets
- Server Event Payloads
- Offline Book Models
- Book Content Extraction
- Series Screen
- API Error Types
- Settings Screens
- File Hashing
- Patch Value Encoding
- Remote Book API
- Search Conditions
- Referential Metadata Queries
- Book Wire Models
- Event Payload Models
- Offline Sync Actions
- Library Screen
- Thumbnail Loading
- Search Operators & SQL
- EPUB Reader (Readium)
- KomgaAuthor
- ContinuousReaderModel
- String
- ReaderViewModel
- AppModule
- PrivateCatalogViewModel
- PagedReaderModel
- KomgaReadList
- KomgaLocalDate
- KomgaReadListId
- KomgaUserId
- ViewModelFactory
- OfflineRecord
- KomgaHTTPClient
- BookViewModel
- SeriesCondition
- SettingsState
- GRDBSettingsStores
- URLSessionDownloadManager
- ReaderView
- EpubReaderModel
- OfflineModule
- OfflineReadListApi
- decode()
- ScanInterval
- HiddenContentFilter
- CollectionViewModel
- OfflineController
- Section
- OfflineTestEnvironment
- Key
- NumericNullableOp
- SyncManager
- TaskData
- PrivacyController
- KomgaCookieStore
- R2Locator
- KomgaSort
- CodingKeys
- book()
- KomgaHTTPClient
- Testing
- inMemory()
- OfflineSeriesApi
- SplashApp
- ThumbnailRequest
- KomgaSeriesId
- SplashDatabase
- ReloadScheduler
- Port map (Komelia Kotlin → Splash Swift)
- SplashCore
- OfflineSettingsStateRepository
- KomgaThumbnailId
- GRDBBookDtoRepository
- OfflineBook
- OfflineDataStore
- TaskProcessor
- Komga wire format contract table
- BookDownload
- init()
- OfflineUser
- OfflineTaskRecord
- OfflineSeriesMetadata
- BookDownloadService
- KomgaAuthenticationState
- KomgaIdentifier
- RemoteUserApi
- ApiKeyStore
- PageId
- SearchViewModel
- EPUBNavigatorRepresentable
- KomgaCollectionId
- LiveEventsController
- HiddenContent
- OfflineLibrary
- OfflineMediaServerId
- OfflineSettings
- HomeViewModel
- decode()
- Error
- make()
- CodingKeys
- HomeScreenFilter
- OfflineFileLocator
- OfflineRepositories
- AppRootView
- JSONValue
- ServerSentEventParser
- LayoutScaleType
- OfflineTaskEmitter
- persisted()
- seeded()
- GRDBOfflineTasksRepository
- SeriesSortOption
- EventRecorder
- decodeEnum()
- SplashKit (local SPM package)
- CodingKeys
- uploadThumbnail()
- OfflineSeries
- execute()
- relativePath()
- LoginView
- WindowSizeClass
- Komga fixture server (fixtures/komga)
- webtoonUsesContinuousReaderWithLayout()
- KomgaApi
- StringOp
- OfflineLogEntry
- Splash trademark and brand policy
- makeDecoder()
- RemoteSSESession
- DownloadEvent
- OfflineDownloads
- content()
- insertBook()
- TestSession
- CLAUDE.md project guide
- CoreGraphics
- EpubSettingsSheet
- DeviceAuthenticating
- strings()
- AsyncBroadcaster
- HideMenuButton
- EncodingTests
- bookMetadataMediaAndProgressRoundTrip()
- FakeDeviceAuthenticator
- Splash
- OfflineBookState
- decode()
- ReaderLogicTests
- Direction
- GRDBOfflineDataStore
- SyncReadProgressAction
- downloadedBytes()
- DownloadManagerConfiguration
- setup.sh
- filterQuery()
- append()
- HTTPMethod
- HomeScreenFilter
- PrivacyRevealGesture
- TransitionPage
- httpClient()
- Live updates via SSE
- cbz()
- decode()
- LoadState
- MemoryPersistence
- book()
- State
- wire_contract_check.py
- ReadiumEpubReaderPresenter
- ThumbnailLoader
- PackageDescription

## God Nodes (most connected - your core abstractions)
1. `KomgaBookId` - 269 edges
2. `KomgaAPI` - 173 edges
3. `KomgaLibraryId` - 139 edges
4. `KomgaSeriesId` - 135 edges
5. `KomgaUserId` - 87 edges
6. `KomgaPageRequest` - 87 edges
7. `OfflineDataStore` - 77 edges
8. `KomgaEvent` - 76 edges
9. `Page` - 71 edges
10. `KomgaAPIError` - 60 edges

## Surprising Connections (you probably didn't know these)
- `Komelia Gradle module map` --semantically_similar_to--> `SplashKit (local SPM package)`  [INFERRED] [semantically similar]
  CLAUDE.md → README.md
- `CLAUDE.md project guide` --references--> `Splash`  [AMBIGUOUS]
  CLAUDE.md → README.md
- `Privacy policy (no data collection)` --semantically_similar_to--> `No telemetry`  [INFERRED] [semantically similar]
  CLAUDE.md → README.md
- `Komga fixture server (fixtures/komga)` --semantically_similar_to--> `Komga fixture server`  [INFERRED] [semantically similar]
  fixtures/komga/README.md → README.md
- `Verified: file download ignores Range` --semantically_similar_to--> `Book file download ignores Range`  [INFERRED] [semantically similar]
  fixtures/komga/README.md → docs/wire-format.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **SplashKit target stack in dependency order** — readme_komgaapi, readme_komgaremote, readme_splashcore, readme_splashoffline, readme_splashdb, readme_splashimage, readme_splashui, readme_splashappshared, readme_dependency_direction [EXTRACTED 1.00]
- **Komga API protocol surface (107 operations)** — docs_wire_format_remotebookapi, docs_wire_format_remoteseriesapi, docs_wire_format_remotelibraryapi, docs_wire_format_remotecollectionsapi, docs_wire_format_remotereadlistapi, docs_wire_format_remotereferentialapi, docs_wire_format_remoteuserapi, docs_wire_format_remotesettingsapi, docs_wire_format_remotetaskapi, docs_wire_format_remoteactuatorapi, docs_wire_format_remoteannouncementsapi, docs_wire_format_remotefilesystemapi, docs_wire_format_remotessesession [EXTRACTED 1.00]
- **Offline reading flow: download, verify, serve, sync** — readme_offline_mode, docs_port_map_phase_f10, docs_port_map_phase_f11, docs_port_map_phase_f12, docs_wire_format_no_range_support, readme_splashoffline, readme_splashdb [INFERRED 0.85]

## Communities (185 total, 8 thin omitted)

### Community 0 - "Navigation & Destinations"
Cohesion: 0.04
Nodes (53): Destination, book, collection, downloads, home, .isPrivate, library, oneshot (+45 more)

### Community 1 - "Paged API Requests"
Cohesion: 0.06
Nodes (29): KomgaBookSearch, KomgaPageRequest, .queryItems, Page, Pageable, Sort, Bool, Decoder (+21 more)

### Community 2 - "Komga API Protocols"
Cohesion: 0.04
Nodes (47): KomgaSSESession, KomgaActuatorApi, KomgaAnnouncementsApi, KomgaCollectionsApi, KomgaFileSystemApi, KomgaLibraryApi, KomgaReadListApi, KomgaReferentialApi (+39 more)

### Community 3 - "Book API Surface"
Cohesion: 0.06
Nodes (18): KomgaBookId, CountingBookApi, .calls, Bool, Data, Int, KomgaBookPage, KomgaBookThumbnail (+10 more)

### Community 4 - "Page Rendering"
Cohesion: 0.06
Nodes (37): PageRenderer, PDFPageRenderer, RasterPageRenderer, Bool, CGFloat, CGImage, CGImageSource, CGPDFDocument (+29 more)

### Community 5 - "Purchases & Paywall"
Cohesion: 0.05
Nodes (39): LocalizedError, Product, StoreKit, Benefit, .body, PaywallView, .body, .priceBlock (+31 more)

### Community 6 - "Content Cards"
Cohesion: 0.05
Nodes (53): Card, Footer, Overlay, BookCard, .body, .progressBar, CardGrid, .body (+45 more)

### Community 7 - "App Settings Models"
Cohesion: 0.04
Nodes (58): CaseIterable, AppTheme, dark, darker, light, BooksLayout, grid, list (+50 more)

### Community 8 - "Remote HTTP Client"
Cohesion: 0.08
Nodes (5): Foundation, GRDB, KomgaAPI, SplashOffline, Synchronization

### Community 9 - "Offline GRDB Repositories"
Cohesion: 0.06
Nodes (34): GRDBBookMetadataRepository, GRDBLogJournalRepository, GRDBMediaRepository, Database, GRDBOfflineRepositories, .bookMetadata, .books, .logJournal (+26 more)

### Community 10 - "UIKit Reader Views"
Cohesion: 0.10
Nodes (24): CGPoint, Equatable, NSCoder, Configuration, ContinuousStripView, Coordinator, PagedSpreadView, SpreadScrollView (+16 more)

### Community 11 - "Keychain & Secrets"
Cohesion: 0.09
Nodes (21): Security, ServerURL, InMemorySecretsRepository, KeychainClient, KeychainError, status, KeychainSecretsRepository, Kind (+13 more)

### Community 12 - "Server Event Payloads"
Cohesion: 0.05
Nodes (36): KomgaEvent, bookAdded, bookChanged, bookDeleted, bookImported, collectionAdded, collectionChanged, collectionDeleted (+28 more)

### Community 13 - "Offline Book Models"
Cohesion: 0.08
Nodes (29): GRDBThumbnailBookRepository, .bookThumbnails, CodingKeys, type, EpubTocEntry, KomgaBook, KomgaBookPage, KomgaBookThumbnail (+21 more)

### Community 14 - "Book Content Extraction"
Cohesion: 0.09
Nodes (27): Archive, ReadiumZIPFoundation, KomgaBookPage, BookContentExtractors, CachedArchive, DataBuffer, DivinaExtractor, EpubExtractor (+19 more)

### Community 15 - "Series Screen"
Cohesion: 0.09
Nodes (30): BooksSortOption, .id, numberAsc, numberDesc, ChipRow, .body, SeriesHeader, .body (+22 more)

### Community 16 - "API Error Types"
Cohesion: 0.06
Nodes (20): R2Positions, KomgaAPIError, decoding, httpStatus, invalidResponse, .isNotFound, .isUnauthorized, .statusCode (+12 more)

### Community 17 - "Settings Screens"
Cohesion: 0.07
Nodes (37): ColorScheme, KomgaUserSort, AboutView, .didReveal, .remainingTaps, .showsCounter, AccountSettingsView, .body (+29 more)

### Community 18 - "File Hashing"
Cohesion: 0.15
Nodes (16): FileHasher, Hash128, Data, Int, String, UInt8, URL, XXH3 (+8 more)

### Community 19 - "Patch Value Encoding"
Cohesion: 0.09
Nodes (31): KeyedEncodingContainer, PatchValue, .isUnset, none, some, unset, Bool, Encoder (+23 more)

### Community 20 - "Remote Book API"
Cohesion: 0.08
Nodes (11): RemoteBookApi, Bool, Data, Int, KomgaBook, KomgaBookPage, KomgaBookThumbnail, KomgaHTTPClient (+3 more)

### Community 21 - "Search Conditions"
Cohesion: 0.06
Nodes (36): SearchValue, AuthorMatch, BookCondition, allOf, anyOf, author, deleted, libraryId (+28 more)

### Community 22 - "Referential Metadata Queries"
Cohesion: 0.13
Nodes (10): KomgaLibraryId, GRDBReferentialRepository, GRDBSeriesDtoRepository, Database, Int, KomgaSeries, SQL, String (+2 more)

### Community 23 - "Book Wire Models"
Cohesion: 0.13
Nodes (31): Identifiable, KomgaBook, KomgaBookMetadata, KomgaBookMetadataUpdateRequest, KomgaBookPage, KomgaBookReadProgressUpdateRequest, KomgaBookThumbnail, KomgaMediaStatus (+23 more)

### Community 24 - "Event Payload Models"
Cohesion: 0.13
Nodes (39): Codable, Hashable, Sendable, CopyMode, copy, hardlink, move, BookImportedPayload (+31 more)

### Community 25 - "Offline Sync Actions"
Cohesion: 0.14
Nodes (25): BookDeleteAction, BookDeleteManyAction, BookMarkRemoteDeletedAction, OfflineActionEnvironment, .isOffline, Bool, LibraryDeleteAction, LibraryKomgaImportAction (+17 more)

### Community 26 - "Library Screen"
Cohesion: 0.10
Nodes (25): LibraryScreen, .body, .libraryPicker, .seriesTab, LibraryViewModel, .cardWidth, .libraries, .scopedLibraryIds (+17 more)

### Community 27 - "Thumbnail Loading"
Cohesion: 0.10
Nodes (21): NSString, .offlineApi, CGImageBox, Configuration, .`default`, DecodedImage, .pixelSize, MemoryKey (+13 more)

### Community 28 - "Search Operators & SQL"
Cohesion: 0.14
Nodes (16): EqualityOp, isEqualTo, isNotEqualTo, BookSearchHelper, SeriesSearchHelper, SQL, SearchSQL, Bool (+8 more)

### Community 29 - "EPUB Reader (Readium)"
Cohesion: 0.09
Nodes (28): DefaultHTTPClientDelegate, Manifest, Publication, ReadiumNavigator, ReadiumShared, ReadiumStreamer, EpubOpenError, .errorDescription (+20 more)

### Community 30 - "KomgaAuthor"
Cohesion: 0.14
Nodes (25): KomgaAlternativeTitle, KomgaAuthor, KomgaReadingDirection, leftToRight, rightToLeft, vertical, webtoon, KomgaSeries (+17 more)

### Community 31 - "ContinuousReaderModel"
Cohesion: 0.11
Nodes (18): Range, ContinuousReaderModel, .isVertical, .pages, Bool, CGFloat, Int, Never (+10 more)

### Community 32 - "String"
Cohesion: 0.13
Nodes (14): String, LoginSession, LoginViewModel, Mode, apiKey, credentials, MainActor, Never (+6 more)

### Community 33 - "ReaderViewModel"
Cohesion: 0.10
Nodes (19): ReaderType, continuous, paged, panels, BookSiblingsContext, readList, series, ReaderBooksState (+11 more)

### Community 34 - "AppModule"
Cohesion: 0.11
Nodes (20): AnyObject, ApiHolder, .current, AppModule, .api, ServerURLHolder, Storage, CommonSettingsRepository (+12 more)

### Community 35 - "PrivateCatalogViewModel"
Cohesion: 0.09
Nodes (26): ID, PrivateCatalogViewModel, .isEmpty, PrivateHomeScreen, .body, PrivateSearchScreen, .body, .matchedBooks (+18 more)

### Community 36 - "PagedReaderModel"
Cohesion: 0.14
Nodes (18): Index, Collection, LoadedPage, .id, PagedReaderModel, .currentPageNumber, .pageCount, Bool (+10 more)

### Community 37 - "KomgaReadList"
Cohesion: 0.13
Nodes (19): KomgaReadStatus, inProgress, read, unread, KomgaCollection, KomgaCollectionCreateRequest, KomgaCollectionQuery, KomgaCollectionThumbnail (+11 more)

### Community 38 - "KomgaLocalDate"
Cohesion: 0.10
Nodes (18): KomgaDuration, .isoString, KomgaInstant, KomgaJSON, KomgaLocalDate, .description, LenientEnum, Date (+10 more)

### Community 39 - "KomgaReadListId"
Cohesion: 0.12
Nodes (9): KomgaReadListId, OfflineBookStateProvider, RemoteCollectionsApi, RemoteReadListApi, Bool, Data, KomgaHTTPClient, SplashBook (+1 more)

### Community 40 - "KomgaUserId"
Cohesion: 0.13
Nodes (13): KomgaUserId, .readProgress, GRDBReadProgressRepository, Database, Date, SQL, Int, OfflineReadProgress (+5 more)

### Community 41 - "ViewModelFactory"
Cohesion: 0.12
Nodes (21): HiddenContentMode, excludeHidden, onlyHidden, AsyncStream, CommonSettingsRepository, HiddenContentRepository, HomeScreenFilterRepository, ImageReaderSettingsRepository (+13 more)

### Community 42 - "OfflineRecord"
Cohesion: 0.20
Nodes (21): DatabaseColumnDecodingStrategy, DatabaseColumnEncodingStrategy, OfflineBookMetadataRecord, OfflineBookRecord, OfflineMediaPageRecord, OfflineMediaRecord, OfflineReadProgressRecord, OfflineRecord (+13 more)

### Community 43 - "KomgaHTTPClient"
Cohesion: 0.08
Nodes (9): RemoteActuatorApi, RemoteAnnouncementsApi, RemoteFileSystemApi, RemoteLibraryApi, RemoteSettingsApi, RemoteTaskApi, Int, KomgaHTTPClient (+1 more)

### Community 44 - "BookViewModel"
Cohesion: 0.13
Nodes (22): BookDownloadButton, SplashBook, BookDetails, .body, .progressLabel, .readButtonTitle, BookScreen, .body (+14 more)

### Community 45 - "SeriesCondition"
Cohesion: 0.07
Nodes (24): SeriesCondition, ageRating, allOf, anyOf, author, collectionId, complete, deleted (+16 more)

### Community 46 - "SettingsState"
Cohesion: 0.12
Nodes (17): escaping, AsyncSerialLock, InMemorySettingsStore, SettingsState, .value, async, AsyncStream, KeyPath (+9 more)

### Community 47 - "GRDBSettingsStores"
Cohesion: 0.13
Nodes (13): FetchableRecord, PersistableRecord, SettingsStore, AppSettingsRow, GRDBAppSettingsStore, GRDBEpubReaderSettingsStore, GRDBHiddenContentStore, GRDBHomeScreenFilterStore (+5 more)

### Community 48 - "URLSessionDownloadManager"
Cohesion: 0.13
Nodes (11): OperationQueue, RequestProvider, Bool, Int64, String, URLSession, TaskInfo, URLSessionDownloadManager (+3 more)

### Community 49 - "ReaderView"
Cohesion: 0.12
Nodes (17): PreferenceKey, .body, ContinuousStripViewStep, ReaderView, .body, .closeButton, .content, .currentPage (+9 more)

### Community 50 - "EpubReaderModel"
Cohesion: 0.13
Nodes (23): Locator, .epubLocation, EnvironmentValues, EpubLocation, EpubReaderModel, EpubReaderPresenting, EpubSource, local (+15 more)

### Community 51 - "OfflineModule"
Cohesion: 0.10
Nodes (8): URL, .get, KomgaSeries, SplashBook, OfflineModule, FixtureServerOfflineTests, OfflineFixtureServer, Bool

### Community 52 - "OfflineReadListApi"
Cohesion: 0.12
Nodes (5): OfflineCollectionsApi, OfflineReadListApi, Bool, Data, SplashBook

### Community 53 - "decode()"
Cohesion: 0.15
Nodes (17): CodingKey, DecodingError, KeyedDecodingContainer, Decoder, BooleanOp, isFalse, isTrue, decodeOperatorName() (+9 more)

### Community 54 - "ScanInterval"
Cohesion: 0.13
Nodes (21): Encodable, DirectoryListing, DirectoryPath, DirectoryRequest, KomgaLibrary, KomgaLibraryCreateRequest, KomgaLibraryUpdateRequest, ScanInterval (+13 more)

### Community 55 - "HiddenContentFilter"
Cohesion: 0.17
Nodes (9): HiddenContentFilter, .isNoop, Bool, Int, KomgaLibrary, KomgaSeries, SplashBook, T (+1 more)

### Community 56 - "CollectionViewModel"
Cohesion: 0.15
Nodes (21): PaginationBar, .body, CollectionScreen, .body, CollectionViewModel, .cardWidth, ReadListScreen, .body (+13 more)

### Community 57 - "OfflineController"
Cohesion: 0.12
Nodes (16): .body, DownloadRow, .body, .progressText, EnvironmentValues, String, OfflineController, .isOfflineMode (+8 more)

### Community 58 - "Section"
Cohesion: 0.09
Nodes (22): PrivacyHelpView, .body, Step, .body, Int, LocalizedStringKey, Section, books (+14 more)

### Community 59 - "OfflineTestEnvironment"
Cohesion: 0.18
Nodes (11): KomgaEventBroadcaster, AsyncStream, OfflineKomgaApi, FakeDownloadManager, .cancelled, .launched, Bool, TaskQueueTests (+3 more)

### Community 60 - "Key"
Cohesion: 0.08
Nodes (26): Key, ageRating, allOf, anyOf, author, collectionId, complete, deleted (+18 more)

### Community 61 - "NumericNullableOp"
Cohesion: 0.10
Nodes (19): EqualityNullableOp, isEqualTo, isNotEqualTo, isNotNull, isNull, NumericNullableOp, greaterThan, isEqualTo (+11 more)

### Community 62 - "SyncManager"
Cohesion: 0.19
Nodes (11): Result, Bool, KomgaUser, Never, Task, TimeInterval, SyncManager, .settings (+3 more)

### Community 63 - "TaskData"
Cohesion: 0.08
Nodes (23): CodingKeys, bookId, file, libraryId, seriesId, type, Status, new (+15 more)

### Community 64 - "PrivacyController"
Cohesion: 0.12
Nodes (17): EnvironmentValues, PrivacyController, .lockPolicy, .lockTimeout, Bool, CommonSettingsRepository, Date, HiddenContentRepository (+9 more)

### Community 65 - "KomgaCookieStore"
Cohesion: 0.17
Nodes (11): HTTPCookie, KomgaCookiePersistence, KomgaCookieStore, .hasRememberMe, Bool, HTTPURLResponse, String, URL (+3 more)

### Community 66 - "R2Locator"
Cohesion: 0.19
Nodes (18): R2Device, R2Location, R2Locator, R2LocatorText, R2Progression, Date, Float, Int (+10 more)

### Community 67 - "KomgaSort"
Cohesion: 0.15
Nodes (6): KomgaBooksSort, KomgaSeriesSort, KomgaSort, .defaults, .komgaSort, .komgaSort

### Community 68 - "CodingKeys"
Cohesion: 0.09
Nodes (23): CodingKeys, ageRestriction, author, configurationSource, contentHtml, databaseSource, dateModified, description (+15 more)

### Community 69 - "book()"
Cohesion: 0.13
Nodes (14): Fixtures, GeneratedMedia, StubImportSource, CGSize, Data, Date, Int, KomgaBook (+6 more)

### Community 70 - "KomgaHTTPClient"
Cohesion: 0.17
Nodes (12): Body, KomgaHTTPClient, .currentBaseURL, Data, HTTPURLResponse, JSONEncoder, T, URL (+4 more)

### Community 71 - "Testing"
Cohesion: 0.14
Nodes (4): KomgaRemote, SplashDB, SplashUI, Testing

### Community 72 - "inMemory()"
Cohesion: 0.16
Nodes (7): AppSettings, SettingsStateTests, MigrationTests, Database, Set, String, SettingsStoreTests

### Community 73 - "OfflineSeriesApi"
Cohesion: 0.12
Nodes (7): OfflineSeriesApi, .userId, Bool, Data, KomgaSeries, KomgaSeriesThumbnail, String

### Community 74 - "SplashApp"
Cohesion: 0.13
Nodes (18): App, NSObject, Scene, SplashAppShared, SplashEpubKit, AppBootstrap, AppDelegate, BootstrapView (+10 more)

### Community 75 - "ThumbnailRequest"
Cohesion: 0.12
Nodes (19): ContentMode, Data, Int, ThumbnailRequest, book, bookDefault, bookPage, .cacheKey (+11 more)

### Community 76 - "KomgaSeriesId"
Cohesion: 0.15
Nodes (6): KomgaSeriesId, RemoteSeriesApi, Data, KomgaHTTPClient, KomgaSeriesThumbnail, String

### Community 77 - "SplashDatabase"
Cohesion: 0.12
Nodes (16): AppMigrations, .migrator, DatabaseMigrator, Set, String, OfflineMigrations, .migrator, DatabaseMigrator (+8 more)

### Community 78 - "ReloadScheduler"
Cohesion: 0.11
Nodes (18): listen(), LoadState, error, .isLoading, .isUninitialized, loading, success, uninitialized (+10 more)

### Community 79 - "Port map (Komelia Kotlin → Splash Swift)"
Cohesion: 0.11
Nodes (22): ApiKeyStore, Search condition helpers, KomgaHTTPClient, KomgaSort, OfflineBookStateProvider, PatchValue, F10 — offline API, F12 — sync (+14 more)

### Community 80 - "SplashCore"
Cohesion: 0.20
Nodes (4): Observation, SplashCore, SplashImage, SwiftUI

### Community 81 - "OfflineSettingsStateRepository"
Cohesion: 0.13
Nodes (12): SettingsState, OfflineSettingsStateRepository, .dataSyncDate, .downloadDirectory, .isOfflineModeEnabled, .readProgressSyncDate, .serverId, .userId (+4 more)

### Community 82 - "KomgaThumbnailId"
Cohesion: 0.17
Nodes (12): KomgaThumbnailId, .seriesThumbnails, GRDBThumbnailSeriesRepository, OfflineThumbnailSeries, Bool, Data, Int, Int64 (+4 more)

### Community 83 - "GRDBBookDtoRepository"
Cohesion: 0.20
Nodes (9): GRDBBookDtoRepository, Bool, Database, SplashBook, SQL, String, .bookDtos, OfflineBookDtoRepository (+1 more)

### Community 84 - "OfflineBook"
Cohesion: 0.15
Nodes (4): GRDBBookRepository, OfflineBook, OfflineBookRepository, Bool

### Community 85 - "OfflineDataStore"
Cohesion: 0.23
Nodes (4): DatabaseOfflineBookStateProvider, OfflineReferentialApi, String, OfflineDataStore

### Community 86 - "TaskProcessor"
Cohesion: 0.20
Nodes (10): PlatformDownloadManager, OfflineTasksRepository, async, CheckedContinuation, Int, Never, Task, Void (+2 more)

### Community 87 - "Komga wire format contract table"
Cohesion: 0.19
Nodes (20): KomgaCookieStore, Komga wire format contract table, Cookie session login, EPUB read-progress restriction, Genres returned lowercased, RemoteActuatorApi, RemoteAnnouncementsApi, RemoteBookApi (+12 more)

### Community 88 - "BookDownload"
Cohesion: 0.14
Nodes (14): GRDBBookDownloadRepository, .downloads, Row, BookDownload, .fractionCompleted, .id, Status, complete (+6 more)

### Community 89 - "init()"
Cohesion: 0.12
Nodes (5): OfflineUserApi, KomgaUser, Bool, URL, OfflineSettingsRepository

### Community 90 - "OfflineUser"
Cohesion: 0.18
Nodes (9): roles, OfflineUserRecord, .libraries, GRDBUserRepository, KomgaUser, OfflineUser, Bool, KomgaUser (+1 more)

### Community 91 - "OfflineTaskRecord"
Cohesion: 0.20
Nodes (10): OfflineTaskRecord, Status, new, running, OfflineTaskQueue, Bool, DatabaseWriter, Int (+2 more)

### Community 92 - "OfflineSeriesMetadata"
Cohesion: 0.16
Nodes (10): .bookMetadataAggregations, .seriesMetadata, GRDBBookMetadataAggregationRepository, GRDBSeriesMetadataRepository, SeriesMetadataChildren, Database, String, OfflineSeriesMetadata (+2 more)

### Community 93 - "BookDownloadService"
Cohesion: 0.18
Nodes (12): BookDownloadService, .fileLocator, OfflineRemoteContext, PreparedDownload, Bool, KomgaBook, KomgaLibrary, KomgaSeries (+4 more)

### Community 94 - "KomgaAuthenticationState"
Cohesion: 0.15
Nodes (13): DataState, authenticationRequired, loaded, KomgaAuthenticationState, Double, KomgaLibrary, KomgaUser, T (+5 more)

### Community 95 - "KomgaIdentifier"
Cohesion: 0.15
Nodes (7): ExpressibleByStringLiteral, RawRepresentable, KomgaAnnouncementId, KomgaIdentifier, .description, .value, String

### Community 96 - "RemoteUserApi"
Cohesion: 0.17
Nodes (4): KomgaUserApi, RemoteUserApi, Bool, KomgaUser

### Community 97 - "ApiKeyStore"
Cohesion: 0.25
Nodes (6): SecretsCookiePersistence, String, ApiKeyStore, .apiKey, String, SecretsRepository

### Community 98 - "PageId"
Cohesion: 0.26
Nodes (8): PageId, .description, PageImageLoader, Data, Int, String, Task, .id

### Community 99 - "SearchViewModel"
Cohesion: 0.16
Nodes (15): SearchScreen, .body, SearchViewModel, CGFloat, KomgaSeries, LoadState, MainActor, Never (+7 more)

### Community 100 - "EPUBNavigatorRepresentable"
Cohesion: 0.18
Nodes (12): DirectionalNavigationAdapter, EPUBNavigatorDelegate, EPUBNavigatorViewController, Navigator, NavigatorError, Coordinator, EPUBNavigatorRepresentable, NavigatorController (+4 more)

### Community 101 - "KomgaCollectionId"
Cohesion: 0.36
Nodes (3): KomgaCollectionId, RemoteReferentialApi, String

### Community 102 - "LiveEventsController"
Cohesion: 0.15
Nodes (8): LiveEventsController, RemoteBox, .api, Bool, Never, Task, Void, String

### Community 103 - "HiddenContent"
Cohesion: 0.16
Nodes (10): HiddenContent, .isEmpty, PrivacyLockPolicy, afterTimeout, onLeaving, untilAppQuits, Bool, Set (+2 more)

### Community 104 - "OfflineLibrary"
Cohesion: 0.23
Nodes (8): OfflineLibraryRecord, GRDBLibraryRepository, KomgaLibrary, OfflineLibrary, .id, .name, .seriesCover, KomgaLibrary

### Community 105 - "OfflineMediaServerId"
Cohesion: 0.27
Nodes (5): OfflineMediaServerRecord, GRDBMediaServerRepository, OfflineMediaServer, OfflineMediaServerId, String

### Community 106 - "OfflineSettings"
Cohesion: 0.21
Nodes (8): GRDBOfflineSettingsStore, OfflineSettings, OfflineSettingsRow, Bool, DatabaseWriter, Date, PersistenceContainer, String

### Community 107 - "HomeViewModel"
Cohesion: 0.23
Nodes (10): .body, HomeViewModel, AsyncStream, HomeScreenFilterRepository, KomgaEventSource, KomgaLibrary, LoadState, MainActor (+2 more)

### Community 108 - "decode()"
Cohesion: 0.21
Nodes (5): Fixture, Data, String, ModelDecodingTests, String

### Community 109 - "Error"
Cohesion: 0.21
Nodes (12): ContinuousClock, Error, .isKomgaNotFound, .isKomgaUnauthorized, .isServerUnreachable, Job, State, CheckedContinuation (+4 more)

### Community 110 - "make()"
Cohesion: 0.30
Nodes (3): ScenePhase, PrivacyControllerTests, MainActor

### Community 111 - "CodingKeys"
Cohesion: 0.13
Nodes (15): CodingKeys, context, href, koboSpan, landmarks, links, locations, metadata (+7 more)

### Community 112 - "HomeScreenFilter"
Cohesion: 0.13
Nodes (15): HomeScreenFilter, booksCustom, booksOnDeck, .id, .isBookFilter, .label, .order, .pageRequest (+7 more)

### Community 113 - "OfflineFileLocator"
Cohesion: 0.22
Nodes (8): BookDeleteFilesAction, Bool, String, URL, URL, OfflineFileLocator, String, URL

### Community 114 - "OfflineRepositories"
Cohesion: 0.25
Nodes (4): DeletionOutcome, String, KomgaLibrary, OfflineRepositories

### Community 115 - "AppRootView"
Cohesion: 0.24
Nodes (8): AppRootView, .body, .privacyBlurActive, AppSession, Bool, SplashBook, PrivacyBlur, .body

### Community 116 - "JSONValue"
Cohesion: 0.14
Nodes (11): JSONValue, array, bool, null, number, object, string, Bool (+3 more)

### Community 117 - "ServerSentEventParser"
Cohesion: 0.24
Nodes (6): ServerSentEvent, ServerSentEventParser, S, String, UInt8, UnitTests

### Community 118 - "LayoutScaleType"
Cohesion: 0.22
Nodes (10): LayoutScaleType, fitHeight, fitWidth, original, screen, SpreadLayout, Bool, CGFloat (+2 more)

### Community 119 - "OfflineTaskEmitter"
Cohesion: 0.44
Nodes (4): OfflineTaskEmitter, Int, String, TaskEntry

### Community 120 - "persisted()"
Cohesion: 0.23
Nodes (11): .value, AppearanceSettingsView, .body, SeriesCardPreview, .body, Binding, CGFloat, CommonSettingsRepository (+3 more)

### Community 122 - "GRDBOfflineTasksRepository"
Cohesion: 0.27
Nodes (4): GRDBOfflineTasksRepository, DatabaseWriter, Int, String

### Community 123 - "SeriesSortOption"
Cohesion: 0.15
Nodes (13): SeriesSortOption, dateAddedAsc, dateAddedDesc, .id, .label, releaseDateAsc, releaseDateDesc, titleAsc (+5 more)

### Community 124 - "EventRecorder"
Cohesion: 0.22
Nodes (9): EventRecorder, .values, AsyncStream, Bool, Duration, Element, Never, Task (+1 more)

### Community 125 - "decodeEnum()"
Cohesion: 0.18
Nodes (9): CustomStringConvertible, E, String, UnknownEnumValue, .description, ReaderImageError, .description, undecodable (+1 more)

### Community 126 - "SplashKit (local SPM package)"
Cohesion: 0.23
Nodes (12): AppModule, KomgaApi (protocol), F1 — KomgaAPI + RemoteAPI, F3 — persistence (GRDB), One SPM package, one target per Gradle module, Protocol-only dependency direction, KomgaAPI, SplashAppShared (+4 more)

### Community 127 - "CodingKeys"
Cohesion: 0.17
Nodes (12): CodingKeys, content, empty, first, last, number, numberOfElements, pageable (+4 more)

### Community 128 - "uploadThumbnail()"
Cohesion: 0.30
Nodes (7): KomgaHTTPClient, MultipartForm, .contentType, Bool, Data, String, T

### Community 129 - "OfflineSeries"
Cohesion: 0.23
Nodes (4): GRDBSeriesRepository, KomgaSeries, KomgaSeriesThumbnail, OfflineSeries

### Community 130 - "execute()"
Cohesion: 0.32
Nodes (6): BookKomgaImportAction, RemoteData, Date, KomgaBook, KomgaSeries, OfflineImportSource

### Community 131 - "relativePath()"
Cohesion: 0.30
Nodes (4): DownloadPathBuilder, String, URL, DownloadPathBuilderTests

### Community 132 - "LoginView"
Cohesion: 0.18
Nodes (9): Field, apiKey, password, url, user, LoginView, .body, .form (+1 more)

### Community 133 - "WindowSizeClass"
Cohesion: 0.18
Nodes (8): Comparable, Int, CGFloat, WindowSizeClass, compact, expanded, full, medium

### Community 134 - "Komga fixture server (fixtures/komga)"
Cohesion: 0.20
Nodes (11): F0 — foundations + wire contract, F11 — downloads, Book file download ignores Range, splash-komga compose service, Optional personal library mount, Komga fixture server (fixtures/komga), openapi.json snapshot, Fixture seed data (+3 more)

### Community 135 - "webtoonUsesContinuousReaderWithLayout()"
Cohesion: 0.25
Nodes (5): images, CGRect, CGSize, ReaderIntegrationTests, String

### Community 136 - "KomgaApi"
Cohesion: 0.27
Nodes (3): KomgaApi, RemoteImportSource, KomgaBookPage

### Community 137 - "StringOp"
Cohesion: 0.18
Nodes (11): StringOp, beginsWith, contains, doesNotBeginWith, doesNotContain, doesNotEndWith, endsWith, isEqualTo (+3 more)

### Community 138 - "OfflineLogEntry"
Cohesion: 0.31
Nodes (8): EntryType, debug, error, info, OfflineLogEntry, Date, String, UUID

### Community 139 - "Splash trademark and brand policy"
Cohesion: 0.20
Nodes (10): Deliberate deviations from Komelia, F16 — offline purchase, Repeated author=name,role filter, Lenient Spring Page<T> decoding, Repeatable sort parameter, Komelia, Apache License 2.0, Splash brand features (+2 more)

### Community 140 - "makeDecoder()"
Cohesion: 0.22
Nodes (5): .errorResponse, JSONDecoderHelper, String, JSONDecoder, .komga

### Community 141 - "RemoteSSESession"
Cohesion: 0.29
Nodes (7): RemoteSSESession, AsyncStream, Duration, KomgaHTTPClient, Never, Task, Void

### Community 142 - "DownloadEvent"
Cohesion: 0.20
Nodes (8): DownloadEvent, bookDownloadCancelled, bookDownloadCompleted, bookDownloadError, bookDownloadProgress, .bookId, AsyncStream, AsyncStream

### Community 144 - "content()"
Cohesion: 0.22
Nodes (4): DownloadsSettingsView, .body, OfflineBanner, .body

### Community 145 - "insertBook()"
Cohesion: 0.31
Nodes (5): OfflineRecordTests, insertBook(), makeBook(), Database, String

### Community 146 - "TestSession"
Cohesion: 0.31
Nodes (6): FixtureAvailability, Bool, CommonSettingsRepository, String, URL, TestSession

### Community 147 - "CLAUDE.md project guide"
Cohesion: 0.25
Nodes (9): Komelia god nodes, Graph structural diagnostics, graphify query/path/explain workflow, Komelia Gradle module map, CMake native superbuild, Privacy policy (no data collection), CLAUDE.md project guide, graphify-out knowledge graph (+1 more)

### Community 148 - "CoreGraphics"
Cohesion: 0.36
Nodes (4): CoreGraphics, CryptoKit, ImageIO, UniformTypeIdentifiers

### Community 149 - "EpubSettingsSheet"
Cohesion: 0.31
Nodes (8): EPUBPreferences, EpubReaderSettings, .readiumPreferences, EpubSettingsSheet, .body, Binding, T, WritableKeyPath

### Community 150 - "DeviceAuthenticating"
Cohesion: 0.28
Nodes (5): LocalAuthentication, DeviceAuthenticating, LocalDeviceAuthenticator, Bool, String

### Community 151 - "strings()"
Cohesion: 0.36
Nodes (6): BookMetadataChildren, String, GroupedRows, Database, SQL, String

### Community 152 - "AsyncBroadcaster"
Cohesion: 0.36
Nodes (4): AsyncBroadcaster, AsyncStream, Element, Void

### Community 153 - "HideMenuButton"
Cohesion: 0.33
Nodes (7): HideMenuButton, .body, Bool, Target, book, library, series

### Community 154 - "EncodingTests"
Cohesion: 0.33
Nodes (3): EncodingTests, encodedJSON(), T

### Community 156 - "FakeDeviceAuthenticator"
Cohesion: 0.39
Nodes (4): FakeAccessPolicy, FakeDeviceAuthenticator, Bool, String

### Community 157 - "Splash"
Cohesion: 0.32
Nodes (8): F15 — EPUB, F9 — reader, Adaptive UI, komga-client, Readers (paged, continuous, EPUB, PDF), Readium swift-toolkit, Splash, SplashEpubKit

### Community 158 - "OfflineBookState"
Cohesion: 0.32
Nodes (5): OfflineBookState, SplashBook, Bool, Date, KomgaBook

### Community 159 - "decode()"
Cohesion: 0.32
Nodes (5): Encodable, Sendable, String, T, WireValues

### Community 160 - "ReaderLogicTests"
Cohesion: 0.50
Nodes (3): ReaderLogicTests, Int, Set

### Community 161 - "Direction"
Cohesion: 0.38
Nodes (4): Direction, asc, desc, Order

### Community 162 - "GRDBOfflineDataStore"
Cohesion: 0.43
Nodes (4): GRDBOfflineDataStore, DatabaseWriter, Sendable, T

### Community 163 - "SyncReadProgressAction"
Cohesion: 0.43
Nodes (3): Bool, KomgaUser, SyncReadProgressAction

### Community 165 - "DownloadManagerConfiguration"
Cohesion: 0.52
Nodes (4): DownloadManagerConfiguration, Duration, Int, URLSessionConfiguration

### Community 167 - "filterQuery()"
Cohesion: 0.53
Nodes (3): Bool, KomgaSeries, URLQueryItem

### Community 168 - "append()"
Cohesion: 0.47
Nodes (3): Array, Bool, S

### Community 169 - "HTTPMethod"
Cohesion: 0.33
Nodes (6): HTTPMethod, delete, get, patch, post, put

### Community 170 - "HomeScreenFilter"
Cohesion: 0.33
Nodes (3): KomgaSort, Decoder, Encoder

### Community 171 - "PrivacyRevealGesture"
Cohesion: 0.33
Nodes (4): PrivacyRevealGesture, Content, .libraryPickerRow, ViewModifier

### Community 172 - "TransitionPage"
Cohesion: 0.33
Nodes (6): SplashBook, TransitionPage, bookEnd, bookStart, TransitionPageView, .body

### Community 173 - "httpClient()"
Cohesion: 0.40
Nodes (4): DefaultHTTPClient, HTTPRequest, HTTPRequestConvertible, HTTPResult

### Community 174 - "Live updates via SSE"
Cohesion: 0.60
Nodes (5): KomgaEvent, KomgaEventBroadcaster, F7 — SSE + live updates, RemoteSSESession, Live updates via SSE

### Community 175 - "cbz()"
Cohesion: 0.60
Nodes (4): cbz(), main(), page(), Path

### Community 176 - "decode()"
Cohesion: 0.50
Nodes (3): OfflineJSON, Encodable, String

### Community 177 - "LoadState"
Cohesion: 0.40
Nodes (5): LoadState, error, loading, success, uninitialized

### Community 179 - "book()"
Cohesion: 0.50
Nodes (3): KomgaSeries, SplashBook, String

### Community 180 - "State"
Cohesion: 0.40
Nodes (5): State, CheckedContinuation, Never, Set, Void

### Community 181 - "wire_contract_check.py"
Cohesion: 0.70
Nodes (4): collect(), main(), normalize(), spec_index()

### Community 183 - "ThumbnailLoader"
Cohesion: 0.50
Nodes (4): F8 — image engine, ThumbnailLoader, Unknown thumbnail id maps to nil, SplashImage

## Ambiguous Edges - Review These
- `Splash` → `CLAUDE.md project guide`  [AMBIGUOUS]
  CLAUDE.md · relation: references

## Knowledge Gaps
- **594 isolated node(s):** `ReadiumStreamer`, `invalidURL`, `open`, `.errorDescription`, `.readium` (+589 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Splash` and `CLAUDE.md project guide`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **Why does `KomgaAPI` connect `Remote HTTP Client` to `Navigation & Destinations`, `OfflineSeries`, `Komga API Protocols`, `Book API Surface`, `Content Cards`, `KomgaApi`, `Offline GRDB Repositories`, `Offline Book Models`, `Book Content Extraction`, `Series Screen`, `Settings Screens`, `TestSession`, `CoreGraphics`, `Offline Sync Actions`, `Library Screen`, `Thumbnail Loading`, `EPUB Reader (Readium)`, `String`, `ReaderViewModel`, `AppModule`, `SyncReadProgressAction`, `PrivateCatalogViewModel`, `KomgaUserId`, `ViewModelFactory`, `HomeScreenFilter`, `BookViewModel`, `EpubReaderModel`, `OfflineModule`, `CollectionViewModel`, `OfflineTestEnvironment`, `SyncManager`, `Testing`, `SplashApp`, `ThumbnailRequest`, `SplashCore`, `BookDownloadService`, `KomgaAuthenticationState`, `PageId`, `SearchViewModel`, `LiveEventsController`, `HomeViewModel`, `AppRootView`?**
  _High betweenness centrality (0.082) - this node is a cross-community bridge._
- **Why does `Foundation` connect `Remote HTTP Client` to `uploadThumbnail()`, `Paged API Requests`, `Komga API Protocols`, `relativePath()`, `Page Rendering`, `OfflineSeries`, `Purchases & Paywall`, `App Settings Models`, `KomgaApi`, `Offline GRDB Repositories`, `Keychain & Secrets`, `Offline Book Models`, `Book Content Extraction`, `File Hashing`, `Patch Value Encoding`, `CoreGraphics`, `Search Conditions`, `DeviceAuthenticating`, `Book Wire Models`, `Offline Sync Actions`, `KomgaAuthor`, `String`, `AppModule`, `KomgaReadList`, `KomgaLocalDate`, `KomgaUserId`, `HomeScreenFilter`, `OfflineRecord`, `GRDBSettingsStores`, `EpubReaderModel`, `decode()`, `ScanInterval`, `KomgaCookieStore`, `R2Locator`, `KomgaSort`, `Testing`, `ReloadScheduler`, `SplashCore`, `BookDownloadService`, `KomgaAuthenticationState`, `KomgaIdentifier`, `PageId`, `OfflineSettings`, `ServerSentEventParser`?**
  _High betweenness centrality (0.072) - this node is a cross-community bridge._
- **Why does `KomgaBookId` connect `Book API Surface` to `Navigation & Destinations`, `Paged API Requests`, `webtoonUsesContinuousReaderWithLayout()`, `KomgaApi`, `Offline GRDB Repositories`, `Server Event Payloads`, `Offline Book Models`, `Book Content Extraction`, `DownloadEvent`, `API Error Types`, `OfflineDownloads`, `Remote Book API`, `Book Wire Models`, `Event Payload Models`, `Offline Sync Actions`, `HideMenuButton`, `bookMetadataMediaAndProgressRoundTrip()`, `ReaderViewModel`, `SyncReadProgressAction`, `PagedReaderModel`, `KomgaReadList`, `KomgaReadListId`, `KomgaUserId`, `ViewModelFactory`, `OfflineRecord`, `BookViewModel`, `URLSessionDownloadManager`, `OfflineModule`, `OfflineReadListApi`, `book()`, `State`, `OfflineController`, `OfflineTestEnvironment`, `SyncManager`, `TaskData`, `PrivacyController`, `R2Locator`, `book()`, `ThumbnailRequest`, `KomgaSeriesId`, `GRDBBookDtoRepository`, `OfflineBook`, `OfflineDataStore`, `TaskProcessor`, `BookDownload`, `BookDownloadService`, `KomgaIdentifier`, `PageId`, `LiveEventsController`, `HiddenContent`, `Error`, `OfflineFileLocator`, `OfflineTaskEmitter`?**
  _High betweenness centrality (0.066) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `KomgaBookId` (e.g. with `.book()` and `.book()`) actually correct?**
  _`KomgaBookId` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 7 inferred relationships involving `KomgaLibraryId` (e.g. with `HiddenContentFilterTests` and `.hiddenLibrariesBecomeNotEqualConditions()`) actually correct?**
  _`KomgaLibraryId` has 7 INFERRED edges - model-reasoned connections that need verification._
- **What connects `ReadiumStreamer`, `invalidURL`, `open` to the rest of the system?**
  _594 weakly-connected nodes found - possible documentation gaps or missing edges._