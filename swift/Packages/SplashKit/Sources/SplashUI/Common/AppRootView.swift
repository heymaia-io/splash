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
    /// Local file when the book is downloaded and we are offline, the Komga manifest otherwise.
    func epubSource(for book: SplashBook) async -> EpubSource?
    /// nil when purchases are not configured (tests/previews) — offline is then unrestricted.
    var entitlements: OfflineEntitlementStore? { get }
}

/// Port of `MainView.kt`'s root navigator: Login ↔ main shell, driven by the authentication state.
/// Screens that Kotlin pushes on the *root* navigator (settings, reader) are presented modally here.
public struct AppRootView: View {
    private let session: any AppSession
    @State private var loginModel: LoginViewModel
    @State private var mainModel: MainScreenViewModel?
    @State private var showSettings = false
    @State private var readingBook: SplashBook?
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
        }
    }

    private func main(_ model: MainScreenViewModel) -> some View {
        MainShellView(model: model, onOpenSettings: { showSettings = true }) { destination in
            DestinationView(
                destination: destination, factory: session.viewModelFactory, navigator: model.navigator,
                onRead: { open($0) })
        }
        .task {
            if let initialBook, !openedInitialBook {
                openedInitialBook = true
                open(initialBook)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(session: session, extraSections: AnyView(
                NavigationLink { DownloadsSettingsView() } label: {
                    Label("Downloads & offline", systemImage: "arrow.down.circle")
                }
            )) {
                showSettings = false
                loginModel = LoginViewModel(session: session)
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
        guard book.media.mediaProfile == .epub, !book.media.epubDivinaCompatible else {
            readingBook = book
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
        ReaderView(model: session.viewModelFactory.readerViewModel(bookId: book.id)) { exit in
            readingBook = nil
            // Finishing the last book returns to its series (`navigator replace MainScreen(SeriesScreen)`).
            if let exit { navigator.push(exit) }
        }
    }
}

