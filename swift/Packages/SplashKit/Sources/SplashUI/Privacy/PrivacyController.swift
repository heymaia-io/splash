import Foundation
import KomgaAPI
import Observation
import SplashCore
import SwiftUI

/// The one place that knows both *what* is hidden and *whether* the private area is currently unlocked.
///
/// [NUEVO] `filter()` is the single source of truth for "should I filter?". `ViewModelFactory` receives it as
/// a provider closure from the composition root and must never compute its own: an earlier version gave the
/// factory its own copy of the rule, which knew what was hidden but not that the area had been revealed — so
/// unlocking showed nothing anywhere while Settings and Downloads behaved correctly. A second copy of this
/// rule is the single most likely bug in this feature.
@MainActor
@Observable
public final class PrivacyController {
    /// **Memory only, never persisted**, so process death always re-locks.
    public private(set) var isUnlocked = false
    /// True while the system authentication sheet is up. Guards the background lock, because the passcode
    /// fallback can background the app on some configurations.
    public private(set) var isAuthenticating = false

    private let state: PrivacyStateRepository
    private let settings: CommonSettingsRepository
    private let authenticator: any DeviceAuthenticating
    private let access: (any PremiumAccessPolicy)?
    private let now: @MainActor () -> Date
    /// When the app last went to `.background` while unlocked — the clock `.afterTimeout` measures against.
    private var leftForegroundAt: Date?

    public init(
        state: PrivacyStateRepository,
        settings: CommonSettingsRepository,
        authenticator: any DeviceAuthenticating = LocalDeviceAuthenticator(),
        access: (any PremiumAccessPolicy)?,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.state = state
        self.settings = settings
        self.authenticator = authenticator
        self.access = access
        self.now = now
    }

    // MARK: - What is hidden

    /// The set for the *current* server. A Komga id only means anything on the server that issued it.
    public var hidden: HiddenContent { state.value.content(for: settings.value.serverUrl) }

    public var lockPolicy: PrivacyLockPolicy { state.value.lockPolicy }
    public var lockTimeout: TimeInterval { state.value.lockTimeout }

    /// True when the feature has anything to reveal at all, used to keep the UI honest without leaking which
    /// items are hidden.
    public var hasHiddenContent: Bool { !hidden.isEmpty }

    /// **The** filter. `.disabled` while unlocked — unlocking is "stop filtering", not "show somewhere else".
    public func filter() -> HiddenContentFilter {
        isUnlocked ? .disabled : HiddenContentFilter(hidden: hidden)
    }

    public func isHidden(libraryId: KomgaLibraryId) -> Bool { hidden.libraries.contains(libraryId) }
    public func isHidden(seriesId: KomgaSeriesId) -> Bool { hidden.series.contains(seriesId) }
    public func isHidden(bookId: KomgaBookId) -> Bool { hidden.books.contains(bookId) }

    /// Emits whenever the persisted state changes, so screens can reload themselves live.
    public func changes() -> AsyncStream<PrivacyState> { state.values() }

    // MARK: - Hiding

    public func setHidden(libraryId: KomgaLibraryId, _ hidden: Bool) async {
        await mutate { content in content.libraries.toggle(libraryId, present: hidden) }
    }

    public func setHidden(seriesId: KomgaSeriesId, _ hidden: Bool) async {
        await mutate { content in content.series.toggle(seriesId, present: hidden) }
    }

    public func setHidden(bookId: KomgaBookId, _ hidden: Bool) async {
        await mutate { content in content.books.toggle(bookId, present: hidden) }
    }

    private func mutate(_ change: @escaping @Sendable (inout HiddenContent) -> Void) async {
        let serverUrl = settings.value.serverUrl
        try? await state.update { $0.update(serverUrl, change) }
    }

    public func setLockPolicy(_ policy: PrivacyLockPolicy) async {
        try? await state.update { $0.lockPolicy = policy }
    }

    public func setLockTimeout(_ timeout: TimeInterval) async {
        try? await state.update { $0.lockTimeout = timeout }
    }

    // MARK: - Reveal

    /// Whether the gesture can do anything at all. Checked before prompting so a device with no passcode
    /// stays silent rather than showing a failing sheet.
    public func canReveal() -> Bool { authenticator.canAuthenticate() }

    /// Authenticate **before** checking the purchase.
    ///
    /// Every failure path returns silently — no alert, no toast, no haptic. A differentiated response is an
    /// oracle: it tells someone holding the device that the feature exists and that there is something to
    /// find. Checking the purchase first would leak the same way, by showing a paywall to a snooper who
    /// never authenticated.
    public func requestReveal() async {
        guard !isUnlocked, !isAuthenticating else { return }
        guard authenticator.canAuthenticate() else { return }

        isAuthenticating = true
        let reason = String(localized: "Show your private content.")
        let authenticated = await authenticator.authenticate(reason: reason)
        isAuthenticating = false

        guard authenticated else { return }

        if let access, !access.isUnlocked {
            access.requestUnlock(for: .privacy)
            return
        }

        isUnlocked = true
        leftForegroundAt = nil
    }

    /// Locks immediately. `onLock` is set by the shell to eject the user from content about to vanish.
    public func lock() {
        guard isUnlocked else { return }
        isUnlocked = false
        leftForegroundAt = nil
        onLock?()
    }

    /// Reset the navigator to Home and clear the search query: being deep inside content that is about to
    /// disappear must eject you, or you are left staring at a detail screen for an item that no longer exists
    /// in any list.
    public var onLock: (@MainActor () -> Void)?

    // MARK: - Re-lock

    /// `scenePhase` reaches `.inactive` during the Face ID prompt itself, Control Centre, notification
    /// banners and the app switcher. **Never lock on `.inactive`** — doing so locks the app mid-reveal.
    ///
    /// The `!isAuthenticating` half of the guard is defensive rather than load-bearing *today*: the app is
    /// still locked while the prompt is up, so `isUnlocked` already rejects those phase changes. It matters
    /// the moment any path authenticates while already unlocked (re-auth to unhide, say). Kept deliberately —
    /// it is one condition, and the passcode fallback really does background the app on some configurations.
    public func scenePhaseChanged(_ phase: ScenePhase) {
        guard isUnlocked, !isAuthenticating else { return }
        switch phase {
        case .background:
            switch lockPolicy {
            case .onLeaving: lock()
            case .afterTimeout: leftForegroundAt = now()
            case .untilAppQuits: break
            }
        case .active:
            // Evaluated on return, not on a timer: a suspended app would never fire one.
            if lockPolicy == .afterTimeout, let left = leftForegroundAt {
                if now().timeIntervalSince(left) >= lockTimeout { lock() } else { leftForegroundAt = nil }
            }
        default:
            break
        }
    }
}

extension Set {
    /// Insert or remove, so the three `setHidden` overloads stay one line each.
    fileprivate mutating func toggle(_ element: Element, present: Bool) {
        if present { insert(element) } else { remove(element) }
    }
}

extension EnvironmentValues {
    /// nil when privacy is not configured (previews/tests), which makes every filter a no-op.
    @Entry public var privacy: PrivacyController?
}
