import SwiftUI

/// The private area's only entry point: a long press on a deliberately unremarkable piece of the Library
/// screen.
///
/// Silence on failure is the whole point. If authentication is cancelled or the purchase is absent,
/// nothing happens at all — no alert, no haptic, no paywall. Any differentiated response would tell
/// someone who found the gesture by accident that there is something here to find.
struct PrivacyRevealGesture: ViewModifier {
    @Environment(\.privacy) private var privacy

    func body(content: Content) -> some View {
        content.onLongPressGesture(minimumDuration: 1.5) {
            guard let privacy else { return }
            Task {
                let wasUnlocked = privacy.isUnlocked
                await privacy.requestReveal()
                // Feedback only on success, where it reads as ordinary UI confirmation.
                if !wasUnlocked, privacy.isUnlocked {
                    #if os(iOS)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    #endif
                }
            }
        }
    }
}
