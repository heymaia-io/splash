import SplashCore
import KomgaAPI
import SwiftUI

/// What a content screen shows when its load fails.
///
/// An unreachable server is the common, recoverable case for a self-hosted Komga — no connection, VPN off,
/// away from home, server down — and a raw "The Internet connection appears to be offline" is a dead end.
/// In that case the screen offers what is already on the device instead. Everything else keeps the plain
/// error, because a 500 or a decoding failure is not something the user can read their way out of.
struct ScreenErrorView: View {
    let error: Error
    let retry: () -> Void
    /// Shelf of downloaded series. Useful where the screen was a browsing surface (Home, Library); pointless
    /// on a single series or book, where an unrelated grid would just be noise.
    var downloads: DownloadsShelf?

    struct DownloadsShelf {
        let cardWidth: CGFloat
        let navigate: (Destination) -> Void
    }

    var body: some View {
        if error.isServerUnreachable {
            OfflineFallbackView(retry: retry, downloads: downloads)
        } else {
            ErrorView(error: error, retry: retry)
        }
    }
}

/// Offline state: a short explanation plus the downloaded shelf.
///
/// Nothing is fetched or pre-cached to make this work. Downloading a book already stores its series record
/// and the series/book thumbnail bytes in the offline database (`SeriesActions` / `BookActions`), so the
/// covers here are local and permanent. A library of any size therefore costs nothing extra — only what was
/// deliberately downloaded ever appears.
struct OfflineFallbackView: View {
    let retry: () -> Void
    var downloads: ScreenErrorView.DownloadsShelf?

    @Environment(\.offlineController) private var offline
    @State private var series: [KomgaSeries] = []
    @State private var didLoad = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                message
                if let downloads, !series.isEmpty {
                    shelf(downloads)
                }
            }
            .padding(.vertical, 32)
        }
        .task {
            guard !didLoad, downloads != nil, let offline else { return }
            didLoad = true
            series = (try? await offline.downloadedSeries()) ?? []
        }
    }

    private var message: some View {
        ContentUnavailableView {
            Label("Can't reach your server", systemImage: "wifi.slash")
        } description: {
            Text(series.isEmpty
                 ? "Check your connection, or that your Komga server is reachable from this network."
                 : "Here's what you've downloaded. It's all readable right now.")
        } actions: {
            Button("Try again", action: retry).buttonStyle(.borderedProminent)
        }
    }

    private func shelf(_ downloads: ScreenErrorView.DownloadsShelf) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Downloaded").font(.title3.bold()).padding(.horizontal)
            CardGrid(items: series, cardWidth: downloads.cardWidth) { item in
                Button {
                    downloads.navigate(item.oneshot ? .oneshot(item.id) : .series(item.id))
                } label: {
                    SeriesCard(series: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
