import SwiftUI

/// The purchase controls in Settings.
///
/// The paywall already has a "Restore purchases" button, but the paywall is only reachable by *hitting a
/// locked feature*. Someone who reinstalls the app and never taps a gated action would have nowhere to
/// restore from, and App Review expects the entry point to be findable (Guideline 3.1.1). This section is
/// that entry point, and it stays visible after unlocking so the state is always legible.
struct PurchaseSettingsSection: View {
    let store: PremiumEntitlementStore

    @State private var isRestoring = false
    /// Deliberately local rather than reading `store.message`: that property is shared with the paywall, so
    /// showing it here would surface a stale purchase error under an unrelated button.
    @State private var restoreResult: String?

    var body: some View {
        Section("Purchases") {
            if store.isUnlocked {
                LabeledContent {
                    Text("Unlocked")
                } label: {
                    Label("Offline reading & private content", systemImage: "checkmark.seal")
                }
            } else {
                Button {
                    store.requestUnlock(for: .offline)
                } label: {
                    Label("Unlock offline reading", systemImage: "arrow.down.circle")
                }
            }

            Button {
                Task { await restore() }
            } label: {
                HStack {
                    Label("Restore purchases", systemImage: "arrow.clockwise")
                    if isRestoring {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isRestoring)

            if let restoreResult {
                Text(restoreResult)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func restore() async {
        isRestoring = true
        restoreResult = nil
        defer { isRestoring = false }

        await store.restore()
        restoreResult = store.isUnlocked
            ? String(localized: "Purchase restored.")
            : store.message
    }
}
