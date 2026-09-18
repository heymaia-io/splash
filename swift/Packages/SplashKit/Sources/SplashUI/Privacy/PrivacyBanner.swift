import SwiftUI

/// Sits beside `OfflineBanner`: while the private area is open, ordinary content and private content are
/// indistinguishable on screen, so the state has to be stated somewhere — together with the way out of it.
struct PrivacyBanner: View {
    let privacy: PrivacyController

    var body: some View {
        HStack {
            Label("Private content visible", systemImage: "eye")
            Spacer()
            Button("Lock now") { privacy.lock() }
                .buttonStyle(.bordered)
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.purple.opacity(0.2))
    }
}
