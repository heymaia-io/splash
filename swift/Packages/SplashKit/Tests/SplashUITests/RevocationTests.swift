import Foundation
import KomgaAPI
import SplashCore
import Testing
@testable import SplashUI

/// What happens when Apple takes the purchase back (refund, chargeback, family sharing removal).
///
/// Two rules are fixed here because both are easy to break by accident and expensive to get wrong:
///
/// 1. Downloaded files stay readable. A refund must not reach into someone's disk and delete their library.
/// 2. Hidden content is revealed. Leaving it hidden while the reveal gesture is gated behind the very
///    purchase that was revoked would lock a customer out of their own content permanently.
@MainActor
@Suite struct RevocationTests {
    private static let serverA = "https://a.example"
    private static let serverB = "https://b.example"

    private func makePrivacy(
        serverUrl: String = serverA,
        state: PrivacyState = PrivacyState(),
        entitled: Bool = true
    ) -> (PrivacyController, PrivacyStateRepository) {
        var settings = AppSettings()
        settings.serverUrl = serverUrl
        let settingsState = CommonSettingsRepository(initial: settings, save: { _ in })
        let privacyState = PrivacyStateRepository(initial: state, save: { _ in })
        let controller = PrivacyController(
            state: privacyState,
            settings: settingsState,
            authenticator: FakeDeviceAuthenticator(),
            access: FakeAccessPolicy(isUnlocked: entitled))
        return (controller, privacyState)
    }

    private func stateWithHidden(on servers: [String]) -> PrivacyState {
        var state = PrivacyState()
        for server in servers {
            state.update(server) { $0.series.insert(KomgaSeriesId("s-1")) }
        }
        return state
    }

    // MARK: - Privacy is revealed

    @Test func revocationRevealsHiddenContent() async {
        let (privacy, _) = makePrivacy(state: stateWithHidden(on: [Self.serverA]), entitled: false)
        #expect(privacy.hasHiddenContent)

        await privacy.revealAllAfterRevocation()

        #expect(!privacy.hasHiddenContent)
        #expect(!privacy.isHidden(seriesId: KomgaSeriesId("s-1")))
        #expect(privacy.filter() == .disabled)
    }

    /// The entitlement belongs to the Apple Account, not to a Komga server, so a per-server reveal would
    /// leave the same lock-out trap waiting on every other server the user signs into.
    @Test func revocationRevealsEveryServerNotJustTheCurrentOne() async {
        let (privacy, repo) = makePrivacy(
            serverUrl: Self.serverA,
            state: stateWithHidden(on: [Self.serverA, Self.serverB]),
            entitled: false)

        await privacy.revealAllAfterRevocation()

        #expect(repo.value.byServer.isEmpty)
    }

    @Test func revealDropsTheUnlockedSessionBecauseThereIsNothingLeftToUnlockInto() async {
        let (privacy, _) = makePrivacy(state: stateWithHidden(on: [Self.serverA]))
        await privacy.requestReveal()
        #expect(privacy.isUnlocked)

        await privacy.revealAllAfterRevocation()

        #expect(!privacy.isUnlocked)
    }

    // MARK: - The notice is shown exactly once

    @Test func revealRaisesTheNoticeOnce() async {
        let (privacy, _) = makePrivacy(state: stateWithHidden(on: [Self.serverA]), entitled: false)

        await privacy.revealAllAfterRevocation()
        #expect(privacy.didRevealAfterRevocation)

        privacy.acknowledgeRevocationReveal()
        #expect(!privacy.didRevealAfterRevocation)

        // Nothing is hidden any more, so a second pass (next launch, still unentitled) must stay silent
        // rather than re-announcing a reveal that already happened.
        await privacy.revealAllAfterRevocation()
        #expect(!privacy.didRevealAfterRevocation)
    }

    /// Someone who never bought anything has nothing hidden, so the unentitled path must be a no-op for
    /// them — not an alert about content they never had.
    @Test func noNoticeWhenThereWasNothingHidden() async {
        let (privacy, _) = makePrivacy(entitled: false)

        await privacy.revealAllAfterRevocation()

        #expect(!privacy.didRevealAfterRevocation)
    }

    // MARK: - Offline stays gated, downloads stay readable

    /// The precondition every offline gate reads. `OfflineController.gated(_:)` and `goOffline(_:)` consult
    /// `access.isUnlocked`, so a store that still reported `true` after a refund would reopen all of them at
    /// once; deleting and cancelling stay open regardless, on purpose, because a refund must tidy up nothing
    /// on the user's disk.
    @Test func revokedEntitlementReportsLocked() async {
        let entitled = PremiumEntitlementStore(provider: FakeStoreProvider(entitled: true))
        await entitled.start()
        #expect(entitled.isUnlocked)

        let revoked = PremiumEntitlementStore(provider: FakeStoreProvider(entitled: false))
        await revoked.start()
        #expect(!revoked.isUnlocked)
    }

    /// The composition root wires this callback to the privacy reveal; the store itself must fire it both
    /// at launch (revocation while the app was closed) and on a live update.
    @Test func absentEntitlementAtLaunchFiresTheHook() async {
        let store = PremiumEntitlementStore(provider: FakeStoreProvider(entitled: false))
        var fired = 0
        store.onEntitlementAbsent = { fired += 1 }

        await store.start()

        #expect(fired == 1)
    }

    @Test func entitlementPresentAtLaunchDoesNotFireTheHook() async {
        let store = PremiumEntitlementStore(provider: FakeStoreProvider(entitled: true))
        var fired = 0
        store.onEntitlementAbsent = { fired += 1 }

        await store.start()

        #expect(fired == 0)
    }
}
