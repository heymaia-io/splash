import Foundation
import KomgaAPI
import SplashCore
import SwiftUI
import Synchronization
import Testing
@testable import SplashUI

// MARK: - Doubles

@MainActor
final class FakeDeviceAuthenticator: DeviceAuthenticating {
    var hasPasscode: Bool
    var succeeds: Bool
    private(set) var authenticateCalls = 0

    init(hasPasscode: Bool = true, succeeds: Bool = true) {
        self.hasPasscode = hasPasscode
        self.succeeds = succeeds
    }

    /// Runs while the controller is inside `authenticate`, i.e. exactly while `isAuthenticating` is true —
    /// the window in which the system prompt can background the app.
    var duringPrompt: (@MainActor () -> Void)?

    func canAuthenticate() -> Bool { hasPasscode }

    func authenticate(reason: String) async -> Bool {
        authenticateCalls += 1
        duringPrompt?()
        return succeeds
    }
}

@MainActor
final class FakeAccessPolicy: PremiumAccessPolicy {
    var isUnlocked: Bool
    private(set) var requestedContexts: [PaywallContext] = []

    init(isUnlocked: Bool) { self.isUnlocked = isUnlocked }

    func requestUnlock(for context: PaywallContext) { requestedContexts.append(context) }
}

@MainActor
@Suite struct PrivacyControllerTests {
    private static let serverA = "https://a.example"
    private static let serverB = "https://b.example"

    /// A clock the test drives by hand, so `.afterTimeout` never depends on real elapsed time.
    private final class TestClock: @unchecked Sendable {
        var now = Date(timeIntervalSince1970: 1_000)
        func advance(_ seconds: TimeInterval) { now.addingTimeInterval(seconds) }
    }

    private func make(
        serverUrl: String = serverA,
        hasPasscode: Bool = true,
        authSucceeds: Bool = true,
        entitled: Bool = true,
        state: PrivacyState = PrivacyState()
    ) -> (PrivacyController, FakeDeviceAuthenticator, FakeAccessPolicy, Box<Date>) {
        var settings = AppSettings()
        settings.serverUrl = serverUrl
        let settingsState = CommonSettingsRepository(initial: settings, save: { _ in })
        let privacyState = PrivacyStateRepository(initial: state, save: { _ in })
        let auth = FakeDeviceAuthenticator(hasPasscode: hasPasscode, succeeds: authSucceeds)
        let access = FakeAccessPolicy(isUnlocked: entitled)
        let clock = Box(Date(timeIntervalSince1970: 1_000))
        let controller = PrivacyController(
            state: privacyState, settings: settingsState, authenticator: auth, access: access,
            now: { clock.value })
        return (controller, auth, access, clock)
    }

    final class Box<T>: @unchecked Sendable {
        var value: T
        init(_ value: T) { self.value = value }
    }

    // MARK: - Reveal

    @Test func startsLocked() {
        let (controller, _, _, _) = make()
        #expect(!controller.isUnlocked)
    }

    /// Any differentiated response to a failed unlock is an oracle telling a snooper the feature exists.
    @Test func failedAuthLeavesItLockedAndDoesNotPresentThePaywall() async {
        let (controller, auth, access, _) = make(authSucceeds: false, entitled: false)
        await controller.requestReveal()
        #expect(!controller.isUnlocked)
        #expect(auth.authenticateCalls == 1)
        #expect(access.requestedContexts.isEmpty)
        #expect(!controller.isAuthenticating)
    }

    /// Authenticate *before* checking the purchase, or the paywall itself becomes the oracle.
    @Test func authWithoutEntitlementPresentsThePrivacyPaywall() async {
        let (controller, auth, access, _) = make(entitled: false)
        await controller.requestReveal()
        #expect(!controller.isUnlocked)
        #expect(auth.authenticateCalls == 1)
        #expect(access.requestedContexts == [.privacy])
    }

    @Test func noPasscodeNeverCallsAuthenticate() async {
        let (controller, auth, access, _) = make(hasPasscode: false)
        #expect(!controller.canReveal())
        await controller.requestReveal()
        #expect(auth.authenticateCalls == 0)
        #expect(access.requestedContexts.isEmpty)
        #expect(!controller.isUnlocked)
    }

    @Test func successfulRevealUnlocks() async {
        let (controller, _, _, _) = make()
        await controller.requestReveal()
        #expect(controller.isUnlocked)
    }

