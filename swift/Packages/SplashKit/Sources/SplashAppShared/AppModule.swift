import Foundation
import SplashCore
import SplashDB
import SplashOffline
import SplashUI
import KomgaAPI
import KomgaRemote
import Observation
import Synchronization

/// Composition root — port of `komelia-app/shared/.../AppModule.kt` (explicit construction, no DI framework).
@MainActor
@Observable
public final class AppModule: AppSession {
    public static let downloadSessionIdentifier = "com.heymaia.splash.downloads"

    /// Where persistent state lives.
    public struct Storage: Sendable {
        public var database: SplashDatabase
        public var secrets: any SecretsRepository
        public var thumbnailCache: ThumbnailLoader.Configuration
        public var downloadRoot: URL
        public var downloadConfiguration: DownloadManagerConfiguration

        public init(
            database: SplashDatabase, secrets: any SecretsRepository,
            thumbnailCache: ThumbnailLoader.Configuration = .default, downloadRoot: URL,
            downloadConfiguration: DownloadManagerConfiguration
        ) {
            self.database = database
            self.secrets = secrets
            self.thumbnailCache = thumbnailCache
            self.downloadRoot = downloadRoot
            self.downloadConfiguration = downloadConfiguration
        }
    }

    // MARK: Public graph

    public let settings: CommonSettingsRepository
    public let imageReaderSettings: ImageReaderSettingsRepository
    public let homeFilters: HomeScreenFilterRepository
    public let epubSettings: EpubReaderSettingsRepository
    public let authState = KomgaAuthenticationState()
    public let events = KomgaEventBroadcaster()
    public let thumbnails: ThumbnailLoader
    public let offline: OfflineModule
    public let offlineSettings: OfflineSettingsStateRepository
    public let remoteApi: RemoteKomgaApi
    public private(set) var offlineController: OfflineController?
    public private(set) var entitlements: OfflineEntitlementStore?
    /// Changes whenever the active API switches (online ↔ offline) so the UI rebuilds its screens.
    public private(set) var contentGeneration = 0
    public private(set) var isOfflineMode: Bool

    @ObservationIgnored public private(set) lazy var viewModelFactory = ViewModelFactory(
        apiProvider: { [unowned self] in self.api },
        settings: settings,
        imageReaderSettings: imageReaderSettings,
        homeFilters: homeFilters,
        authState: authState,
        events: events,
        thumbnails: thumbnails)

    /// The API every screen uses: remote, or the offline implementation while in offline mode.
    public var api: any KomgaApi { apiHolder.current }

    // MARK: Private

    @ObservationIgnored private let secrets: any SecretsRepository
    @ObservationIgnored private let apiKeyStore: ApiKeyStore
    @ObservationIgnored private let cookieStore: KomgaCookieStore
    @ObservationIgnored private let server: ServerURLHolder
    @ObservationIgnored private let apiHolder: ApiHolder
    @ObservationIgnored private let liveEvents: LiveEventsController
    @ObservationIgnored private var accessPolicy: any OfflineAccessPolicy = AlwaysUnlockedPolicy()

