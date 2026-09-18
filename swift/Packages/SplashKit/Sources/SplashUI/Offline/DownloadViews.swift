import SplashCore
import SplashOffline
import KomgaAPI
import SwiftUI

extension EnvironmentValues {
    /// nil when offline support is not configured (previews/tests).
    @Entry public var offlineController: OfflineController?
}

/// Download state control for a book (book screen toolbar/details).
struct BookDownloadButton: View {
    let book: SplashBook
    @Environment(\.offlineController) private var offline

    var body: some View {
        if let offline, !offline.isOfflineMode {
            let state = offline.state(of: book.id)
            switch (state?.status, book.downloaded) {
            case (.queued?, _), (.downloading?, _):
                HStack {
                    ProgressView(value: state.map { $0.totalBytes > 0 ? Double($0.completedBytes) / Double($0.totalBytes) : 0 } ?? 0)
                        .frame(width: 80)
                    Button("Cancel", role: .cancel) { offline.cancel(book.id) }
                }
            case (.failed?, _):
                Button { offline.retry(book.id) } label: {
                    Label("Retry download", systemImage: "arrow.clockwise.circle")
                }
                .tint(.orange)
            case (_, true), (.complete?, _):
                Menu {
                    if book.isLocalFileOutdated {
                        Button("Update download") { offline.download(book: book.id) }
                    }
                    Button("Delete download", role: .destructive) { offline.delete(book: book.id) }
                } label: {
                    Label(book.isLocalFileOutdated ? "Outdated" : "Downloaded",
                          systemImage: book.isLocalFileOutdated ? "arrow.down.circle.dotted" : "checkmark.circle.fill")
                }
                .tint(.green)
            default:
                Button { offline.download(book: book.id) } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
            }
        }
    }
}

/// `settings/offline` + `settings/offline/downloads` (downloads list, storage, network, mode).
public struct DownloadsSettingsView: View {
    @Environment(\.offlineController) private var offline
    @State private var users: [OfflineUserChoice] = []

    public init() {}

    public var body: some View {
        if let offline {
            content(offline)
        } else {
            ContentUnavailableView("Offline mode unavailable", systemImage: "icloud.slash")
        }
    }

    private func content(_ offline: OfflineController) -> some View {
        List {
            Section {
                if offline.isOfflineMode {
                    Button("Go online") { Task { await offline.goOnline() } }
                } else {
                    ForEach(users) { user in
                        Button("Go offline as \(user.email)") { Task { await offline.goOffline(as: user.id) } }
                    }
                    if users.isEmpty {
                        Text("Download something to be able to read offline.").foregroundStyle(.secondary)
                    }
                }
                Toggle("Download on Wi-Fi only", isOn: Binding(get: { offline.wifiOnly }, set: { offline.wifiOnly = $0 }))
                LabeledContent("Storage used",
                               value: ByteCountFormatter.string(fromByteCount: offline.downloadedBytes, countStyle: .file))
            } header: {
                Text("Offline mode")
            } footer: {
                if !offline.access.isUnlocked {
                    Button("Unlock offline reading") { offline.access.requestUnlock(for: .offline) }
                }
            }

            Section("Downloads") {
                if offline.sortedDownloads.isEmpty {
                    Text("No downloads").foregroundStyle(.secondary)
                }
                ForEach(offline.sortedDownloads) { download in
                    DownloadRow(download: download, offline: offline)
                }
                .onDelete { indexes in
                    for index in indexes { offline.delete(book: offline.sortedDownloads[index].bookId) }
                }
            }
            if offline.sortedDownloads.contains(where: { $0.status == .complete || $0.status == .failed }) {
                Button("Clear finished from list") { offline.clearFinished() }
            }
        }
        .navigationTitle("Downloads")
        .task {
            offline.start()
            await offline.refresh()
            users = await offline.offlineUsers()
        }
        .refreshable { await offline.refresh() }
        .alert(offline.lastError ?? "", isPresented: Binding(
            get: { offline.lastError != nil }, set: { if !$0 { offline.dismissError() } })
        ) { Button("OK", role: .cancel) {} }
    }
}

