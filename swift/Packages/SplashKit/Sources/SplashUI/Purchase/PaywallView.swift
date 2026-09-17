import SwiftUI

/// Paywall for the offline unlock (plan Phase 16). Shown when a download or offline mode is requested
/// without the purchase.
public struct PaywallView: View {
    @Bindable var store: OfflineEntitlementStore
    @Environment(\.dismiss) private var dismiss

    public init(store: OfflineEntitlementStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    VStack(spacing: 8) {
                        Text("Read offline").font(.largeTitle.bold())
                        Text("Reading online stays free and unlimited. Unlock offline reading once to take your comics anywhere.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Benefit(icon: "books.vertical", text: "Download books and whole series")
                        Benefit(icon: "airplane", text: "Read comics, PDFs and EPUBs without a connection")
                        Benefit(icon: "arrow.triangle.2.circlepath", text: "Progress syncs back when you're online")
                        Benefit(icon: "checkmark.seal", text: "One-time purchase — no subscription")
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