    private init(
        settings: CommonSettingsRepository, imageReaderSettings: ImageReaderSettingsRepository,
        homeFilters: HomeScreenFilterRepository, epubSettings: EpubReaderSettingsRepository,
        offlineSettings: OfflineSettingsStateRepository, storage: Storage
    ) {
        self.epubSettings = epubSettings
        self.settings = settings
        self.imageReaderSettings = imageReaderSettings
        self.homeFilters = homeFilters
        self.offlineSettings = offlineSettings
        self.secrets = storage.secrets
        isOfflineMode = offlineSettings.isOfflineModeEnabled

        let server = ServerURLHolder(URL(string: settings.value.serverUrl) ?? AppSettings.unconfiguredServerURL)
        self.server = server
        let apiKeyStore = ApiKeyStore(secrets: storage.secrets)
        self.apiKeyStore = apiKeyStore
        cookieStore = KomgaCookieStore(
            serverURL: server.get, persistence: SecretsCookiePersistence(secrets: storage.secrets))
        let http = KomgaHTTPClient(baseURL: server.get, apiKey: { apiKeyStore.apiKey }, cookieStore: cookieStore)

        // The offline module needs the remote API lazily (downloads/imports) and the remote API needs the
        // offline book states — the box breaks the construction cycle.
        let remoteBox = RemoteBox()
        let downloadRoot = storage.downloadRoot
        offline = OfflineModule(
            store: GRDBOfflineDataStore(database: storage.database),
            tasksRepository: GRDBOfflineTasksRepository(storage.database.offline),
            settings: offlineSettings,
            remote: {
                guard let api = remoteBox.api else { throw KomgaAPIError.unsupported("Not logged in") }
                return OfflineRemoteContext(api: api, serverURL: server.get())
            },
            bookFileRequest: { id in
                guard let api = remoteBox.api else { throw KomgaAPIError.unsupported("Not logged in") }
                return api.remoteBookApi.bookFileRequest(id)
            },
            downloadConfiguration: storage.downloadConfiguration,
            downloadRoot: { downloadRoot })
        let remote = RemoteKomgaApi(http: http, offlineBooks: offline.bookStates, offlineEvents: offline.events)
        remoteApi = remote
        remoteBox.set(remote)

        let holder = ApiHolder(offlineSettings.isOfflineModeEnabled ? offline.api : remote)
        apiHolder = holder
        let thumbnails = ThumbnailLoader(
            api: { holder.current }, namespace: { server.get().absoluteString },
            configuration: storage.thumbnailCache)
        self.thumbnails = thumbnails
        liveEvents = LiveEventsController(api: { holder.current }, broadcaster: events, thumbnails: thumbnails)
    }

    /// `initDependencies()`
    public static func make(storage: Storage, accessPolicy: (any OfflineAccessPolicy)? = nil) async throws
        -> AppModule
    {
        let db = storage.database
        let settings = try await SettingsState.load(from: GRDBAppSettingsStore(db.app), default: AppSettings())
        let readerSettings = try await SettingsState.load(
            from: GRDBImageReaderSettingsStore(db.app), default: ImageReaderSettings())
        let filters = try await SettingsState.load(
            from: GRDBHomeScreenFilterStore<HomeScreenFilter>(db.app), default: HomeScreenFilter.defaults)
        let epubSettings = try await SettingsState.load(
            from: GRDBEpubReaderSettingsStore<EpubReaderSettings>(db.app), default: EpubReaderSettings())
        let offlineSettings = try await OfflineSettingsStateRepository.load(
            database: db, defaultDownloadDirectory: storage.downloadRoot)
        let module = AppModule(
            settings: settings, imageReaderSettings: readerSettings, homeFilters: filters,
            epubSettings: epubSettings, offlineSettings: offlineSettings, storage: storage)
        if let accessPolicy { module.accessPolicy = accessPolicy }
        await module.cookieStore.loadRememberMeCookie()
        await module.apiKeyStore.loadStoredApiKey(serverURL: module.settings.value.serverUrl)
        let controller = OfflineController(
            service: module.offline.downloads, modeSwitch: module, access: module.accessPolicy,
            wifiOnly: UserDefaults.standard.bool(forKey: wifiOnlyKey),
            onWifiOnlyChange: { UserDefaults.standard.set($0, forKey: wifiOnlyKey) })
        module.offlineController = controller
        await module.offline.start()
        controller.start()
        return module
    }

    static let wifiOnlyKey = "downloads.wifiOnly"

