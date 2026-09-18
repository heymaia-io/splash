import SplashCore
import KomgaAPI
import SwiftUI

/// "Hide"/"Unhide" entry for the ellipsis menus on a library, series or book.
///
/// Renders nothing at all unless the private area is currently unlocked — before that, the menus look
/// exactly as they did before the feature existed.
struct HideMenuButton: View {
    enum Target {
        case library(KomgaLibraryId)
        case series(KomgaSeriesId)
        case book(KomgaBookId, isDownloaded: Bool)
    }

    let target: Target
    @Environment(\.privacy) private var privacy
    @Environment(\.offlineController) private var offline

    var body: some View {
        if let privacy, privacy.isUnlocked {
            if isHidden(privacy) {
                Button { Task { await setHidden(false, privacy) } } label: {
                    Label("Unhide", systemImage: "eye")
                }
            } else {
                Button { Task { await setHidden(true, privacy) } } label: {
                    Label("Hide", systemImage: "eye.slash")
                }
                // Hiding a downloaded book removes it from every listing, but the file stays on disk and
                // is readable by anything that can see the container. Offer to finish the job.
                if case .book(let bookId, true) = target, let offline {
                    Button(role: .destructive) {
                        Task {
                            await setHidden(true, privacy)
                            offline.delete(book: bookId)
                        }
                    } label: {
                        Label("Hide and delete download", systemImage: "eye.slash")
                    }
                }
            }
        }
    }

    private func isHidden(_ privacy: PrivacyController) -> Bool {
        switch target {
        case .library(let id): privacy.isHidden(libraryId: id)
        case .series(let id): privacy.isHidden(seriesId: id)
        case .book(let id, _): privacy.isHidden(bookId: id)
        }
    }

    private func setHidden(_ isHidden: Bool, _ privacy: PrivacyController) async {
        switch target {
        case .library(let id): await privacy.setHidden(isHidden, libraryId: id)
        case .series(let id): await privacy.setHidden(isHidden, seriesId: id)
        case .book(let id, _): await privacy.setHidden(isHidden, bookId: id)
        }
    }
}