    @Test func lockEjectsTheUser() async {
        let (controller, _, _, _) = make()
        var ejected = 0
        controller.onLock = { ejected += 1 }
        await controller.requestReveal()
        controller.lock()
        #expect(!controller.isUnlocked)
        #expect(ejected == 1)
        controller.lock()  // already locked — must not fire again
        #expect(ejected == 1)
    }

    // MARK: - Hiding is available while locked

    /// Hiding is the common action, so it must not cost a Face ID prompt first. It is gated on the purchase
    /// only — never on `isUnlocked`.
    @Test func canHideWhileLockedWithTheEntitlement() async {
        let (controller, auth, _, _) = make(entitled: true)
        #expect(!controller.isUnlocked)
        #expect(controller.canHide)
        #expect(auth.authenticateCalls == 0)  // offering Hide must not prompt

        await controller.setHidden(seriesId: KomgaSeriesId("s1"), true)
        #expect(controller.isHidden(seriesId: KomgaSeriesId("s1")))
        // Still locked, so it takes effect immediately.
        #expect(controller.filter().hidden.series == [KomgaSeriesId("s1")])
    }

    /// Without the purchase the action never appears, locked or not.
    @Test func cannotHideWithoutTheEntitlement() async {
        let (controller, _, _, _) = make(entitled: false)
        #expect(!controller.canHide)
        await controller.requestReveal()
        #expect(!controller.canHide)
    }

    @Test func canHideStaysTrueOnceUnlocked() async {
        let (controller, _, _, _) = make(entitled: true)
        await controller.requestReveal()
        #expect(controller.isUnlocked)
        #expect(controller.canHide)
    }

    // MARK: - §2.1 regression: one source of truth

    /// `filter()` must return `.disabled` while unlocked. When this regressed, unlocking revealed nothing
    /// anywhere, because the screens held a copy of the rule that knew what was hidden but not that it had
    /// been revealed.
    @Test func filterIsDisabledWhileUnlocked() async {
        var state = PrivacyState()
        state.update(Self.serverA) { $0.series.insert(KomgaSeriesId("s1")) }
        let (controller, _, _, _) = make(state: state)

        #expect(controller.filter().hidden.series == [KomgaSeriesId("s1")])
        #expect(!controller.filter().isNoop)

        await controller.requestReveal()
        #expect(controller.filter() == .disabled)
        #expect(controller.filter().isNoop)

        controller.lock()
        #expect(controller.filter().hidden.series == [KomgaSeriesId("s1")])
    }

    /// The factory's provider must track the controller, not snapshot it.
    @Test func viewModelFactoryFilterTracksTheController() async {
        var state = PrivacyState()
        state.update(Self.serverA) { $0.libraries.insert(KomgaLibraryId("lib-a")) }
        let (controller, _, _, _) = make(state: state)

        // Exactly the closure the composition root installs.
        let provider: @MainActor () -> HiddenContentFilter = { [unowned controller] in controller.filter() }

        #expect(provider().hidden.libraries == [KomgaLibraryId("lib-a")])
        await controller.requestReveal()
        #expect(provider() == .disabled)
        controller.lock()
        #expect(provider().hidden.libraries == [KomgaLibraryId("lib-a")])
    }

    /// Hiding something while unlocked is still invisible to `filter()`, and becomes effective on lock.
    @Test func hidingWhileUnlockedTakesEffectOnLock() async {
        let (controller, _, _, _) = make()
        await controller.requestReveal()
        await controller.setHidden(bookId: KomgaBookId("b1"), true)

        #expect(controller.isHidden(bookId: KomgaBookId("b1")))
        #expect(controller.filter() == .disabled)  // still revealed

        controller.lock()
        #expect(controller.filter().hidden.books == [KomgaBookId("b1")])
    }

    // MARK: - §2.2 regression: hidden ids are keyed by server

