import SplashCore
import KomgaAPI
import SwiftUI

/// Preferences for the private area.
///
/// Reachable only while unlocked — `SettingsView` does not render the row otherwise, because a permanent
/// "Private" row in Settings would be exactly the visible entry point this feature is meant not to have.
struct PrivacySettingsView: View {
    @State var catalog: PrivateCatalogViewModel
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
                if catalog.state.isUninitialized || (catalog.state.isLoading && catalog.isEmpty) {
                    ProgressView()
                } else if catalog.isEmpty {
                    Text("Nothing is hidden.").foregroundStyle(.secondary)
                } else {
                    ForEach(catalog.libraries) { library in
                        row(library.name, subtitle: String(localized: "Library"), systemImage: "books.vertical") {
                            await privacy.setHidden(false, libraryId: library.id)
                        }
                    }
                    ForEach(catalog.series) { item in
                        row(item.metadata.title, subtitle: String(localized: "Series"), systemImage: "square.stack") {
                            await privacy.setHidden(false, seriesId: item.id)
                        }
                    }
                    ForEach(catalog.books) { book in
                        row(book.metadata.title, subtitle: book.seriesTitle, systemImage: "book") {
                            await privacy.setHidden(false, bookId: book.id)
                        }
                    }
                }
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
        .task {
            catalog.start()
            if catalog.state.isUninitialized { await catalog.load() }
        }
        .onDisappear { catalog.stop() }
    }

    /// One hidden item, with the only action that matters here.
    private func row(
        _ title: String, subtitle: String, systemImage: String, unhide: @escaping () async -> Void
    ) -> some View {
        HStack {
            Label {
                VStack(alignment: .leading) {
                    Text(title)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
            }
            Spacer()
            Button("Unhide") { Task { await unhide() } }
                .buttonStyle(.borderless)
        }
    }

    private func footer(for policy: PrivacyLockPolicy) -> LocalizedStringKey {
        switch policy {
        case .onLeaving: "The private tab disappears as soon as Splash goes to the background."
        case .afterTimeout: "The private tab stays available if you come back within the delay."
        case .untilAppQuits: "The private tab stays available until Splash is closed entirely."
        }
    }
}
