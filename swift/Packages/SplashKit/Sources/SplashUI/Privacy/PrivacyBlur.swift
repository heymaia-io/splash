import SwiftUI

extension View {
    /// Covers the window while the app is leaving the foreground with the private area open.
    ///
    /// iOS snapshots the window for the app switcher during `.inactive`, and that snapshot survives in the
    /// recents UI. Without this, everything the feature hides is on display there.
    func privacyBlur(isActive: Bool) -> some View {
        modifier(PrivacyBlurModifier(isActive: isActive))
    }
}

private struct PrivacyBlurModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if isActive {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                }
                .ignoresSafeArea()
                // No animation: a fade would render the first frames of the snapshot unblurred.
                .transition(.identity)
                .accessibilityHidden(true)
            }
        }
    }
}