struct DownloadRow: View {
    let download: BookDownload
    let offline: OfflineController

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(.bookDefault(download.bookId))
                .aspectRatio(0.703, contentMode: .fit)
                .frame(width: 40)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            VStack(alignment: .leading, spacing: 4) {
                Text(download.bookTitle ?? download.bookId.rawValue).lineLimit(1)
                switch download.status {
                case .queued:
                    Text("Queued").font(.caption).foregroundStyle(.secondary)
                case .downloading:
                    ProgressView(value: download.totalBytes > 0
                                 ? Double(download.completedBytes) / Double(download.totalBytes) : 0)
                    Text(progressText).font(.caption).foregroundStyle(.secondary)
                case .complete:
                    Text(ByteCountFormatter.string(fromByteCount: download.totalBytes, countStyle: .file))
                        .font(.caption).foregroundStyle(.secondary)
                case .failed:
                    Text(download.error ?? String(localized: "Failed")).font(.caption).foregroundStyle(.red).lineLimit(2)
                }
            }
            Spacer()
            switch download.status {
            case .queued, .downloading:
                Button { offline.cancel(download.bookId) } label: { Image(systemName: "xmark.circle") }
                    .accessibilityLabel("Cancel download")
            case .failed:
                Button { offline.retry(download.bookId) } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Retry download")
            case .complete:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .buttonStyle(.borderless)
    }

    private var progressText: String {
        let done = ByteCountFormatter.string(fromByteCount: download.completedBytes, countStyle: .file)
        guard download.totalBytes > 0 else { return done }
        return "\(done) / \(ByteCountFormatter.string(fromByteCount: download.totalBytes, countStyle: .file))"
    }
}

/// Banner shown on top of the main shell while offline (`AppBar` offline indicator + "go online").
struct OfflineBanner: View {
    let offline: OfflineController

    var body: some View {
        HStack {
            Label("Offline mode", systemImage: "icloud.slash")
            Spacer()
            Button("Go online") { Task { await offline.goOnline() } }
                .buttonStyle(.bordered)
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.orange.opacity(0.2))
    }
}

/// The Downloads *tab*: the shelf of what is on the device. Configuration (offline mode, Wi-Fi, storage,
/// the transfer list) lives in Settings → Downloads, so this screen stays a library view rather than a
/// settings form.
struct DownloadsView: View {
    let cardWidth: CGFloat
    let navigate: (Destination) -> Void
    @Environment(\.offlineController) private var offline
    @State private var series: [KomgaSeries] = []
    @State private var state: LoadState<Void> = .uninitialized

    var body: some View {
        Group {
            if let offline {
                content(offline)
            } else {
                ContentUnavailableView("Offline mode unavailable", systemImage: "icloud.slash")
            }
        }
        .navigationTitle("Downloads")
    }

    @ViewBuilder private func content(_ offline: OfflineController) -> some View {
        if !offline.access.isUnlocked {
            locked(offline)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    activeTransfers(offline)
                    switch state {
                    case .error(let error):
                        ErrorView(error: error) { Task { await load(offline) } }
                    case .uninitialized,
                         .loading where series.isEmpty:
                        ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                    default:
                        if series.isEmpty, offline.sortedDownloads.isEmpty {
                            ContentUnavailableView("No downloads", systemImage: "arrow.down.circle",
                                                   description: Text("Books you download appear here."))
                        } else {
                            CardGrid(items: series, cardWidth: cardWidth) { item in
                                Button { navigate(item.oneshot ? .oneshot(item.id) : .series(item.id)) } label: {
                                    SeriesCard(series: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .refreshable { await load(offline) }
            .task(id: offline.downloads.count) { await load(offline) }
        }
    }

    /// Offline reading is the paid feature, so the tab doubles as the storefront until it is unlocked.
    private func locked(_ offline: OfflineController) -> some View {
        ContentUnavailableView {
            Label("Offline reading is locked", systemImage: "lock")
        } description: {
            Text("Download comics, PDFs and EPUBs and read them without a connection.")
        } actions: {
            Button("Unlock offline reading") { offline.access.requestUnlock(for: .offline) }
                .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder private func activeTransfers(_ offline: OfflineController) -> some View {
        let active = offline.sortedDownloads.filter { $0.status == .queued || $0.status == .downloading || $0.status == .failed }
        if !active.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("In progress").font(.title3.bold()).padding(.horizontal)
                ForEach(active) { download in
                    DownloadRow(download: download, offline: offline).padding(.horizontal)
                }
            }
        }
    }

    private func load(_ offline: OfflineController) async {
        state = .loading
        do {
            series = try await offline.downloadedSeries()
            state = .success(())
        } catch {
            state = .error(error)
        }
    }
}
