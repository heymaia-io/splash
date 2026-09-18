import Foundation

/// Gate for the paid features. The composition root injects the real entitlement check; everything that
/// starts a download, enters offline mode, or reveals private content asks this first.
///
/// One product unlocks **both** offline reading and private content, which is why these types are named
/// `Premium*` rather than `Offline*` — see `PremiumProduct.id`.
@MainActor
public protocol PremiumAccessPolicy: AnyObject {
    var isUnlocked: Bool { get }
    /// Asks the UI to present the paywall, phrased for whichever feature was blocked.
    func requestUnlock(for context: PaywallContext)
}

@MainActor
public final class AlwaysUnlockedPolicy: PremiumAccessPolicy {
    public init() {}
    public var isUnlocked: Bool { true }
    public func requestUnlock(for context: PaywallContext) {}
}

/// Which feature the user hit, so the paywall can lead with that rather than with a generic pitch.
///
/// Both presets must state that the single purchase unlocks both features. Two differently-titled paywalls
/// for one SKU, each implying its own purchase, reads as a dark pattern at App Review.
public struct PaywallContext: Sendable, Equatable {
    public let icon: String
    public let title: LocalizedStringResource
    public let subtitle: LocalizedStringResource
    public let benefits: [Benefit]

    public struct Benefit: Sendable, Equatable {
        public let icon: String
        public let text: LocalizedStringResource

        public init(icon: String, text: LocalizedStringResource) {
            self.icon = icon
            self.text = text
        }
    }

    public init(
        icon: String, title: LocalizedStringResource, subtitle: LocalizedStringResource, benefits: [Benefit]
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.benefits = benefits
    }

    public static let offline = PaywallContext(
        icon: "arrow.down.circle.fill",
        title: "Read offline",
        subtitle: """
            Reading online stays free and unlimited. One purchase unlocks offline reading and private content.
            """,
        benefits: [
            Benefit(icon: "books.vertical", text: "Download books and whole series"),
            Benefit(icon: "airplane", text: "Read comics, PDFs and EPUBs without a connection"),
            Benefit(icon: "eye.slash", text: "Keep chosen libraries, series and books private"),
            Benefit(icon: "checkmark.seal", text: "One-time purchase — no subscription"),
        ])

    public static let privacy = PaywallContext(
        icon: "lock.fill",
        title: "Keep it private",
        subtitle: """
            Reading online stays free and unlimited. One purchase unlocks private content and offline reading.
            """,
        benefits: [
            Benefit(icon: "eye.slash", text: "Hide libraries, series and books from every list"),
            Benefit(icon: "faceid", text: "Bring them back with Face ID, Touch ID or your passcode"),
            Benefit(icon: "books.vertical", text: "Download books and whole series for offline reading"),
            Benefit(icon: "checkmark.seal", text: "One-time purchase — no subscription"),
        ])
}