    /// Production entry point used by the app target.
    public static func makeDefault(accessPolicy: (any OfflineAccessPolicy)? = nil) async throws -> AppModule {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = support.appending(path: "Splash", directoryHint: .isDirectory)
        // Computed on every launch: the container path changes between app updates.
        var downloads = directory.appending(path: "Downloads", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true  // re-downloadable content must not bloat iCloud backups
        try? downloads.setResourceValues(values)

        let database = try SplashDatabase(directory: directory)
        let wifiOnlyKey = wifiOnlyKey
        let storage = Storage(
            database: database, secrets: KeychainSecretsRepository(), downloadRoot: downloads,
            downloadConfiguration: .background(
                identifier: downloadSessionIdentifier,
                allowsCellularAccess: { !UserDefaults.standard.bool(forKey: wifiOnlyKey) }))
        return try await make(storage: storage, accessPolicy: accessPolicy)
    }

    /// Production wiring of the paid offline unlock (plan Phase 16).
    public static func makeDefaultWithStore() async throws -> AppModule {
        let store = OfflineEntitlementStore(provider: StoreKitOfflineProvider())
        #if DEBUG
        // Debug builds only: `SPLASH_UNLOCK_OFFLINE=1` skips the entitlement check so downloads and offline
        // mode can be exercised without going through StoreKit at all. Deliberately compiled out of release
        // builds — a bypass that ships is a bypass anyone can find in the binary.
        if ProcessInfo.processInfo.environment["SPLASH_UNLOCK_OFFLINE"] == "1" {
            let module = try await makeDefault(accessPolicy: AlwaysUnlockedPolicy())
            module.entitlements = store
            await store.start()
            return module
        }
        #endif
        let module = try await makeDefault(accessPolicy: store)
        module.entitlements = store
        await store.start()
        return module
    }

    /// Late injection of the purchase-backed policy (Phase 16).
    public func setAccessPolicy(_ policy: any OfflineAccessPolicy) {
        accessPolicy = policy
        guard let old = offlineController else { return }
        let controller = OfflineController(
            service: offline.downloads, modeSwitch: self, access: policy, wifiOnly: old.wifiOnly,
            onWifiOnlyChange: { UserDefaults.standard.set($0, forKey: Self.wifiOnlyKey) })
        offlineController = controller
        controller.start()
    }

    // MARK: - Lifecycle hooks

    /// Starts/stops live events; the app calls this from `scenePhase` changes ([NUEVO] iOS lifecycle).
    public func setLiveEventsActive(_ active: Bool) {
        if active, authState.state == .loaded { liveEvents.start() } else { liveEvents.stop() }
        if active, authState.state == .loaded, !isOfflineMode, let user = authState.authenticatedUser {
            // Sync trigger = authenticated online user (`onlineUser.filterNotNull()`), not reachability.
            let remote = remoteApi
            let sync = offline.syncManager
            Task { await sync.onlineUserChanged(user, api: remote) }
        }
    }

    /// `application(_:handleEventsForBackgroundURLSession:completionHandler:)`
    public func handleBackgroundURLSessionEvents(identifier: String, completion: @escaping @Sendable () -> Void) {
        offline.downloadManager.handleEventsForBackgroundURLSession(
            identifier: identifier, completionHandler: completion)
    }

    #if DEBUG
    /// UI-automation hook: `SPLASH_DEBUG_LOGIN="url|user|password"` and `SPLASH_DEBUG_BOOK=<bookId>`
    /// (passed with `SIMCTL_CHILD_` prefix to `simctl launch`). Never compiled into release builds.
    public func debugBootstrap(environment: [String: String]) async -> SplashBook? {
        guard let login = environment["SPLASH_DEBUG_LOGIN"] else { return nil }
        let parts = login.split(separator: "|", maxSplits: 2).map(String.init)
        guard parts.count == 3 else { return nil }
        if isOfflineMode { try? await setOfflineMode(false) }
        try? await settings.set(\.serverUrl, parts[0])
        await switchServer(to: parts[0])
        guard let user = try? await remoteApi.userApi.getMe(username: parts[1], password: parts[2], rememberMe: true),
              let libraries = try? await remoteApi.libraryApi.getLibraries()
        else { return nil }
        authState.setStateValues(user: user, libraries: libraries)
        guard let bookId = environment["SPLASH_DEBUG_BOOK"].map(KomgaBookId.init) else { return nil }
        // SPLASH_DEBUG_OFFLINE=1: download the book, wait for it, then switch to offline mode.
        if environment["SPLASH_DEBUG_OFFLINE"] == "1" {
            try? await offline.downloads.downloadBook(bookId)
            for _ in 0..<120 {
                if (try? await offline.downloads.localFileURL(for: bookId)) != nil { break }
                try? await Task.sleep(for: .milliseconds(500))
            }
            try? await goOffline(as: user.id)
        }
        return try? await api.bookApi.getOne(bookId)
    }
    #endif

    // MARK: - LoginSession

    public func hasStoredSession(serverURL: String) async -> Bool {
        if isOfflineMode { return true }
        let cookie = try? await secrets.getCookie(url: serverURL)
        let apiKey = try? await secrets.getApiKey(url: serverURL)
        return cookie != nil || apiKey != nil
    }

    public func switchServer(to serverURL: String) async {
        guard let url = URL(string: serverURL), server.replace(with: url) else { return }
        liveEvents.stop()
        await cookieStore.resetInMemory()
        await cookieStore.loadRememberMeCookie()
        await apiKeyStore.loadStoredApiKey(serverURL: serverURL)
        await thumbnails.clearMemory()
    }

    public func storeApiKey(_ apiKey: String, serverURL: String) async throws {
        try await apiKeyStore.setApiKey(apiKey, serverURL: serverURL)
    }

    // MARK: - AppSession

    public func epubSource(for book: SplashBook) async -> EpubSource? {
        if isOfflineMode {
            guard let file = try? await offline.downloads.localFileURL(for: book.id) else { return nil }
            return .local(file: file)
        }
        let http = remoteApi.http
        return .remote(manifest: remoteApi.webPubManifestURL(book.id), headers: { http.authorizationHeaders(for: $0) })
    }

    /// Port of `SettingsNavigationViewModel.logout()`.
    public func logout() async {
        liveEvents.stop()
        if isOfflineMode {
            try? await setOfflineMode(false)
        } else {
            _ = try? await remoteApi.userApi.logout()
        }
        let serverURL = settings.value.serverUrl
        await cookieStore.clear()
        try? await secrets.deleteCookie(url: serverURL)
        try? await apiKeyStore.deleteApiKey(serverURL: serverURL)
        authState.reset()
    }

    private func setOfflineMode(_ offlineMode: Bool) async throws {
        try await offlineSettings.putOfflineMode(offlineMode)
        isOfflineMode = offlineMode
        liveEvents.stop()
        apiHolder.set(offlineMode ? offline.api : remoteApi)
        await thumbnails.clearMemory()
        contentGeneration += 1
    }
}

// MARK: - Offline mode switching (`LoginViewModel.offlineLogin`, `MainScreenViewModel.goOnline`)

extension AppModule: OfflineModeSwitching {
    /// Reads the offline store directly (not `api`), so the shelf is identical online and offline.
    public func downloadedSeries() async throws -> [KomgaSeries] {
        try await offline.api.seriesApi
            .getSeriesList(search: KomgaSeriesSearch(), pageRequest: KomgaPageRequest(unpaged: true))
            .content
    }

