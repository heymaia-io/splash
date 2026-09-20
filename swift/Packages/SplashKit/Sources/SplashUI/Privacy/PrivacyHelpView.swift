import SwiftUI

/// Documents the reveal gesture.
///
/// Required, not optional: App Review guideline 2.3.1 treats undocumented hidden functionality as grounds
/// for rejection, and a user who forgets the gesture has no other way back to their own content. It is
/// reached by tapping the version row in About seven times, so it stays out of the way of anyone casually
/// looking through Settings.
struct PrivacyHelpView: View {
    var body: some View {
        Form {
            Section {
                Text("""
                    Private content is hidden from every list in the app — Home, Library, search, \
                    collections, read lists and downloads — until you unlock it.
                    """)
            }

            Section("Showing private content") {
                Label("Open the Library tab.", systemImage: "1.circle")
                Label("Press and hold the empty space to the right of the library chip for about two seconds.",
                      systemImage: "2.circle")
                Label("Confirm with Face ID, Touch ID or your device passcode.", systemImage: "3.circle")
                Text("""
                    Nothing happens if you cancel. Your content reappears exactly where it normally lives, \
                    marked with a lock badge, and a banner offers Lock now.
                    """)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Hiding something") {
                Text("""
                    While unlocked, the ⋯ menu on a library, series or book offers Hide. Settings → Private \
                    lists everything you have hidden and can unhide it again.
                    """)
            }

            Section("What this is not") {
                Text("""
                    Hidden items are recorded on this device only and never sent to your server, so the \
                    Komga web UI and other clients still show everything. The list of hidden items is not \
                    encrypted, and files you have downloaded stay readable on disk. It hides content from \
                    someone glancing at your library — it is not a secure vault.
                    """)
            }

            Section("If the feature is unavailable") {
                Text("""
                    Unlocking requires a device passcode. If your device has none, set one in \
                    Settings → Face ID & Passcode.
                    """)
            }
        }
        .navigationTitle("Private content")
    }
}

/// Seven taps on the version row reveals the help page.
struct PrivacyHelpTapTarget: ViewModifier {
    @Binding var isPresented: Bool
    @State private var taps = 0

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                taps += 1
                if taps >= 7 {
                    taps = 0
                    isPresented = true
                }
            }
    }
}
