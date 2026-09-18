import SplashCore
import Foundation

/// Port of `snd.komelia.ui.LoadState`.
public enum LoadState<Value> {
    case uninitialized
    case loading
    case success(Value)
    case error(Error)

    public var value: Value? {
        if case .success(let value) = self { return value }
        return nil
    }

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var isUninitialized: Bool {
        if case .uninitialized = self { return true }
        return false
    }
}

/// `reloadJobsFlow` pattern shared by every screen model: SSE events request a reload, requests are
/// conflated (buffer 1, DROP_OLDEST) and spaced by `cooldown`, and can be paused while the user is
/// interacting (`stopKomgaEventHandler` / `startKomgaEventHandler`).
@MainActor
public final class ReloadScheduler {
    private let cooldown: Duration
    private let action: @MainActor () async -> Void
    private var pending = false
    private var running = false
    public var isEnabled = true {
        didSet { if isEnabled { drain() } }
    }

    public init(cooldown: Duration, action: @escaping @MainActor () async -> Void) {
        self.cooldown = cooldown
        self.action = action
    }

    public func request() {
        pending = true
        drain()
    }

    private func drain() {
        guard isEnabled, pending, !running else { return }
        pending = false
        running = true
        Task {
            await action()
            try? await Task.sleep(for: cooldown)
            running = false
            drain()
        }
    }
}

/// Subscribes a screen model to the shared event stream for as long as the returned task lives.
@MainActor
func listen(
    to events: KomgaEventSource, _ handler: @escaping @MainActor (KomgaEventValue) -> Void
) -> Task<Void, Never> {
    let stream = events.subscribe()
    return Task {
        for await event in stream { handler(event) }
    }
}

/// [NUEVO] Reloads a screen when the private-content set changes, so hiding something takes effect without
/// leaving the screen.
///
/// **The first emission is skipped**: `SettingsState.values()` replays the current value on subscribe, and
/// `initialize()` has already loaded with it — reacting to it would double every screen's first fetch.
@MainActor
func listenHidden(
    to changes: @escaping @MainActor () -> AsyncStream<PrivacyState>, _ reload: @escaping @MainActor () async -> Void
) -> Task<Void, Never> {
    let stream = changes()
    return Task {
        var isFirst = true
        for await _ in stream {
            if isFirst { isFirst = false; continue }
            await reload()
        }
    }
}

/// The "privacy is not configured" stream: finishes immediately, so subscribers do not linger.
@MainActor
public var noHiddenChanges: AsyncStream<PrivacyState> { AsyncStream { $0.finish() } }
