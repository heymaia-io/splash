import Foundation
import Observation
import StoreKit
import SwiftUI

/// The single product sold by the app: a one-time, non-consumable unlock. It gates offline reading *and*
/// private libraries — one purchase, both features.
public enum PremiumProduct {
    /// Still `…splash.offline` even though the product is no longer offline-only: this identifier is
    /// registered in App Store Connect, and changing it would orphan every purchase already made.
    public static let id = "com.heymaia.splash.offline"
}

/// Which feature asked for the unlock. One product is sold, but the pitch has to speak the user's terms —
/// someone who just tried to download a book is not looking at a privacy pitch.
// `@MainActor` rather than `Sendable`: `LocalizedStringKey` is not `Sendable`, and the paywall
// only ever runs on the main actor anyway.
@MainActor
public struct PaywallContext: Identifiable {
    /// Stable identity for diffing and tests — the copy itself is not comparable
    /// (`LocalizedStringKey` equality is not available off the main actor).
    public let id: String
    public let icon: String
    public let title: LocalizedStringKey
    public let subtitle: LocalizedStringKey
    public let benefits: [PaywallBenefit]

    public static let offline = PaywallContext(
        id: "offline",
        icon: "arrow.down.circle.fill",
        title: "Read offline",
        subtitle: "Reading online stays free and unlimited. One purchase unlocks offline reading and private libraries, for good.",
        benefits: [
            PaywallBenefit(icon: "books.vertical", text: "Download books and whole series"),
            PaywallBenefit(icon: "airplane", text: "Read comics, PDFs and EPUBs without a connection"),
            PaywallBenefit(icon: "arrow.triangle.2.circlepath", text: "Progress syncs back when you are online"),
            PaywallBenefit(icon: "lock", text: "Keep chosen libraries private, behind Face ID"),
        ])

    public static let privacy = PaywallContext(
        id: "privacy",
        icon: "lock.circle.fill",
        title: "Private libraries",
        subtitle: "One purchase unlocks private libraries and offline reading, for good. No subscription.",
        benefits: [
            PaywallBenefit(icon: "eye.slash", text: "Hide a library, a series or a single book"),
            PaywallBenefit(icon: "magnifyingglass", text: "Hidden content stays out of search and every listing"),
            PaywallBenefit(icon: "faceid", text: "Reachable only after Face ID, Touch ID or your passcode"),
            PaywallBenefit(icon: "arrow.down.circle", text: "Also unlocks downloads and offline reading"),
        ])

    public init(
        id: String, icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey,
        benefits: [PaywallBenefit]
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.benefits = benefits
    }
}

public struct PaywallBenefit {
    public let icon: String
    public let text: LocalizedStringKey

    public init(icon: String, text: LocalizedStringKey) {
        self.icon = icon
        self.text = text
    }
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

/// Observable entitlement state + the `PremiumAccessPolicy` gate used by downloads and offline mode.
/// A refund/revocation blocks new downloads and entering offline mode; already downloaded files are kept.
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
    /// Which feature's pitch the paywall shows. Set by `requestUnlock(for:)`.
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

    public func requestUnlock(for context: PaywallContext = .offline) {
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
