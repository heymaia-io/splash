import SwiftUI

/// Paywall for the one-time premium unlock. Shown when a download, offline mode, or the private area is
/// requested without the purchase.
///
/// The copy comes from a `PaywallContext` rather than being hardcoded, because a single SKU unlocks several
/// features and each one should lead with what the user just tried to do.
public struct PaywallView: View {
    @Bindable var store: PremiumEntitlementStore
    @Environment(\.dismiss) private var dismiss

    private var context: PaywallContext { store.paywallContext }

    public init(store: PremiumEntitlementStore) {
        self.store = store
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
                        ForEach(context.benefits, id: \.icon) { benefit in
                            BenefitRow(icon: benefit.icon, text: benefit.text)
                        }
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

private struct BenefitRow: View {
    let icon: String
    let text: LocalizedStringResource

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: icon).foregroundStyle(.tint)
        }
    }
}