    /// Hide on A, switch to B → nothing hidden; hide on B → A untouched; switch back → A intact.
    @Test func hiddenIdsAreIsolatedPerServer() async {
        var settings = AppSettings()
        settings.serverUrl = Self.serverA
        let settingsState = CommonSettingsRepository(initial: settings, save: { _ in })
        let privacyState = PrivacyStateRepository(initial: PrivacyState(), save: { _ in })
        let controller = PrivacyController(
            state: privacyState, settings: settingsState,
            authenticator: FakeDeviceAuthenticator(), access: FakeAccessPolicy(isUnlocked: true))

        await controller.setHidden(seriesId: KomgaSeriesId("a-series"), true)
        #expect(controller.hidden.series == [KomgaSeriesId("a-series")])

        // Switch to B.
        try? await settingsState.set(\.serverUrl, Self.serverB)
        #expect(controller.hidden.isEmpty)

        await controller.setHidden(seriesId: KomgaSeriesId("b-series"), true)
        #expect(controller.hidden.series == [KomgaSeriesId("b-series")])

        // Back to A — untouched by everything that happened on B.
        try? await settingsState.set(\.serverUrl, Self.serverA)
        #expect(controller.hidden.series == [KomgaSeriesId("a-series")])
        #expect(privacyState.value.byServer.count == 2)
    }

    @Test func unhidingTheLastItemDropsTheServerEntry() async {
        let (controller, _, _, _) = make()
        await controller.setHidden(bookId: KomgaBookId("b1"), true)
        await controller.setHidden(bookId: KomgaBookId("b1"), false)
        #expect(controller.hidden.isEmpty)
        #expect(!controller.hasHiddenContent)
    }

    // MARK: - Re-lock

    /// `.inactive` arrives during the Face ID prompt itself, Control Centre and the app switcher.
    @Test func onLeavingLocksOnBackgroundButNotOnInactive() async {
        var state = PrivacyState()
        state.lockPolicy = .onLeaving
        let (controller, _, _, _) = make(state: state)
        await controller.requestReveal()

        controller.scenePhaseChanged(.inactive)
        #expect(controller.isUnlocked)

        controller.scenePhaseChanged(.background)
        #expect(!controller.isUnlocked)
    }

    @Test func untilAppQuitsNeverLocks() async {
        var state = PrivacyState()
        state.lockPolicy = .untilAppQuits
        let (controller, _, _, _) = make(state: state)
        await controller.requestReveal()

        controller.scenePhaseChanged(.inactive)
        controller.scenePhaseChanged(.background)
        controller.scenePhaseChanged(.active)
        #expect(controller.isUnlocked)
    }

    @Test func afterTimeoutRespectsTheClock() async {
        var state = PrivacyState()
        state.lockPolicy = .afterTimeout
        state.lockTimeout = 300
        let (controller, _, _, clock) = make(state: state)
        await controller.requestReveal()

        // Away for less than the timeout → still unlocked.
        controller.scenePhaseChanged(.background)
        clock.value = clock.value.addingTimeInterval(120)
        controller.scenePhaseChanged(.active)
        #expect(controller.isUnlocked)

        // Away for longer → locked on return, not on a timer a suspended app would miss.
        controller.scenePhaseChanged(.background)
        clock.value = clock.value.addingTimeInterval(301)
        controller.scenePhaseChanged(.active)
        #expect(!controller.isUnlocked)
    }

    /// The passcode fallback backgrounds the app on some configurations. A `.background` arriving while the
    /// prompt is up must not leave residue that locks the user out the instant they finish authenticating.
    ///
    /// Note this passes with or without the `!isAuthenticating` guard, because the app is still locked while
    /// the prompt is up and `isUnlocked` already rejects the phase change. It pins the user-visible outcome,
    /// not that one condition — see the comment on `scenePhaseChanged`.
    @Test func aBackgroundDuringThePromptDoesNotBreakTheReveal() async {
        var state = PrivacyState()
        state.lockPolicy = .afterTimeout
        state.lockTimeout = 300
        let (controller, auth, _, clock) = make(state: state)

        auth.duringPrompt = { [unowned controller] in
            #expect(controller.isAuthenticating)
            controller.scenePhaseChanged(.background)  // the passcode sheet backgrounding the app
        }
        await controller.requestReveal()
        #expect(controller.isUnlocked)

        // Coming back must not lock: the mid-prompt `.background` was ignored, so no absence was recorded.
        clock.value = clock.value.addingTimeInterval(3_600)
        controller.scenePhaseChanged(.active)
        #expect(controller.isUnlocked)
    }

    /// The same, under `.onLeaving` — the policy that locks most eagerly.
    @Test func onLeavingSurvivesABackgroundDuringThePrompt() async {
        var state = PrivacyState()
        state.lockPolicy = .onLeaving
        let (controller, auth, _, _) = make(state: state)

        auth.duringPrompt = { [unowned controller] in controller.scenePhaseChanged(.background) }
        await controller.requestReveal()
        #expect(controller.isUnlocked)
    }
}
