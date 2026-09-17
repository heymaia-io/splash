import Foundation
import Synchronization
import Testing
@testable import KomeliaUI

final class FakeStoreProvider: OfflineStoreProvider {
    let entitled = Mutex(false)
    let outcome: PurchaseOutcome
    let (updates, continuation) = AsyncStream.makeStream(of: Bool.self)

    init(outcome: PurchaseOutcome = .purchased, entitled: Bool = false) {
        self.outcome = outcome
        self.entitled.withLock { $0 = entitled }
    }

    func productInfo() async throws -> OfflineProductInfo? {
        OfflineProductInfo(displayName: "Offline", displayPrice: "$3.99", description: "")
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
        let store = OfflineEntitlementStore(provider: FakeStoreProvider())
        await store.start()
        #expect(!store.isUnlocked)
        #expect(store.product?.displayPrice == "$3.99")
        store.requestUnlock()
        #expect(store.isPaywallPresented)
    }

    @Test func purchaseUnlocksAndClosesPaywall() async {
        let store = OfflineEntitlementStore(provider: FakeStoreProvider())
        await store.start()
        store.requestUnlock()
        await store.purchase()
        #expect(store.isUnlocked)
        #expect(!store.isPaywallPresented)
    }

    @Test func pendingAndCancelledStayLocked() async {
        for outcome in [PurchaseOutcome.pending, .cancelled] {
            let store = OfflineEntitlementStore(provider: FakeStoreProvider(outcome: outcome))
            await store.start()
            await store.purchase()
            #expect(!store.isUnlocked)
        }
    }

    @Test func restoreFindsExistingPurchase() async {
        let provider = FakeStoreProvider()
        let store = OfflineEntitlementStore(provider: provider)
        await store.start()
        provider.entitled.withLock { $0 = true }
        await store.restore()
        #expect(store.isUnlocked)
    }

    @Test func revocationLocksAgain() async throws {
        let provider = FakeStoreProvider(entitled: true)
        let store = OfflineEntitlementStore(provider: provider)
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
