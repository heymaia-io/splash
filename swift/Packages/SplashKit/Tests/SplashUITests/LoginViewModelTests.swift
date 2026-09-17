import Foundation
import Testing
@testable import SplashCore
@testable import SplashUI
@testable import KomgaAPI
@testable import KomgaRemote

/// Minimal `LoginSession` over the real remote API + fixture server (no Keychain, no DB).
@MainActor
final class TestSession: LoginSession {
    let settings: CommonSettingsRepository
    let authState = KomgaAuthenticationState()
    let api: any KomgaApi
    let secrets = InMemorySecretsRepository()
    let apiKeys: ApiKeyStore
    var switchedTo: [String] = []

    init(serverURL: URL, storedSession: Bool = false) {
        var initial = AppSettings()
        initial.serverUrl = serverURL.absoluteString
        settings = SettingsState(initial: initial) { _ in }
        let apiKeys = ApiKeyStore(secrets: secrets)
        self.apiKeys = apiKeys
        let cookies = KomgaCookieStore(serverURL: { serverURL }, persistence: nil)
        api = RemoteKomgaApi(http: KomgaHTTPClient(baseURL: { serverURL }, apiKey: { apiKeys.apiKey }, cookieStore: cookies))
        hasSession = storedSession
    }

    var hasSession: Bool
    func hasStoredSession(serverURL: String) async -> Bool { hasSession }
    func switchServer(to serverURL: String) async { switchedTo.append(serverURL) }
    func storeApiKey(_ apiKey: String, serverURL: String) async throws {
        try await apiKeys.setApiKey(apiKey, serverURL: serverURL)
    }
}

@MainActor
@Suite(.enabled(if: FixtureAvailability.isAvailable), .serialized)
struct LoginViewModelTests {
    let url = URL(string: "http://localhost:25601")!

    @Test func withoutStoredSessionShowsFormPrefilledWithLastServer() async {
        let model = LoginViewModel(session: TestSession(serverURL: url))
        await model.initialize()
        // After a logout the cookie is gone but the server URL is kept, so the form comes back filled in.
        #expect(model.url == url.absoluteString)
        #expect(model.autoLoginError == nil)
        if case .error = model.state {} else { Issue.record("expected error state, got \(model.state)") }
    }

    @Test func credentialsLoginPopulatesAuthState() async throws {
        let session = TestSession(serverURL: url)
        let model = LoginViewModel(session: session)
        await model.initialize()
        model.url = "localhost:25601/"
        model.user = "admin@fixture.local"
        model.password = "fixture-password"
        model.loginWithCredentials()
        try await waitUntil { model.state != .loading }

        #expect(model.state == .success)
        #expect(model.url == "http://localhost:25601")
        #expect(session.switchedTo == ["http://localhost:25601"])
        #expect(session.settings.value.username == "admin@fixture.local")
        #expect(session.authState.state == .loaded)
        #expect(session.authState.libraries.count >= 3)
        #expect(model.password.isEmpty)
    }

    @Test func wrongPasswordReportsInvalidCredentials() async throws {
        let model = LoginViewModel(session: TestSession(serverURL: url))
        model.url = "http://localhost:25601"
        model.user = "admin@fixture.local"
        model.password = "nope"
        model.loginWithCredentials()
        try await waitUntil { model.state != .loading }
        #expect(model.userLoginError == String(localized: "Invalid credentials"))
    }

    @Test func autoLoginUnauthorizedFallsBackToFormSilently() async throws {
        let model = LoginViewModel(session: TestSession(serverURL: url, storedSession: true))
        await model.initialize()
        #expect(model.autoLoginError == nil)  // 401 => just show the form
        if case .error = model.state {} else { Issue.record("expected error state") }
    }

    @Test func invalidURLIsRejectedBeforeNetwork() async throws {
        let session = TestSession(serverURL: url)
        let model = LoginViewModel(session: session)
        model.url = "   "
        model.loginWithCredentials()
        try await waitUntil { model.state != .loading }
        #expect(model.userLoginError == String(localized: "Invalid server URL"))
        #expect(session.switchedTo.isEmpty)
    }
}

enum FixtureAvailability {
    static let isAvailable: Bool = {
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var ok = false
        var request = URLRequest(url: URL(string: "http://localhost:25601/api/v1/claim")!)
        request.timeoutInterval = 2
        URLSession.shared.dataTask(with: request) { _, response, _ in
            ok = (response as? HTTPURLResponse)?.statusCode == 200
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return ok
    }()
}

@MainActor
func waitUntil(timeout: Duration = .seconds(10), _ condition: @MainActor () -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else { throw TimeoutError() }
        try await Task.sleep(for: .milliseconds(20))
    }
}
