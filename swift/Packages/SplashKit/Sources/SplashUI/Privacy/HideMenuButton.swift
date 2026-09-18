import KomgaAPI
import SwiftUI

/// The "Hide"/"Unhide" item for an ellipsis or context menu.
///
/// Renders nothing unless the private area is unlocked — the feature must leave no trace while locked, and
/// there is nowhere to hide something *from* while everything is visible anyway.
struct HideMenuButton: View {
    enum Target {
        case library(KomgaLibraryId)
        case series(KomgaSeriesId)
        case book(KomgaBookId)
    }

    let target: Target
    /// Offered for a downloaded book: filtering hides it from the shelf, not from the filesystem.
    var downloadedBook: SplashBook?
    var onDeleteDownload: (() -> Void)?

    @Environment(\.privacy) private var privacy

    var body: some View {
        if let privacy, privacy.isUnlocked {
            Divider()
            Button {
                Task { await setHidden(!isHidden(privacy), on: privacy) }
            } label: {
                isHidden(privacy)
                    ? Label("Unhide", systemImage: "eye")
                    : Label("Hide", systemImage: "eye.slash")
            }
            if !isHidden(privacy), let book = downloadedBook, book.downloaded, let onDeleteDownload {
                Button(role: .destructive) {
                    Task {
                        await setHidden(true, on: privacy)
                        onDeleteDownload()
                    }
                } label: {
                    Label("Hide and delete download", systemImage: "eye.slash")
                }
            }
        }
    }

    private func isHidden(_ privacy: PrivacyController) -> Bool {
        switch target {
        case .library(let id): privacy.isHidden(libraryId: id)
        case .series(let id): privacy.isHidden(seriesId: id)
        case .book(let id): privacy.isHidden(bookId: id)
        }
    }

    private func setHidden(_ hidden: Bool, on privacy: PrivacyController) async {
        switch target {
        case .library(let id): await privacy.setHidden(libraryId: id, hidden)
        case .series(let id): await privacy.setHidden(seriesId: id, hidden)
        case .book(let id): await privacy.setHidden(bookId: id, hidden)
        }
    }
}
