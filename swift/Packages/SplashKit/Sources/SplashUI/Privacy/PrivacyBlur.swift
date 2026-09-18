import SwiftUI

/// Opaque cover drawn over the whole window when the app leaves the foreground with the private area
/// open. iOS snapshots the window for the app switcher during `.inactive`, and that snapshot survives on
/// disk — without this, everything the private area is hiding would be visible from the app switcher.
struct PrivacyBlur: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
        }
        .ignoresSafeArea()
        .transition(.opacity)
        .accessibilityHidden(true)
    }
}
