import Foundation
import Observation
import StoreKit

/// Product sold by the app: one-time, non-consumable unlock of offline reading **and** private content.
public enum PremiumProduct {
    /// **Do not change this id once the app has shipped.** From the first release on, it is registered in
    /// App Store Connect and changing it orphans every existing purchase. It still reads `.offline` because
    /// the product predates the privacy feature; the surrounding types are named `Premium*` because one
    /// purchase now unlocks both. The mismatch is deliberate, not a bug.
    public static let id = "io.heymaia.splash.offline"
}

/// What the entitlement store needs from the App Store (Strategy/Adapter — StoreKit in the app, fake in tests).
public protocol PremiumStoreProvider: Sendable {
    /// Localized price and name, nil when the product can't be loaded (no network, misconfiguration).
    func productInfo() async throws -> PremiumProductInfo?
    func purchase() async throws -> PurchaseOutcome
    /// Current verified entitlement (`Transaction.currentEntitlements`), ignoring revoked transactions.
    func hasEntitlement() async -> Bool
    /// `AppStore.sync()` — required "Restore purchases".
    func restore() async throws
    /// Entitlement changes arriving outside the purchase flow (`Transaction.updates`: refunds, Ask to Buy,
    /// purchases on other devices).
    func entitlementUpdates() -> AsyncStream<Bool>
}

public struct PremiumProductInfo: Sendable, Equatable {
    public let displayName: String
    public let displayPrice: String
    public let description: String

    public init(displayName: String, displayPrice: String, description: String) {
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.description = description
    }
}

public enum PurchaseOutcome: Sendable, Equatable {
    case purchased
    case pending  // Ask to Buy / SCA
    case cancelled
}

/// Observable entitlement state + the `PremiumAccessPolicy` gate used by downloads, offline mode and the
/// private area.
///
/// A refund/revocation blocks new downloads and entering offline mode; already downloaded files are kept and
/// stay readable, because a refund should not delete anyone's files. Hidden content is *revealed* rather
/// than stranded: leaving it hidden with the reveal gesture gated would lock a paying-then-refunded customer
/// out of their own library permanently. That reveal is wired by the composition root through
/// `onEntitlementAbsent` — this type deliberately knows nothing about privacy.
@MainActor
@Observable
public final class PremiumEntitlementStore: PremiumAccessPolicy {
    public private(set) var isUnlocked = false
    public private(set) var product: PremiumProductInfo?
    public private(set) var isLoadingProduct = false
    public private(set) var isPurchasing = false
    public private(set) var message: String?
    /// Why `product` is nil, when it is. Drives the paywall's disabled state.
    public private(set) var productLoadFailure: (any Error)?
    /// Nothing can be bought without a product, so the buy button must not pretend otherwise.
    public var canPurchase: Bool { product != nil }
    /// Drives the paywall sheet.
    public var isPaywallPresented = false
    /// Which feature was blocked, so the sheet leads with that. Set by `requestUnlock(for:)`.
    public private(set) var paywallContext: PaywallContext = .offline

    /// Called whenever the App Store has been asked and answered that there is **no** entitlement — at
    /// launch and on every later revocation. Never fired from the `false` default before `start()` has
    /// asked, so nothing acts on a state we have not actually confirmed.
    ///
    /// Wired in `AppModule.makeDefaultWithStore()`; see the note there about the debug bypass.
    public var onEntitlementAbsent: (@MainActor () async -> Void)?

    private let provider: any PremiumStoreProvider
    private var updatesTask: Task<Void, Never>?

    public init(provider: any PremiumStoreProvider) {
        self.provider = provider
    }

    /// Call once at launch: reads the current entitlement and listens for changes.
    public func start() async {
        isUnlocked = await provider.hasEntitlement()
        if !isUnlocked { await onEntitlementAbsent?() }
        if updatesTask == nil {
            let updates = provider.entitlementUpdates()
            updatesTask = Task { [weak self] in
                for await unlocked in updates {
                    self?.isUnlocked = unlocked
                    if !unlocked { await self?.onEntitlementAbsent?() }
                }
            }
        }
        await loadProduct()
    }

