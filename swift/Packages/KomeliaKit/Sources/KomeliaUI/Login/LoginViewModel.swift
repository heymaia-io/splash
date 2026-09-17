import Foundation
import KomeliaCore
import KomgaAPI
import Observation

/// Everything the login flow needs from the app, injected by the composition root (dependency inversion:
/// the view model never sees HTTP clients, cookie jars or the Keychain directly).
@MainActor
public protocol LoginSession: AnyObject {
    var api: any KomgaApi { get }
    var settings: CommonSettingsRepository { get }
    var authState: KomgaAuthenticationState { get }
    /// Remember-me cookie stored for `serverURL` (drives auto-login, like `secretsRepository.getCookie`).
    func hasStoredSession(serverURL: String) async -> Bool
    /// Points the HTTP stack at a new server (reloads cookies / API key for it).
    func switchServer(to serverURL: String) async
    func storeApiKey(_ apiKey: String, serverURL: String) async throws
}

/// Port of `snd.komelia.ui.login.LoginViewModel` (online part; offline login arrives with Phase 10).
@MainActor
@Observable
public final class LoginViewModel {
    public enum Mode: String, CaseIterable, Sendable {
        case credentials
        /// [NUEVO] The mobile Kotlin form only offers credentials; API keys are exposed on iOS too.
        case apiKey
    }

    public enum LoadState: Equatable {
        case uninitialized
        case loading
        case success
        case error(String)
    }

    public var url = ""
    public var user = ""
    public var password = ""
    public var apiKey = ""
    public var mode: Mode = .credentials
    public private(set) var state: LoadState = .uninitialized
    public private(set) var userLoginError: String?
    public private(set) var autoLoginError: String?

    private let session: any LoginSession
    private var loginTask: Task<Void, Never>?

    public init(session: any LoginSession) {
        self.session = session
    }

    /// `initialize()` — restores the last server/user and auto-logs-in when a session cookie exists.
    public func initialize() async {
        guard state == .uninitialized else { return }
        let settings = session.settings.value
        url = settings.serverUrl
        user = settings.username
        let hasSession = await session.hasStoredSession(serverURL: url)
        if hasSession {
            state = .loading
            await tryAutoLogin()
        } else {
            url = ""
            user = ""
            state = .error(String(localized: "Not logged in"))
        }
    }

    public func retryAutoLogin() {
        start { await $0.tryAutoLogin() }
    }

    public func cancel() {
        loginTask?.cancel()
        let message = String(localized: "Cancelled login attempt")
        state = .error(message)
        userLoginError = message
    }

    public func login() {
        switch mode {
        case .credentials: loginWithCredentials()
        case .apiKey: loginWithApiKey()
        }
    }

    public func loginWithCredentials() {
        start { model in
            guard let serverURL = model.prepareServerURL() else { return }
            try? await model.session.settings.set(\.serverUrl, serverURL)
            try? await model.session.settings.set(\.username, model.user)
            await model.session.switchServer(to: serverURL)
            await model.tryUserLogin(username: model.user, password: model.password)
        }
    }

    public func loginWithApiKey() {
        start { model in
            guard let serverURL = model.prepareServerURL() else { return }
            try? await model.session.settings.set(\.serverUrl, serverURL)
            await model.session.switchServer(to: serverURL)
            do {
                try await model.session.storeApiKey(model.apiKey, serverURL: serverURL)
            } catch {
                model.fail(user: String(localized: "Login error: \(error.localizedDescription)"))
                return
            }
            await model.tryUserLogin(username: nil, password: nil)
        }
    }

    // MARK: - Private

    private func start(_ body: @escaping @MainActor (LoginViewModel) async -> Void) {
        loginTask?.cancel()
        userLoginError = nil
        state = .loading
        loginTask = Task { [weak self] in
            guard let self else { return }
            await body(self)
        }
    }

    private func prepareServerURL() -> String? {
        guard let normalized = ServerURL.normalize(url) else {
            fail(user: String(localized: "Invalid server URL"))
            return nil
        }
        url = normalized
        return normalized
    }

    private func tryAutoLogin() async {
        do {
            try await tryLogin()
        } catch {
            guard !Task.isCancelled else { return }
            state = .error(error.localizedDescription)
            // 401 on auto-login just means "show the form" (Kotlin: `if Unauthorized null`).
            autoLoginError = error.isKomgaUnauthorized ? nil : Self.message(for: error, url: url)
        }
    }

    private func tryUserLogin(username: String?, password: String?) async {
        do {
            try await tryLogin(username: username, password: password)
        } catch {
            guard !Task.isCancelled else { return }
            let message = error.isKomgaUnauthorized
                ? String(localized: "Invalid credentials") : Self.message(for: error, url: url)
            fail(user: message)
        }
    }

    private func tryLogin(username: String? = nil, password: String? = nil) async throws {
        let api = session.api
        let me: KomgaUser
        if let username, let password {
            me = try await api.userApi.getMe(username: username, password: password, rememberMe: true)
        } else {
            me = try await api.userApi.getMe()
        }
        let libraries = try await api.libraryApi.getLibraries()
        session.authState.setStateValues(user: me, libraries: libraries)
        self.password = ""
        state = .success
    }

    private func fail(user message: String) {
        state = .error(message)
        userLoginError = message
    }

    static func message(for error: Error, url: String) -> String {
        if case .decoding = error as? KomgaAPIError {
            return String(localized: "Unexpected response for url \(url)")
        }
        return String(localized: "Login error: \(error.localizedDescription)")
    }
}