    public func offlineUsers() async -> [OfflineUserChoice] {
        (try? await offline.store.read { repos in
            try repos.users.findAll()
                .filter { $0.id != OfflineUser.root }
                .map { user in
                    OfflineUserChoice(
                        id: user.id, email: user.email,
                        serverURL: try user.serverId.flatMap { try repos.mediaServers.find($0)?.url })
                }
        }) ?? []
    }

    public func goOffline(as userId: KomgaUserId) async throws {
        let user = try await offline.store.read { try $0.users.get(userId) }
        try await offlineSettings.putUserId(userId)
        try await setOfflineMode(true)
        let libraries = try await offline.api.libraryApi.getLibraries()
        authState.setStateValues(user: user.toKomgaUser(), libraries: libraries)
        setLiveEventsActive(true)
    }

    /// Kotlin returns to the login screen, which auto-logs-in with the stored cookie.
    public func goOnline() async throws {
        try await setOfflineMode(false)
        authState.reset()
    }
}

// MARK: - Support types

/// Current `KomgaApi` (remote or offline), readable from any thread.
final class ApiHolder: Sendable {
    private let value: Mutex<any KomgaApi>
    init(_ api: any KomgaApi) { value = Mutex(api) }
    var current: any KomgaApi { value.withLock { $0 } }
    func set(_ api: any KomgaApi) { value.withLock { $0 = api } }
}

final class RemoteBox: Sendable {
    private let value = Mutex<RemoteKomgaApi?>(nil)
    var api: RemoteKomgaApi? { value.withLock { $0 } }
    func set(_ api: RemoteKomgaApi) { value.withLock { $0 = api } }
}

/// Thread-safe current server URL (read synchronously by every request).
final class ServerURLHolder: Sendable {
    private let value: Mutex<URL>