    public func loadProduct() async {
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            product = try await provider.productInfo()
            productLoadFailure = nil
        } catch {
            product = nil
            productLoadFailure = error
            // The whole point of D8: a `try?` here made a misconfigured product indistinguishable from a
            // flaky network, in the one situation where the developer most needs to know which it is.
            if let store = error as? StoreKitPremiumProvider.StoreError {
                print("[Splash] paywall: \(store.diagnosticDescription)")
            } else {
                print("[Splash] paywall: could not load product — \(error)")
            }
        }
    }

    public func requestUnlock(for context: PaywallContext) {
        message = nil
        paywallContext = context
        isPaywallPresented = true
    }

    public func purchase() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await provider.purchase() {
            case .purchased:
                isUnlocked = true
                isPaywallPresented = false
            case .pending:
                message = String(localized: "Your purchase is pending approval.")
            case .cancelled:
                break
            }
        } catch {
            message = error.localizedDescription
        }
    }

    public func restore() async {
        do {
            try await provider.restore()
            isUnlocked = await provider.hasEntitlement()
            if isUnlocked {
                isPaywallPresented = false
            } else {
                message = String(localized: "No previous purchase was found for this Apple Account.")
            }
        } catch {
            message = error.localizedDescription
        }
    }
}

// MARK: - StoreKit 2 implementation

public struct StoreKitPremiumProvider: PremiumStoreProvider {
    public init() {}

    private func loadProduct() async throws -> Product {
        let products: [Product]
        do {
            products = try await Product.products(for: [PremiumProduct.id])
        } catch {
            throw StoreError.storeUnreachable(underlying: error)
        }
        // An empty list is not an error to StoreKit, so it has to become one here or it degrades into a
        // priceless paywall with no explanation anywhere.
        guard let product = products.first else { throw StoreError.productNotConfigured }
        return product
    }

    public func productInfo() async throws -> PremiumProductInfo? {
        let product = try await loadProduct()
        return PremiumProductInfo(
            displayName: product.displayName, displayPrice: product.displayPrice, description: product.description)
    }

    public func purchase() async throws -> PurchaseOutcome {
        let product = try await loadProduct()
        switch try await product.purchase() {
        case .success(let verification):
            let transaction = try Self.verified(verification)
            await transaction.finish()
            return transaction.revocationDate == nil ? .purchased : .cancelled
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    public func hasEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == PremiumProduct.id,
               transaction.revocationDate == nil
            {
                return true
            }
        }
        return false
    }

    public func restore() async throws {
        try await AppStore.sync()
    }

    public func entitlementUpdates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    guard case .verified(let transaction) = result, transaction.productID == PremiumProduct.id
                    else { continue }
                    await transaction.finish()
                    continuation.yield(await hasEntitlement())
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Only locally verified (JWS) transactions count.
    static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified(_, let error): throw error
        }
    }

    public enum StoreError: LocalizedError {
        /// The App Store answered, but with no product for `PremiumProduct.id`. In practice that is never a
        /// network problem: the id does not exist in App Store Connect, or the Paid Apps agreement is not
        /// signed, or the build's bundle id does not match the one the product belongs to. Kept separate
        /// from a transport failure so the message does not blame the customer's connection for a
        /// configuration mistake that only the developer can fix.
        case productNotConfigured
        /// Could not reach the App Store at all.
        case storeUnreachable(underlying: any Error)

        public var errorDescription: String? {
            switch self {
            case .productNotConfigured:
                String(localized: "This purchase is not available right now. Please try again later.")
            case .storeUnreachable:
                String(localized: "The App Store is not available right now. Please try again later.")
            }
        }

        /// What goes in a log, not in front of a customer.
        public var diagnosticDescription: String {
            switch self {
            case .productNotConfigured:
                """
                No App Store product for id '\(PremiumProduct.id)'. Check that the in-app purchase exists in \
                App Store Connect with exactly that id, that the Paid Apps agreement is signed, and that the \
                bundle id matches.
                """
            case .storeUnreachable(let underlying):
                "Could not reach the App Store: \(underlying)"
            }
        }
    }
}
