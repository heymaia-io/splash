import SwiftUI

/// Documentation for the private area, reached by tapping the version row in About seven times.
///
/// Two jobs. First, the private area has no discoverable entry point by design, and a feature nobody can
/// find is a feature nobody can review — App Review treats undocumented functionality as grounds for
/// rejection, so this page is what the review notes point at. Second, the gesture is easy to forget
/// months later, and a hidden feature you cannot get back into is just lost data.
struct PrivacyHelpView: View {
    var body: some View {
        Form {
            Section {
                Text("""
                    Private libraries let you mark a library, a series or a single book as private. \
                    Private content is removed from every list and from search, and appears only in the \
                    Private tab.
                    """)
            }

            Section("How to open it") {
                Step(number: 1, text: "Go to the Library tab.")
                Step(number: 2, text: "Press and hold the empty space just to the right of the “All Libraries” button for about two seconds.")
                Step(number: 3, text: "Confirm with Face ID, Touch ID or your device passcode.")
                Step(number: 4, text: "A Private tab appears at the top. It disappears again when the area locks.")
            }

            Section("How to make something private") {
                Text("Open a library, series or book, then choose Hide from its ••• menu. The option only appears while the Private tab is unlocked.")
            }

            Section {
                Text("The Private tab requires the one-time purchase that also unlocks offline reading. Without it the gesture does nothing at all.")
                Text("Choose when the area locks again in Settings › Private, which is likewise only visible while it is unlocked.")
            } header: {
                Text("Requirements")
            }

            Section {
                Text("Hiding is stored on this device only. Komga has no concept of private content and nothing about it is sent to your server, so the same account on another device shows everything.")
                Text("This is a lock on the door, not a safe. The list of which items are hidden is stored unencrypted on the device, and a downloaded file of a hidden book stays readable on disk until you delete the download.")
            } header: {
                Text("What it does not do")
            }
        }
        .navigationTitle("Private libraries")
    }
}

private struct Step: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Text("\(number)")
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.tint))
        }
    }
}
