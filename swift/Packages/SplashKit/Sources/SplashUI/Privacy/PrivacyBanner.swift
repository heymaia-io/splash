import SwiftUI

/// Standing reminder that private content is currently on screen.
///
/// Since unlocking reveals hidden items in place — in Home, Library, Search and Downloads — rather than
/// gathering them into a tab of their own, there is no longer any implicit signal that you are looking
/// at them. This is that signal, and the quickest way back.
struct PrivacyBanner: View {
    let privacy: PrivacyController

    var body: some View {
        HStack {
            Label("Private content visible", systemImage: "lock.open")
            Spacer()
            Button("Lock now") { privacy.lock() }
                .buttonStyle(.bordered)
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.tint.opacity(0.15))
    }
}
