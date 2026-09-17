import Foundation
import KomeliaCore
import KomeliaDB
import KomeliaUI
import KomgaAPI
import KomgaRemote
import Synchronization

/// Composition root — port of `komelia-app/shared/.../AppModule.kt` (explicit construction, no DI framework).
@MainActor
public final class AppModule: AppSession {
    /// Where persistent state lives; swapped for in-memory stores in previews/tests.
    public struct Storage: Sendable {
        public var appSettings: any SettingsStore<AppSettings>
        public var imageReaderSettings: any SettingsStore<ImageReaderSettings>
        public var homeFilters: any SettingsStore<[HomeScreenFilter]>
        public var secrets: any SecretsRepository
        public var thumbnailCache: ThumbnailLoader.Configuration

        public init(
            appSettings: any SettingsStore<AppSettings>,
            imageReaderSettings: any SettingsStore<ImageReaderSettings>,
            homeFilters: any SettingsStore<[HomeScreenFilter]>,
            secrets: any SecretsRepository,
            thumbnailCache: ThumbnailLoader.Configuration = .default
        ) {
            self.appSettings = appSettings
            self.imageReaderSettings = imageReaderSettings
            self.homeFilters = homeFilters
            self.secrets = secrets
            self.thumbnailCache = thumbnailCache
        }

        /// Production wiring: GRDB databases in Application Support + Keychain.
        public static func persistent(database: KomeliaDatabase) -> Storage {
            Storage(
                appSettings: GRDBAppSettingsStore(database.app),
                imageReaderSettings: GRDBImageReaderSettingsStore(database.app),
                homeFilters: GRDBHomeScreenFilterStore<HomeScreenFilter>(database.app),
                secrets: KeychainSecretsRepository())
        }

        public static func inMemory() -> Storage {
            Storage(
                appSettings: InMemorySettingsStore<AppSettings>(),
                imageReaderSettings: InMemorySettingsStore<ImageReaderSettings>(),
                homeFilters: InMemorySettingsStore<[HomeScreenFilter]>(),
                secrets: InMemorySecretsRepository(),
                thumbnailCache: .init(directory: FileManager.default.temporaryDirectory.appending(path: "thumbs")))
        }
    }

    public let settings: CommonSettingsRepository
    public let imageReaderSettings: ImageReaderSettingsRepository
    public let homeFilters: HomeScreenFilterRepository
    public let authState = KomgaAuthenticationState()
    public let events = KomgaEventBroadcaster()
    public let api: any KomgaApi
    public let thumbnails: ThumbnailLoader
    public private(set) lazy var viewModelFactory = ViewModelFactory(
        apiProvider: { [unowned self] in self.api },
        settings: settings,
        imageReaderSettings: imageReaderSettings,
        homeFilters: homeFilters,
        authState: authState,
        events: events,
        thumbnails: thumbnails)

    private let secrets: any SecretsRepository
    private let apiKeyStore: ApiKeyStore
    private let cookieStore: KomgaCookieStore
    private let server: ServerURLHolder
    private let liveEvents: LiveEventsController

    private init(
        settings: CommonSettingsRepository, imageReaderSettings: ImageReaderSettingsRepository,
        homeFilters: HomeScreenFilterRepository, storage: Storage
    ) {
        self.settings = settings
        self.imageReaderSettings = imageReaderSettings
        self.homeFilters = homeFilters
        self.secrets = storage.secrets

        let server = ServerURLHolder(URL(string: settings.value.serverUrl) ?? URL(string: AppSettings().serverUrl)!)
        self.server = server
        let apiKeyStore = ApiKeyStore(secrets: storage.secrets)
        self.apiKeyStore = apiKeyStore
        cookieStore = KomgaCookieStore(
            serverURL: server.get, persistence: SecretsCookiePersistence(secrets: storage.secrets))
        let http = KomgaHTTPClient(baseURL: server.get, apiKey: { apiKeyStore.apiKey }, cookieStore: cookieStore)
        let api = RemoteKomgaApi(http: http)
        self.api = api
        thumbnails = ThumbnailLoader(
            api: { api }, namespace: { server.get().absoluteString }, configuration: storage.thumbnailCache)
        liveEvents = LiveEventsController(api: api, broadcaster: events, thumbnails: thumbnails)
    }

