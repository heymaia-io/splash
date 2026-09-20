import Foundation
import Synchronization
import Testing
@testable import SplashUI

final class FakeStoreProvider: PremiumStoreProvider {
    let entitled = Mutex(false)
    let outcome: PurchaseOutcome
    let (updates, continuation) = AsyncStream.makeStream(of: Bool.self)

    init(outcome: PurchaseOutcome = .purchased, entitled: Bool = false) {
        self.outcome = outcome
        self.entitled.withLock { $0 = entitled }
    }

    func productInfo() async throws -> PremiumProductInfo? {
        PremiumProductInfo(displayName: "Offline", displayPrice: "$3.99", description: "")
    }

    func purchase() async throws -> PurchaseOutcome {
        if outcome == .purchased { entitled.withLock { $0 = true } }
        return outcome
    }

    func hasEntitlement() async -> Bool { entitled.withLock { $0 } }
    func restore() async throws {}
    func entitlementUpdates() -> AsyncStream<Bool> { updates }
}

@MainActor
@Suite struct EntitlementTests {
    @Test func lockedByDefaultAndPaywallOnRequest() async {
        let store = PremiumEntitlementStore(provider: FakeStoreProvider())
        await store.start()
        #expect(!store.isUnlocked)
        #expect(store.product?.displayPrice == "$3.99")
        store.requestUnlock(for: .offline)
        #expect(store.isPaywallPresented)
    }

    @Test func purchaseUnlocksAndClosesPaywall() async {
        let store = PremiumEntitlementStore(provider: FakeStoreProvider())
        await store.start()
        store.requestUnlock(for: .offline)
        await store.purchase()
        #expect(store.isUnlocked)
        #expect(!store.isPaywallPresented)
    }

    @Test func pendingAndCancelledStayLocked() async {
        for outcome in [PurchaseOutcome.pending, .cancelled] {
            let store = PremiumEntitlementStore(provider: FakeStoreProvider(outcome: outcome))
            await store.start()
            await store.purchase()
            #expect(!store.isUnlocked)
        }
    }

    @Test func restoreFindsExistingPurchase() async {
        let provider = FakeStoreProvider()
        let store = PremiumEntitlementStore(provider: provider)
        await store.start()
        provider.entitled.withLock { $0 = true }
        await store.restore()
        #expect(store.isUnlocked)
    }

    /// One SKU, several features: the sheet must lead with whichever one the user actually hit.
    @Test func paywallContextFollowsTheBlockedFeature() async {
        let store = PremiumEntitlementStore(provider: FakeStoreProvider())
        await store.start()
        #expect(store.paywallContext == .offline)  // default

        store.requestUnlock(for: .privacy)
        #expect(store.paywallContext == .privacy)
        store.isPaywallPresented = false

        store.requestUnlock(for: .offline)
        #expect(store.paywallContext == .offline)
    }

    /// Two paywalls for one product must not imply two purchases, or App Review reads it as a dark pattern.
    @Test func bothPresetsSayOnePurchaseUnlocksBoth() {
        for context in [PaywallContext.offline, .privacy] {
            let subtitle = String(localized: context.subtitle)
            #expect(subtitle.contains("One purchase"))
            #expect(subtitle.contains("offline"))
            #expect(subtitle.contains("private"))
            let benefits = context.benefits.map { String(localized: $0.text) }
            #expect(benefits.contains { $0.contains("One-time purchase") })
        }
    }

    @Test func revocationLocksAgain() async throws {
        let provider = FakeStoreProvider(entitled: true)
        let store = PremiumEntitlementStore(provider: provider)
        await store.start()
        #expect(store.isUnlocked)
        provider.continuation.yield(false)  // refund
        try await waitUntil { !store.isUnlocked }
    }
}

@Suite struct LicensesTests {
    @Test func everyBundledLicenseIsPresent() {
        for entry in LicensesView.entries {
            #expect(LicensesView.text(for: entry.file).count > 200, "missing \(entry.file)")
        }
        #expect(LicensesView.text(for: "LICENSE-Komelia-Apache-2.0").contains("Apache License"))
    }
}
