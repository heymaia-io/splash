import SwiftUI

extension View {
    /// A 1.5 s long press that opens the private area.
    ///
    /// Attach it to **dead space**, never to a `Menu` label or any other control that handles press-and-hold
    /// itself — the two gestures fight and neither fires reliably. There is also no supported way to attach a
    /// gesture to a large navigation title, and `.principal` is already occupied by the shell's tab picker,
    /// which is why the target is the empty area beside the library chip.
    func privacyRevealGesture() -> some View {
        modifier(PrivacyRevealGesture())
    }
}

private struct PrivacyRevealGesture: ViewModifier {
    @Environment(\.privacy) private var privacy
    @State private var revealCount = 0

    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 1.5) {
                guard let privacy, !privacy.isUnlocked else { return }
                Task {
                    await privacy.requestReveal()
                    // Feedback *only* on success. A failed or cancelled authentication must be
                    // indistinguishable from having pressed empty space, or the response itself tells a
                    // snooper that there is something here to find.
                    if privacy.isUnlocked { revealCount += 1 }
                }
            }
            // Nothing accessible is announced: the gesture is deliberately undiscoverable, and Settings →
            // About documents it for the user who needs it.
            .accessibilityHidden(true)
            .sensoryFeedback(.success, trigger: revealCount)
    }
}