    init(_ url: URL) { value = Mutex(url) }

    var get: @Sendable () -> URL { { [self] in value.withLock { $0 } } }

    /// Returns true when the URL actually changed.
    func replace(with url: URL) -> Bool {
        value.withLock { current in
            defer { current = url }
            return current != url
        }
    }
}

/// Keeps one SSE session alive and fans its events out to every screen (`komgaEvents` SharedFlow),
/// invalidating thumbnail caches on `Thumbnail*` events (plan Phase 5/7 hook).
@MainActor
final class LiveEventsController {
    private let api: @Sendable () -> any KomgaApi
    private let broadcaster: KomgaEventBroadcaster
    private let thumbnails: ThumbnailLoader
    private var session: (any KomgaSSESession)?
    private var pump: Task<Void, Never>?

    init(api: @escaping @Sendable () -> any KomgaApi, broadcaster: KomgaEventBroadcaster, thumbnails: ThumbnailLoader) {
        self.api = api
        self.broadcaster = broadcaster
        self.thumbnails = thumbnails
    }

    func start() {
        guard pump == nil else { return }
        let api = self.api()
        let broadcaster = self.broadcaster
        let thumbnails = self.thumbnails
        pump = Task { [weak self] in
            guard let session = try? await api.createSSESession() else { return }
            self?.session = session
            for await event in session.incoming {
                if let prefix = Self.thumbnailPrefix(for: event) { await thumbnails.invalidate(prefix: prefix) }
                broadcaster.emit(event)
            }
        }
    }

    func stop() {
        session?.cancel()
        session = nil
        pump?.cancel()
        pump = nil
    }

    nonisolated static func thumbnailPrefix(for event: KomgaEvent) -> String? {
        switch event {
        case .thumbnailBookAdded(let p), .thumbnailBookDeleted(let p): ThumbnailRequest.prefix(book: p.bookId)
        case .thumbnailSeriesAdded(let p), .thumbnailSeriesDeleted(let p): ThumbnailRequest.prefix(series: p.seriesId)
        case .thumbnailSeriesCollectionAdded(let p), .thumbnailSeriesCollectionDeleted(let p):
            ThumbnailRequest.prefix(collection: p.collectionId)
        case .thumbnailReadListAdded(let p), .thumbnailReadListDeleted(let p):
            ThumbnailRequest.prefix(readList: p.readListId)
        case .bookChanged(let p): ThumbnailRequest.prefix(book: p.bookId)  // page thumbnails may change
        default: nil
        }
    }
}

/// Adapter: remote cookie persistence → `SecretsRepository` (keeps KomgaRemote independent of SplashCore).
struct SecretsCookiePersistence: KomgaCookiePersistence {
    let secrets: any SecretsRepository

    func loadCookie(serverURL: String) async throws -> String? {
        try await secrets.getCookie(url: Self.key(serverURL))
    }

    func saveCookie(_ setCookieHeader: String, serverURL: String) async throws {
        try await secrets.setCookie(url: Self.key(serverURL), cookie: setCookieHeader)
    }

    func deleteCookie(serverURL: String) async throws {
        try await secrets.deleteCookie(url: Self.key(serverURL))
    }

    /// Settings store the URL without a trailing slash; `URL.absoluteString` may carry one.
    static func key(_ url: String) -> String {
        var key = url
        while key.hasSuffix("/") { key.removeLast() }
        return key
    }
}
