import SplashCore
import KomgaAPI
import SwiftUI

/// What the root of the UI needs from the composition root.
@MainActor
public protocol AppSession: LoginSession {
    var viewModelFactory: ViewModelFactory { get }
    func logout() async
    /// Live server events (SSE) — active only while authenticated and in the foreground.
    func setLiveEventsActive(_ active: Bool)
    var offlineController: OfflineController? { get }
    var isOfflineMode: Bool { get }
    /// Bumped when the active API changes (online ↔ offline); screens are rebuilt.
    var contentGeneration: Int { get }
    var epubSettings: EpubReaderSettingsRepository { get }
    /// Local file when the book is downloaded, the Komga manifest otherwise.
    func epubSource(for book: SplashBook) async -> EpubSource?
    /// API a book is read through — the offline store for downloaded books, the active API otherwise.
    func readingApi(for book: SplashBook) async -> any KomgaApi
    /// API backed purely by the offline store, used to browse downloaded content without a connection.
    var offlineApi: any KomgaApi { get }
    /// nil when purchases are not configured (tests/previews) — offline is then unrestricted.
    var entitlements: PremiumEntitlementStore? { get }
    /// nil when privacy is not configured (tests/previews) — nothing is then hidden.
    var privacy: PrivacyController? { get }
}

/// Port of `MainView.kt`'s root navigator: Login ↔ main shell, driven by the authentication state.
/// Screens that Kotlin pushes on the *root* navigator (settings, reader) are presented modally here.
public struct AppRootView: View {
    private let session: any AppSession
    @State private var loginModel: LoginViewModel
    @State private var mainModel: MainScreenViewModel?
    @State private var readingBook: SplashBook?
    /// Resolved just before presenting the image reader (see `readingApi(for:)`).
    @State private var readerApi: (any KomgaApi)?
    @State private var epubModel: EpubReaderModel?
    @State private var openedInitialBook = false
    @Environment(\.epubReaderPresenter) private var epubPresenter
    @Environment(\.scenePhase) private var scenePhase

    private let initialBook: SplashBook?

    public init(session: any AppSession, initialBook: SplashBook? = nil) {
        self.session = session
        self.initialBook = initialBook
        _loginModel = State(initialValue: LoginViewModel(session: session))
    }

    public var body: some View {
        Group {
            switch session.authState.state {
            case .authenticationRequired:
                LoginView(model: loginModel)
                    .onChange(of: session.contentGeneration) { loginModel = LoginViewModel(session: session) }
            case .loaded:
                if let mainModel {
                    VStack(spacing: 0) {
                        if session.isOfflineMode, let offline = session.offlineController {
                            OfflineBanner(offline: offline)
                        }
                        if let privacy = session.privacy, privacy.isUnlocked {
                            PrivacyBanner(privacy: privacy)
                        }
                        main(mainModel)
                    }
                    .id(session.contentGeneration)
                } else {
                    ProgressView().onAppear {
                        let model = MainScreenViewModel(authState: session.authState)
                        model.startListening(to: session.viewModelFactory.events.subscribe())
                        mainModel = model
                    }
                }
            }
        }
        .environment(\.thumbnailLoader, session.viewModelFactory.thumbnails)
        .environment(\.offlineController, session.offlineController)
        .environment(\.privacy, session.privacy)
        .preferredColorScheme(session.settings.value.appTheme.colorScheme)
        .background(session.settings.value.appTheme == .darker ? Color.black.ignoresSafeArea() : nil)
        .sheet(isPresented: Binding(
            get: { session.entitlements?.isPaywallPresented ?? false },
            set: { session.entitlements?.isPaywallPresented = $0 })
        ) {
            if let store = session.entitlements { PaywallView(store: store) }
        }
        .onChange(of: session.authState.state) { _, state in
            if state == .authenticationRequired {
                mainModel?.stopListening()
                mainModel = nil
            }
            session.setLiveEventsActive(state == .loaded && scenePhase == .active)
        }
        // [NUEVO] iOS lifecycle: pause SSE in background, resume when active (plan Phase 7).
        .onChange(of: scenePhase) { _, phase in
            session.setLiveEventsActive(phase == .active && session.authState.state == .loaded)
            session.privacy?.scenePhaseChanged(phase)
        }
        // [NUEVO] The app-switcher snapshot is taken while `.inactive`; without this it would preserve
        // everything the feature hides, in a thumbnail the user cannot dismiss.
        .privacyBlur(isActive: (session.privacy?.isUnlocked ?? false) && scenePhase != .active)
        .task {
            // Being deep inside content that is about to vanish must eject you, or you are left on a detail
            // screen for an item that no longer appears in any list.
            session.privacy?.onLock = { [weak mainModel] in
                mainModel?.navigator.replaceAll(.home)
                mainModel?.searchQuery = ""
            }
        }
    }