    /// `initDependencies()`
    public static func make(storage: Storage) async throws -> AppModule {
        async let settings = SettingsState.load(from: storage.appSettings, default: AppSettings())
        async let readerSettings = SettingsState.load(from: storage.imageReaderSettings, default: ImageReaderSettings())
        async let filters = SettingsState.load(from: storage.homeFilters, default: HomeScreenFilter.defaults)
        let module = try await AppModule(
            settings: settings, imageReaderSettings: readerSettings, homeFilters: filters, storage: storage)
        await module.cookieStore.loadRememberMeCookie()
        await module.apiKeyStore.loadStoredApiKey(serverURL: module.settings.value.serverUrl)
        return module
    }

    /// Production entry point used by the app target.
    public static func makeDefault() async throws -> AppModule {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = support.appending(path: "Komelia", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try KomeliaDatabase(directory: directory)
        return try await make(storage: .persistent(database: database))
    }

    // MARK: - Live events (Phase 7)

    /// Starts/stops the SSE session; the app calls this from `scenePhase` changes ([NUEVO] iOS lifecycle).
    public func setLiveEventsActive(_ active: Bool) {
        if active, authState.state == .loaded { liveEvents.start() } else { liveEvents.stop() }
    }

    #if DEBUG
    /// UI-automation hook: `KOMELIA_DEBUG_LOGIN="url|user|password"` and `KOMELIA_DEBUG_BOOK=<bookId>`
    /// (passed with `SIMCTL_CHILD_` prefix to `simctl launch`). Never compiled into release builds.
    public func debugBootstrap(environment: [String: String]) async -> KomeliaBook? {
        guard let login = environment["KOMELIA_DEBUG_LOGIN"] else { return nil }
        let parts = login.split(separator: "|", maxSplits: 2).map(String.init)
        guard parts.count == 3 else { return nil }
        try? await settings.set(\.serverUrl, parts[0])
        await switchServer(to: parts[0])
        guard let user = try? await api.userApi.getMe(username: parts[1], password: parts[2], rememberMe: true),
              let libraries = try? await api.libraryApi.getLibraries()
        else { return nil }
        authState.setStateValues(user: user, libraries: libraries)
        guard let bookId = environment["KOMELIA_DEBUG_BOOK"] else { return nil }
        return try? await api.bookApi.getOne(KomgaBookId(bookId))
    }
    #endif

    // MARK: - LoginSession

    public func hasStoredSession(serverURL: String) async -> Bool {
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

    /// Port of `SettingsNavigationViewModel.logout()` (online branch).
    public func logout() async {
        liveEvents.stop()
        _ = try? await api.userApi.logout()
        let serverURL = settings.value.serverUrl
        await cookieStore.clear()
        try? await secrets.deleteCookie(url: serverURL)
        try? await apiKeyStore.deleteApiKey(serverURL: serverURL)
        authState.reset()
    }
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
    private let api: any KomgaApi
    private let broadcaster: KomgaEventBroadcaster
    private let thumbnails: ThumbnailLoader
    private var session: (any KomgaSSESession)?
    private var pump: Task<Void, Never>?

    init(api: any KomgaApi, broadcaster: KomgaEventBroadcaster, thumbnails: ThumbnailLoader) {
        self.api = api
        self.broadcaster = broadcaster
        self.thumbnails = thumbnails
    }

    func start() {
        guard pump == nil else { return }
        let api = self.api
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

/// Adapter: remote cookie persistence → `SecretsRepository` (keeps KomgaRemote independent of KomeliaCore).
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
