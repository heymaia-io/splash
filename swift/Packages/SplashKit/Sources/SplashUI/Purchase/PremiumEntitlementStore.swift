import Foundation
import Observation
import StoreKit

/// Product sold by the app: one-time, non-consumable unlock of offline reading **and** private content.
public enum PremiumProduct {
    /// **Do not change this id.** It is registered in App Store Connect and changing it orphans every
    /// existing purchase. It still reads `.offline` because the product predates the privacy feature; the
    /// surrounding types are named `Premium*` because one purchase now unlocks both. The mismatch is
    /// deliberate, not a bug.
    public static let id = "com.heymaia.splash.offline"
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
/// private area. A refund/revocation blocks new downloads, entering offline mode and revealing private
/// content; already downloaded files are kept, and nothing that was hidden becomes visible.
@MainActor
@Observable
public final class PremiumEntitlementStore: PremiumAccessPolicy {
    public private(set) var isUnlocked = false
    public private(set) var product: PremiumProductInfo?
    public private(set) var isLoadingProduct = false
    public private(set) var isPurchasing = false
    public private(set) var message: String?
    /// Drives the paywall sheet.
    public var isPaywallPresented = false
    /// Which feature was blocked, so the sheet leads with that. Set by `requestUnlock(for:)`.
    public private(set) var paywallContext: PaywallContext = .offline

    private let provider: any PremiumStoreProvider
    private var updatesTask: Task<Void, Never>?

    public init(provider: any PremiumStoreProvider) {
        self.provider = provider
    }

    /// Call once at launch: reads the current entitlement and listens for changes.
    public func start() async {
        isUnlocked = await provider.hasEntitlement()
        if updatesTask == nil {
            let updates = provider.entitlementUpdates()
            updatesTask = Task { [weak self] in
                for await unlocked in updates { self?.isUnlocked = unlocked }
            }
        }
        await loadProduct()
    }

    public func loadProduct() async {
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        product = try? await provider.productInfo()
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

    private func loadProduct() async throws -> Product? {
        try await Product.products(for: [PremiumProduct.id]).first
    }

    public func productInfo() async throws -> PremiumProductInfo? {
        guard let product = try await loadProduct() else { return nil }
        return PremiumProductInfo(
            displayName: product.displayName, displayPrice: product.displayPrice, description: product.description)
    }

    public func purchase() async throws -> PurchaseOutcome {
        guard let product = try await loadProduct() else { throw StoreError.productUnavailable }
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
        case productUnavailable
        public var errorDescription: String? {
            String(localized: "The App Store is not available right now. Please try again later.")
        }
    }
}