    private func main(_ model: MainScreenViewModel) -> some View {
        MainShellView(model: model) { destination in
            // Settings is the only destination that needs the composition root, so it is resolved here
            // instead of in `DestinationView` (which only knows the view-model factory).
            switch destination {
            case .settings:
                SettingsView(session: session, isEmbedded: true) {
                    loginModel = LoginViewModel(session: session)
                }
            default:
                DestinationView(
                    destination: destination, factory: session.viewModelFactory, navigator: model.navigator,
                    api: model.navigator.root == .downloads ? session.offlineApi : nil,
                    onRead: { open($0) })
            }
        }
        .task {
            if let initialBook, !openedInitialBook {
                openedInitialBook = true
                open(initialBook)
            }
        }
        #if os(iOS)
        .fullScreenCover(item: $readingBook) { book in reader(book, navigator: model.navigator) }
        .fullScreenCover(item: $epubModel) { epub in epubReader(epub) }
        #else
        .sheet(item: $readingBook) { book in reader(book, navigator: model.navigator) }
        .sheet(item: $epubModel) { epub in epubReader(epub) }
        #endif
    }

    /// EPUB books go to the Readium reader (plan Phase 15); everything else (CBZ, images, PDF) to the image
    /// reader. EPUBs that Komga marks as DiViNa-compatible (fixed-layout comics) also use the image reader.
    private func open(_ book: SplashBook) {
        // This is the one path into the reader that does not come through a filtered listing — it is also
        // reached by `initialBook` at launch, which is restored from the last session and can name a book
        // hidden since. Silently doing nothing is deliberate: an error would confirm the book exists.
        guard !(session.privacy?.filter() ?? .disabled).isHidden(book: book) else { return }
        guard book.media.mediaProfile == .epub, !book.media.epubDivinaCompatible else {
            Task { readerApi = await session.readingApi(for: book); readingBook = book }
            return
        }
        Task {
            guard let source = await session.epubSource(for: book) else { return }
            epubModel = EpubReaderModel(
                book: book, source: source, api: session.viewModelFactory.apiProvider(),
                settings: session.epubSettings)
        }
    }

    @ViewBuilder private func epubReader(_ model: EpubReaderModel) -> some View {
        if let epubPresenter {
            epubPresenter.makeReader(model: model) { epubModel = nil }
        } else {
            NavigationStack {
                ContentUnavailableView("EPUB reader unavailable", systemImage: "book.closed")
                    .toolbar { Button("Close") { epubModel = nil } }
            }
        }
    }

    /// Image reader pushed over the main navigator (Kotlin: `navigator.parent.push(ImageReaderScreen)`).
    private func reader(_ book: SplashBook, navigator: MainNavigator) -> some View {
        ReaderView(model: session.viewModelFactory.readerViewModel(bookId: book.id, api: readerApi)) { exit in
            readingBook = nil
            readerApi = nil
            // Finishing the last book returns to its series (`navigator replace MainScreen(SeriesScreen)`).
            if let exit { navigator.push(exit) }
        }
    }
}

