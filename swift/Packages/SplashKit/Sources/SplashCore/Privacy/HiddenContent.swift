import Foundation
import KomgaAPI

/// The ids hidden on **one** Komga server.
///
/// [NUEVO] Komga has no concept of private content, so this is purely client-side and never leaves the
/// device. It is deliberately *obscurity behind a device-authentication gate*, not encryption: the ids
/// below are stored in plain text in `splash.sqlite`, so someone with a filesystem backup can see which
/// ids are hidden (not what they contain). Do not describe this feature as a vault.
public struct HiddenContent: Codable, Equatable, Sendable {
    /// Hiding a library hides everything in it; hiding a series hides its books. `HiddenContentFilter`
    /// resolves that inheritance — these sets hold only what the user marked directly.
    public var libraries: Set<KomgaLibraryId> = []
    public var series: Set<KomgaSeriesId> = []
    public var books: Set<KomgaBookId> = []

    public init() {}

    public var isEmpty: Bool { libraries.isEmpty && series.isEmpty && books.isEmpty }
}

/// Everything the privacy feature persists.
///
/// The hidden ids are keyed **by server**, because a Komga id only means anything on the server that
/// issued it. An earlier version kept one flat set plus a `serverUrl` stamp, and every write rewrote
/// that stamp — so hiding something after switching servers silently re-labelled the previous server's
/// ids as belonging to the new one, and switching back left the original set inert. Making the server
/// the key removes that failure mode rather than guarding against it.
public struct PrivacyState: Codable, Equatable, Sendable {
    /// Device preferences, not per-server.
    public var lockPolicy: PrivacyLockPolicy = .onLeaving
    /// Seconds of absence before `.afterTimeout` re-locks.
    public var lockTimeout: TimeInterval = 300
    /// Keyed by the normalised server URL held in `AppSettings.serverUrl`.
    public var byServer: [String: HiddenContent] = [:]

    public init() {}

    public func content(for serverUrl: String) -> HiddenContent { byServer[serverUrl] ?? HiddenContent() }

    public mutating func update(_ serverUrl: String, _ change: (inout HiddenContent) -> Void) {
        var content = byServer[serverUrl] ?? HiddenContent()
        change(&content)
        // Don't accumulate empty entries for every server the user has ever visited.
        byServer[serverUrl] = content.isEmpty ? nil : content
    }

    // MARK: - Decoding

    private enum CodingKeys: String, CodingKey {
        case lockPolicy, lockTimeout, byServer
        // Legacy (flat, single-server) payload.
        case libraries, series, books, serverUrl
    }

    /// Accepts both the current shape and the legacy flat one.
    ///
    /// This has to be hand-written: `GRDBHiddenContentStore.load()` turns a decode failure into `nil`,
    /// which makes the defaults get re-saved — so a decoder that simply rejected the old payload would
    /// silently erase whatever the user had hidden before the upgrade.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lockPolicy = try container.decodeIfPresent(PrivacyLockPolicy.self, forKey: .lockPolicy) ?? .onLeaving
        lockTimeout = try container.decodeIfPresent(TimeInterval.self, forKey: .lockTimeout) ?? 300

        if let byServer = try container.decodeIfPresent([String: HiddenContent].self, forKey: .byServer) {
            self.byServer = byServer
            return
        }

        var legacy = HiddenContent()
        legacy.libraries = try container.decodeIfPresent(Set<KomgaLibraryId>.self, forKey: .libraries) ?? []
        legacy.series = try container.decodeIfPresent(Set<KomgaSeriesId>.self, forKey: .series) ?? []
        legacy.books = try container.decodeIfPresent(Set<KomgaBookId>.self, forKey: .books) ?? []
        let serverUrl = try container.decodeIfPresent(String.self, forKey: .serverUrl) ?? ""
        // An empty `serverUrl` can only come from a set written before any login, which cannot contain
        // real ids — there was nothing to hide yet. Keep the preferences, drop the (empty) sets.
        byServer = (legacy.isEmpty || serverUrl.isEmpty) ? [:] : [serverUrl: legacy]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lockPolicy, forKey: .lockPolicy)
        try container.encode(lockTimeout, forKey: .lockTimeout)
        try container.encode(byServer, forKey: .byServer)
    }
}

/// When the private area re-locks. Exposed in full to the user, who picks the trade-off they want.
public enum PrivacyLockPolicy: String, Codable, CaseIterable, Sendable {
    /// Locks as soon as the app is backgrounded. Safest.
    case onLeaving
    /// Stays unlocked for `lockTimeout` seconds of absence.
    case afterTimeout
    /// One unlock per app launch; `isUnlocked` is memory-only, so process death clears it.
    case untilAppQuits
}

public typealias PrivacyStateRepository = SettingsState<PrivacyState>
