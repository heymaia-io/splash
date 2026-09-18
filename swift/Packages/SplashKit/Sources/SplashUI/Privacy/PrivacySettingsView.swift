import SplashCore
import KomgaAPI
import SwiftUI

/// Preferences for the private area.
///
/// Reachable only while unlocked — `SettingsView` does not render the row otherwise, because a permanent
/// "Private" row in Settings would be exactly the visible entry point this feature is meant not to have.
struct PrivacySettingsView: View {
    @Environment(\.privacy) private var privacy
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let privacy {
            content(privacy)
        } else {
            ContentUnavailableView("Unavailable", systemImage: "lock.slash")
        }
    }

    private func content(_ privacy: PrivacyController) -> some View {
        Form {
            Section {
                Picker("Lock again", selection: Binding(
                    get: { privacy.lockPolicy },
                    set: { policy in Task { await privacy.setLockPolicy(policy) } })
                ) {
                    Text("When I leave the app").tag(PrivacyLockPolicy.onLeaving)
                    Text("After a delay").tag(PrivacyLockPolicy.afterTimeout)
                    Text("When I quit the app").tag(PrivacyLockPolicy.untilAppQuits)
                }
                if privacy.lockPolicy == .afterTimeout {
                    Picker("Delay", selection: Binding(
                        get: { privacy.lockTimeout },
                        set: { timeout in Task { await privacy.setLockTimeout(timeout) } })
                    ) {
                        Text("1 minute").tag(TimeInterval(60))
                        Text("5 minutes").tag(TimeInterval(300))
                        Text("15 minutes").tag(TimeInterval(900))
                        Text("1 hour").tag(TimeInterval(3600))
                    }
                }
            } header: {
                Text("Locking")
            } footer: {
                Text(footer(for: privacy.lockPolicy))
            }

            Section {
                LabeledContent("Hidden libraries", value: "\(privacy.hidden.libraries.count)")
                LabeledContent("Hidden series", value: "\(privacy.hidden.series.count)")
                LabeledContent("Hidden books", value: "\(privacy.hidden.books.count)")
            } header: {
                Text("Hidden items")
            } footer: {
                Text("""
                    Hiding is stored on this device only — Komga has no concept of private content, and \
                    nothing about it is sent to your server. Downloaded files of hidden books stay on \
                    disk until you delete them.
                    """)
            }

            Section {
                Button("Lock now", role: .destructive) {
                    privacy.lock()
                    dismiss()
                }
            }
        }
        .navigationTitle("Private")
    }

    private func footer(for policy: PrivacyLockPolicy) -> LocalizedStringKey {
        switch policy {
        case .onLeaving: "The private tab disappears as soon as Splash goes to the background."
        case .afterTimeout: "The private tab stays available if you come back within the delay."
        case .untilAppQuits: "The private tab stays available until Splash is closed entirely."
        }
    }
}
