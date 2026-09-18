import Foundation

/// Gate for the paid features. The composition root injects the real entitlement check; everything that
/// starts a download, enters offline mode, or opens the private area asks this first.
///
/// Kept separate from `PremiumEntitlementStore` so the gate can be faked (tests, previews) without
/// dragging StoreKit in, and so the offline and privacy features depend on the capability rather than on
/// the purchase machinery.
@MainActor
public protocol PremiumAccessPolicy: AnyObject {
    var isUnlocked: Bool { get }
    /// Asks the UI to present the paywall, with the copy for whichever feature was blocked.
    func requestUnlock(for context: PaywallContext)
}

@MainActor
public final class AlwaysUnlockedPolicy: PremiumAccessPolicy {
    public init() {}
    public var isUnlocked: Bool { true }
    public func requestUnlock(for context: PaywallContext) {}
}
