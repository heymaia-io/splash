import Foundation
import SplashCore
import KomgaAPI
import Observation
import SwiftUI

/// Owns the private area's lock state and the hidden set.
///
/// `isUnlocked` is deliberately memory-only and never persisted: killing the app must always re-lock,
/// and that falls out for free if nothing writes it to disk.
@MainActor
@Observable
public final class PrivacyController {
    public private(set) var isUnlocked = false
    /// Mirror of the repository so views can ask "is this hidden?" synchronously while building a menu.
    public private(set) var hidden = HiddenContent()
    /// True while a device-authentication prompt is on screen — see `scenePhaseChanged`.
    public private(set) var isAuthenticating = false

    private let repository: HiddenContentRepository
    private let settings: CommonSettingsRepository
    private let auth: any DeviceAuthenticating
    private let access: any PremiumAccessPolicy
    private let now: @MainActor () -> Date
    private var leftForegroundAt: Date?
    private var mirrorTask: Task<Void, Never>?

    public init(
        repository: HiddenContentRepository,
        settings: CommonSettingsRepository,
        auth: any DeviceAuthenticating,
        access: any PremiumAccessPolicy,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.repository = repository
        self.settings = settings
        self.auth = auth
        self.access = access
        self.now = now
        hidden = repository.value
        mirrorTask = Task { [weak self] in
            for await value in repository.values() { self?.hidden = value }
        }
    }

    public var lockPolicy: PrivacyLockPolicy { hidden.lockPolicy }
    public var lockTimeout: TimeInterval { hidden.lockTimeout }

    /// The filter every ordinary screen uses. Returns `.disabled` when the hidden set belongs to a
    /// different server, so ids can never be applied to content they were not recorded against.
    public func filter(_ mode: HiddenContentMode = .excludeHidden) -> HiddenContentFilter {
        guard hidden.applies(to: settings.value.serverUrl) else { return .disabled }
        return HiddenContentFilter(hidden: hidden, mode: mode)
    }

    // MARK: - Reveal

    /// The hidden gesture's handler.
    ///
    /// Order matters and is the feature's whole security story: authenticate *before* consulting the
    /// purchase, and stay completely silent on any failure. A user without the purchase who stumbles
    /// onto the gesture learns nothing — no alert, no haptic, no paywall. Any differentiated response
    /// would be an oracle that reveals the feature exists.
    public func requestReveal() async {
        guard !isUnlocked else { return }
        guard auth.canAuthenticate() else { return }

        isAuthenticating = true
        let authenticated = await auth.authenticate(reason: String(localized: "Unlock Splash"))
        isAuthenticating = false
        guard authenticated else { return }

        guard access.isUnlocked else {
            access.requestUnlock(for: .privacy)
            return
        }
        isUnlocked = true
    }

    public func lock() {
        isUnlocked = false
    }

    // MARK: - Hiding

    public func isHidden(libraryId: KomgaLibraryId) -> Bool { hidden.libraries.contains(libraryId) }
    public func isHidden(seriesId: KomgaSeriesId) -> Bool { hidden.series.contains(seriesId) }
    public func isHidden(bookId: KomgaBookId) -> Bool { hidden.books.contains(bookId) }

    public func setHidden(_ isHidden: Bool, libraryId: KomgaLibraryId) async {
        await mutate { if isHidden { $0.libraries.insert(libraryId) } else { $0.libraries.remove(libraryId) } }
    }

    public func setHidden(_ isHidden: Bool, seriesId: KomgaSeriesId) async {
        await mutate { if isHidden { $0.series.insert(seriesId) } else { $0.series.remove(seriesId) } }
    }

    public func setHidden(_ isHidden: Bool, bookId: KomgaBookId) async {
        await mutate { if isHidden { $0.books.insert(bookId) } else { $0.books.remove(bookId) } }
    }

    public func setLockPolicy(_ policy: PrivacyLockPolicy) async {
        await mutate { $0.lockPolicy = policy }
    }

    public func setLockTimeout(_ timeout: TimeInterval) async {
        await mutate { $0.lockTimeout = timeout }
    }

    private func mutate(_ change: @escaping @Sendable (inout HiddenContent) -> Void) async {
        // Stamp the server these ids belong to, so they are never applied to a different one.
        let serverUrl = settings.value.serverUrl
        try? await repository.update { content in
            change(&content)
            content.serverUrl = serverUrl
        }
        hidden = repository.value
    }

    // MARK: - Re-locking

    /// `scenePhase` reaches `.inactive` during the authentication prompt itself, Control Centre pulls,
    /// notification banners and the app-switcher preview — locking there would fight the very prompt that
    /// unlocks the area. Only `.background` counts as "the user left".
    public func scenePhaseChanged(_ phase: ScenePhase) {
        guard isUnlocked || leftForegroundAt != nil else { return }
        switch phase {
        case .background:
            // The passcode fallback can background the app on some configurations; don't lock ourselves out
            // mid-authentication.
            guard !isAuthenticating else { return }
            leftForegroundAt = now()
            if lockPolicy == .onLeaving { lock() }
        case .active:
            // Evaluated on return rather than by a timer: a suspended app would never fire one.
            if lockPolicy == .afterTimeout, let left = leftForegroundAt,
               now().timeIntervalSince(left) >= lockTimeout {
                lock()
            }
            leftForegroundAt = nil
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}

extension EnvironmentValues {
    /// nil when the privacy feature is not configured (previews/tests).
    @Entry public var privacy: PrivacyController?
}
