import Foundation
import SplashOffline
import KomgaAPI
import Observation

/// What the offline UI needs from the composition root (mode switching lives there because it swaps the
/// active `KomgaApi`).
@MainActor
public protocol OfflineModeSwitching: AnyObject {
    var isOfflineMode: Bool { get }
    /// Users with downloaded content (Kotlin `offlineIsAvailable` / `offlineUser`).
    func offlineUsers() async -> [OfflineUserChoice]
    /// Series that have at least one downloaded book, read from the *offline* store regardless of the
    /// current mode — the Downloads tab shows the same shelf whether the app is online or not.
    func downloadedSeries() async throws -> [KomgaSeries]
    func goOffline(as userId: KomgaUserId) async throws
    func goOnline() async throws
}

public struct OfflineUserChoice: Identifiable, Hashable, Sendable {
    public let id: KomgaUserId
    public let email: String
    public let serverURL: String?

    public init(id: KomgaUserId, email: String, serverURL: String?) {
        self.id = id
        self.email = email
        self.serverURL = serverURL
    }
}

/// Gate for paid offline features (plan Phase 16). The composition root injects the real entitlement check;
/// everything that starts a download or enters offline mode asks this first.
@MainActor
public protocol OfflineAccessPolicy: AnyObject {
    var isUnlocked: Bool { get }
    /// Asks the UI to present the paywall.
    func requestUnlock()
}

@MainActor
public final class AlwaysUnlockedPolicy: OfflineAccessPolicy {
    public init() {}
    public var isUnlocked: Bool { true }
    public func requestUnlock() {}
}

/// UI façade over `OfflineDownloads` (Kotlin: `OfflineTaskEmitter` + `bookDownloadEvents` +
/// `OfflineSettingsRepository` as consumed by screens). Keeps live download state for badges/progress.
@MainActor
@Observable
public final class OfflineController {
    public private(set) var downloads: [KomgaBookId: BookDownload] = [:]
    public private(set) var downloadedBytes: Int64 = 0
    public private(set) var lastError: String?
    public var wifiOnly: Bool {
        didSet { onWifiOnlyChange(wifiOnly) }
    }

    public let access: any OfflineAccessPolicy
    private let service: OfflineDownloads
    private let modeSwitch: any OfflineModeSwitching
    private let onWifiOnlyChange: (Bool) -> Void
    private var eventsTask: Task<Void, Never>?

    public init(
        service: OfflineDownloads, modeSwitch: any OfflineModeSwitching, access: any OfflineAccessPolicy,
        wifiOnly: Bool, onWifiOnlyChange: @escaping (Bool) -> Void
    ) {
        self.service = service
        self.modeSwitch = modeSwitch
        self.access = access
        self.wifiOnly = wifiOnly
        self.onWifiOnlyChange = onWifiOnlyChange
    }

    public var isOfflineMode: Bool { modeSwitch.isOfflineMode }

    public func start() {
        guard eventsTask == nil else { return }
        let stream = service.events()
        eventsTask = Task { [weak self] in
            await self?.refresh()
            for await event in stream {
                self?.apply(event)
            }
        }
    }

    public func refresh() async {
        do {
            let all = try await service.downloads()
            downloads = Dictionary(uniqueKeysWithValues: all.map { ($0.bookId, $0) })
            downloadedBytes = try await service.downloadedBytes()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func apply(_ event: DownloadEvent) {
        switch event {
        case .bookDownloadProgress(let d), .bookDownloadError(let d):
            downloads[d.bookId] = d
        case .bookDownloadCompleted(let d):
            downloads[d.bookId] = d
            Task { downloadedBytes = (try? await service.downloadedBytes()) ?? downloadedBytes }
        case .bookDownloadCancelled(let id):
            downloads[id] = nil
        }
    }

    public var sortedDownloads: [BookDownload] {
        downloads.values.sorted { $0.createdDate > $1.createdDate }
    }

    public func state(of bookId: KomgaBookId) -> BookDownload? { downloads[bookId] }

    // MARK: Actions (gated)

    public func download(book id: KomgaBookId) { gated { try await $0.downloadBook(id) } }
    public func download(series id: KomgaSeriesId) { gated { try await $0.downloadSeries(id) } }
    public func retry(_ id: KomgaBookId) { gated { try await $0.retry(id) } }

    public func cancel(_ id: KomgaBookId) { run { try await $0.cancel(id) } }
    public func delete(book id: KomgaBookId) {
        run { try await $0.deleteBook(id) }
        downloads[id] = nil
    }
    public func delete(series id: KomgaSeriesId) { run { try await $0.deleteSeries(id) } }
    public func clearFinished() { run { try await $0.clearFinished() } }

    public func localFileURL(for id: KomgaBookId) async -> URL? {
        try? await service.localFileURL(for: id)
    }

    // MARK: Mode

    public func offlineUsers() async -> [OfflineUserChoice] { await modeSwitch.offlineUsers() }

    public func downloadedSeries() async throws -> [KomgaSeries] { try await modeSwitch.downloadedSeries() }

    public func goOffline(as userId: KomgaUserId) async {
        guard access.isUnlocked else { return access.requestUnlock() }
        do { try await modeSwitch.goOffline(as: userId) } catch { lastError = error.localizedDescription }
    }

    public func goOnline() async {
        do { try await modeSwitch.goOnline() } catch { lastError = error.localizedDescription }
    }

    public func dismissError() { lastError = nil }

    private func gated(_ action: @escaping (OfflineDownloads) async throws -> Void) {
        guard access.isUnlocked else { return access.requestUnlock() }
        run(action)
    }

    private func run(_ action: @escaping (OfflineDownloads) async throws -> Void) {
        let service = self.service
        Task {
            do {
                try await action(service)
                await refresh()
            } catch {
                lastError = error.localizedDescription
            }
        }
    }
}
