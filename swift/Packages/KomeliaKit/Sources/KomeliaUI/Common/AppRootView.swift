import KomeliaCore
import KomgaAPI
import SwiftUI

/// What the root of the UI needs from the composition root.
@MainActor
public protocol AppSession: LoginSession {
    var viewModelFactory: ViewModelFactory { get }
    func logout() async
    /// Live server events (SSE) — active only while authenticated and in the foreground.
    func setLiveEventsActive(_ active: Bool)
}

/// Port of `MainView.kt`'s root navigator: Login ↔ main shell, driven by the authentication state.
/// Screens that Kotlin pushes on the *root* navigator (settings, reader) are presented modally here.
public struct AppRootView: View {
    private let session: any AppSession
    @State private var loginModel: LoginViewModel
    @State private var mainModel: MainScreenViewModel?
    @State private var showSettings = false
    @State private var readingBook: KomeliaBook?
    @Environment(\.scenePhase) private var scenePhase

    private let initialBook: KomeliaBook?

    public init(session: any AppSession, initialBook: KomeliaBook? = nil) {
        self.session = session
        self.initialBook = initialBook
        _loginModel = State(initialValue: LoginViewModel(session: session))
        _readingBook = State(initialValue: initialBook)
    }

    public var body: some View {
        Group {
            switch session.authState.state {
            case .authenticationRequired:
                LoginView(model: loginModel)
            case .loaded:
                if let mainModel {
                    main(mainModel)
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
                onRead: { readingBook = $0 })
        }
        .sheet(isPresented: $showSettings) {
            SettingsPlaceholderView(session: session) {
                showSettings = false
                loginModel = LoginViewModel(session: session)
            }
        }
        #if os(iOS)
        .fullScreenCover(item: $readingBook) { book in reader(book, navigator: model.navigator) }
        #else
        .sheet(item: $readingBook) { book in reader(book, navigator: model.navigator) }
        #endif
    }

    /// Image reader pushed over the main navigator (Kotlin: `navigator.parent.push(ImageReaderScreen)`).
    private func reader(_ book: KomeliaBook, navigator: MainNavigator) -> some View {
        ReaderView(model: session.viewModelFactory.readerViewModel(bookId: book.id)) { exit in
            readingBook = nil
            // Finishing the last book returns to its series (`navigator replace MainScreen(SeriesScreen)`).
            if let exit { navigator.push(exit) }
        }
    }
}

/// Minimal settings until Phase 13 (account + logout).
struct SettingsPlaceholderView: View {
    let session: any AppSession
    let onLoggedOut: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                if let user = session.authState.authenticatedUser {
                    Section("Account") {
                        LabeledContent("User", value: user.email)
                        LabeledContent("Server", value: session.settings.value.serverUrl)
                    }
                }
                Section {
                    Button("Log out", role: .destructive) {
                        Task {
                            await session.logout()
                            onLoggedOut()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
