import KomgaAPI
import SplashCore
import SwiftUI

/// Admin-only operations on a whole series, shared by the Library grid and the Series screen so the rules
/// (who may do it, what a rename writes, how a delete is confirmed) live in one place.
@MainActor
struct SeriesAdminActions {
    let api: any KomgaApi
    let events: KomgaEventSource

    /// Komga restricts file deletion and metadata edits to ADMIN. The offline store is excluded because its
    /// `delete` only drops the local download and its `update` is unsupported: offering either there would
    /// promise a server change that never happens.
    static func canManage(authState: KomgaAuthenticationState, isOfflineMode: Bool) -> Bool {
        !isOfflineMode && (authState.authenticatedUser?.isAdmin ?? false)
    }

    /// Renames the series in Komga (not the folder on disk). The sort title follows so A–Z ordering matches,
    /// and both fields are locked so the next library scan does not revert them. A blank or unchanged title
    /// is a no-op.
    func rename(_ series: KomgaSeries, to title: String) async throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title != series.metadata.title else { return }
        var request = KomgaSeriesMetadataUpdateRequest()
        request.title = .some(title)
        request.titleLock = .some(true)
        request.titleSort = .some(title)
        request.titleSortLock = .some(true)
        try await api.seriesApi.update(series.id, request: request)
    }

    /// Deletes every book file of the series and then the series folder (when empty) on the server, and
    /// empties the library trash.
    func delete(_ series: KomgaSeries) async throws {
        try await ServerFileDeleter.deleteAndEmptyTrash(SeriesTarget(series: series), api: api, events: events)
    }
}

extension View {
    /// The rename alert and delete confirmation for a series, so every screen offering the actions shows
    /// the same dialogs. Set `renaming` / `deleting` to present them.
    func seriesAdminDialogs(
        renaming: Binding<KomgaSeries?>, deleting: Binding<KomgaSeries?>,
        onRename: @escaping (KomgaSeries, String) -> Void, onDelete: @escaping (KomgaSeries) -> Void
    ) -> some View {
        modifier(SeriesAdminDialogs(renaming: renaming, deleting: deleting, onRename: onRename, onDelete: onDelete))
    }
}

private struct SeriesAdminDialogs: ViewModifier {
    @Binding var renaming: KomgaSeries?
    @Binding var deleting: KomgaSeries?
    let onRename: (KomgaSeries, String) -> Void
    let onDelete: (KomgaSeries) -> Void
    /// nil until the user types, so the field shows the current title without a separate sync step.
    @State private var draft: String?

    func body(content: Content) -> some View {
        content
            .alert("Rename series", isPresented: presented($renaming), presenting: renaming) { series in
                TextField("Title", text: Binding(get: { draft ?? series.metadata.title }, set: { draft = $0 }))
                Button("Cancel", role: .cancel) { draft = nil }
                Button("Save") {
                    onRename(series, draft ?? series.metadata.title)
                    draft = nil
                }
            } message: { _ in
                Text("Changes the title in Komga. The folder on disk keeps its name.")
            }
            .confirmationDialog(
                deleting.map(BookDeleteDialog.title(for:)) ?? "", isPresented: presented($deleting),
                titleVisibility: .visible, presenting: deleting
            ) { series in
                Button(BookDeleteDialog.confirm, role: .destructive) { onDelete(series) }
            } message: { series in
                Text(BookDeleteDialog.warning(for: series))
            }
    }

    private func presented(_ item: Binding<KomgaSeries?>) -> Binding<Bool> {
        Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }
}
