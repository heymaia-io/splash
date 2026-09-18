import SwiftUI

/// Paywall for the offline unlock (plan Phase 16). Shown when a download or offline mode is requested
/// without the purchase.
public struct PaywallView: View {
    @Bindable var store: PremiumEntitlementStore
    /// Copy for the feature that asked; the product being sold is the same either way.
    let context: PaywallContext
    @Environment(\.dismiss) private var dismiss

    public init(store: PremiumEntitlementStore, context: PaywallContext = .offline) {
        self.store = store
        self.context = context
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: context.icon)
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    VStack(spacing: 8) {
                        Text(context.title).font(.largeTitle.bold())
                        Text(context.subtitle)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(context.benefits, id: \.icon) { Benefit(icon: $0.icon, text: $0.text) }
                    }
                    .frame(maxWidth: 420, alignment: .leading)

                    priceBlock

                    if let message = store.message {
                        Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        Button {
                            Task { await store.purchase() }
                        } label: {
                            Group {
                                if store.isPurchasing {
                                    ProgressView()
                                } else if let product = store.product {
                                    Text("Unlock for \(product.displayPrice)")
                                } else {
                                    Text("Unlock")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(store.isPurchasing)

                        Button("Restore purchases") { Task { await store.restore() } }
                            .disabled(store.isPurchasing)
                    }
                    .frame(maxWidth: 420)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } }
            }
            .task { if store.product == nil { await store.loadProduct() } }
        }
    }
}

extension PaywallView {
    /// The price, stated plainly rather than only on the button. `displayPrice` is StoreKit's localized
    /// string, so it already carries the right currency and formatting for the viewer's storefront.
    @ViewBuilder fileprivate var priceBlock: some View {
        VStack(spacing: 4) {
            if let product = store.product {
                Text(product.displayPrice)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("One-time payment. Yours forever — no subscription, no renewal.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if store.isLoadingProduct {
                ProgressView()
            } else {
                Text("Price unavailable — check your connection and try again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: 420)
    }
}

private struct Benefit: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: icon).foregroundStyle(.tint)
        }
    }
}
