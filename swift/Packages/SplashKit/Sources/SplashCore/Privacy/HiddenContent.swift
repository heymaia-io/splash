import Foundation
import KomgaAPI

/// The ids hidden on **one** Komga server.
///
/// [NUEVO] Komga has no concept of private content, so this is entirely client-side and never reaches the
/// server. It is deliberately *obscurity behind a device-authentication gate*, not encryption: the ids below
/// are stored in plain text in `splash.sqlite`, so anyone with a filesystem backup can see which ids are
/// hidden — not what they contain. Do not describe this feature as a vault.
public struct HiddenContent: Codable, Hashable, Sendable {
    /// Only what the user marked *directly*. Hiding a library hides everything in it and hiding a series
    /// hides its books, but that inheritance is resolved by `HiddenContentFilter`, not stored here.
    public var libraries: Set<KomgaLibraryId> = []
    public var series: Set<KomgaSeriesId> = []
    public var books: Set<KomgaBookId> = []

    public init() {}

    public var isEmpty: Bool { libraries.isEmpty && series.isEmpty && books.isEmpty }
}

/// Everything the privacy feature persists.
///
/// The hidden ids are keyed **by server**, because a Komga id only means anything on the server that issued
/// it. An earlier version kept one flat set plus a `serverUrl` stamp, and every write rewrote that stamp — so
/// hiding something after switching servers silently re-labelled the previous server's ids as belonging to
/// the new one, and switching back left the whole original set inert. Making the server the *key* removes the
/// failure mode instead of guarding against it.
public struct PrivacyState: Codable, Hashable, Sendable {
    /// A device preference, not a per-server one.
    public var lockPolicy: PrivacyLockPolicy = .onLeaving
    /// Seconds of absence before `.afterTimeout` re-locks.
    public var lockTimeout: TimeInterval = 300
    /// Keyed by `AppSettings.serverUrl`.
    public var byServer: [String: HiddenContent] = [:]

    public init() {}

    public func content(for serverUrl: String) -> HiddenContent { byServer[serverUrl] ?? HiddenContent() }

    public mutating func update(_ serverUrl: String, _ change: (inout HiddenContent) -> Void) {
        var content = byServer[serverUrl] ?? HiddenContent()
        change(&content)
        // Don't accumulate an empty entry for every server the user has ever signed into.
        byServer[serverUrl] = content.isEmpty ? nil : content
    }

    // MARK: - Decoding

    private enum CodingKeys: String, CodingKey {
        case lockPolicy, lockTimeout, byServer
    }

    /// Hand-written so an unrecognised payload degrades to "nothing hidden" rather than throwing.
    ///
    /// `GRDBPrivacyStore.load()` turns a decode failure into `nil`, which makes the defaults get re-saved —
    /// so a decoder that rejected an older or newer shape outright would silently *erase* whatever the user
    /// had hidden. Each field is therefore optional, and the lock preferences survive even when the sets
    /// cannot be read.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lockPolicy = (try? container.decodeIfPresent(PrivacyLockPolicy.self, forKey: .lockPolicy)) ?? .onLeaving
        lockTimeout = (try? container.decodeIfPresent(TimeInterval.self, forKey: .lockTimeout)) ?? 300
        byServer = (try? container.decodeIfPresent([String: HiddenContent].self, forKey: .byServer)) ?? [:]
    }
}

/// When the private area re-locks. Exposed in full to the user, who picks the trade-off they want.
public enum PrivacyLockPolicy: String, Codable, CaseIterable, Sendable {
    /// Locks as soon as the app is backgrounded. Safest.
    case onLeaving = "ON_LEAVING"
    /// Stays unlocked for `lockTimeout` seconds of absence.
    case afterTimeout = "AFTER_TIMEOUT"
    /// One unlock per app launch. `PrivacyController.isUnlocked` is memory-only, so process death clears it.
    case untilAppQuits = "UNTIL_APP_QUITS"
}

/// Whole-state repository, like `HomeScreenFilterRepository`.
public typealias PrivacyStateRepository = SettingsState<PrivacyState>
