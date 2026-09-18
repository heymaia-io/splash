import SplashCore
import KomgaAPI
import SwiftUI

/// Settings → Private: the only place that shows what is hidden, with per-row Unhide.
///
/// Deliberately a flat, non-navigable list. An earlier attempt made this a browsing surface with shelves you
/// could tap into, which meant re-implementing every home-screen query client-side — ~775 lines that carried
/// four bugs. Hidden items are browsed in the ordinary UI while unlocked; this screen only manages the set.
struct PrivacySettingsView: View {
    let api: any KomgaApi
    let privacy: PrivacyController

    /// Rows resolved from bare ids. The database stores ids only, so a name costs one `getOne` each — far
    /// cheaper than reproducing the listing queries, and the list is short by construction.
    private struct Row: Identifiable, Hashable {
        enum Kind: String { case library, series, book }
        let id: String
        let kind: Kind
        let name: String
    }

    @State private var rows: [Row] = []
    @State private var isLoading = true

    var body: some View {
        Form {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if rows.isEmpty {
                ContentUnavailableView(
                    "Nothing is private", systemImage: "eye",
                    description: Text("Use Hide from the menu on a library, series or book."))
            } else {
                section(.library, title: "Libraries")
                section(.series, title: "Series")
                section(.book, title: "Books")
            }

            Section {
                Picker("Lock again", selection: policyBinding) {
                    Text("When I leave the app").tag(PrivacyLockPolicy.onLeaving)
                    Text("After a few minutes away").tag(PrivacyLockPolicy.afterTimeout)
                    Text("When I quit the app").tag(PrivacyLockPolicy.untilAppQuits)
                }
            } footer: {
                Text("""
                    Hidden items are stored on this device only and never sent to your server. \
                    Other Komga clients still show everything. This is not encryption — downloaded files \
                    stay readable on disk.
                    """)
            }
        }
        .navigationTitle("Private")
        .task { await load() }
    }

    @ViewBuilder private func section(_ kind: Row.Kind, title: LocalizedStringKey) -> some View {
        let items = rows.filter { $0.kind == kind }
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { row in
                    HStack {
                        Text(row.name)
                        Spacer()
                        Button("Unhide") { Task { await unhide(row) } }
                            .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    private var policyBinding: Binding<PrivacyLockPolicy> {
        Binding(
            get: { privacy.lockPolicy },
            set: { policy in Task { await privacy.setLockPolicy(policy) } })
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let hidden = privacy.hidden
        var resolved: [Row] = []

        for id in hidden.libraries.sorted(by: { $0.rawValue < $1.rawValue }) {
            let name = try? await api.libraryApi.getLibrary(id).name
            resolved.append(Row(id: id.rawValue, kind: .library, name: name ?? id.rawValue))
        }
        for id in hidden.series.sorted(by: { $0.rawValue < $1.rawValue }) {
            let name = try? await api.seriesApi.getOneSeries(id).metadata.title
            resolved.append(Row(id: id.rawValue, kind: .series, name: name ?? id.rawValue))
        }
        for id in hidden.books.sorted(by: { $0.rawValue < $1.rawValue }) {
            let name = try? await api.bookApi.getOne(id).metadata.title
            resolved.append(Row(id: id.rawValue, kind: .book, name: name ?? id.rawValue))
        }
        rows = resolved
    }

    private func unhide(_ row: Row) async {
        switch row.kind {
        case .library: await privacy.setHidden(libraryId: KomgaLibraryId(row.id), false)
        case .series: await privacy.setHidden(seriesId: KomgaSeriesId(row.id), false)
        case .book: await privacy.setHidden(bookId: KomgaBookId(row.id), false)
        }
        // Drop the row immediately rather than re-resolving every remaining name.
        rows.removeAll { $0 == row }
    }
}
