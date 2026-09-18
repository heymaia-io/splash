import Foundation
import KomgaAPI

/// The set of content the user has marked private, plus the preferences that govern the private area.
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

    /// Server these ids belong to. Komga ids are per-server, so a set carried over to a different server
    /// could both fail to hide the intended items *and* hide unrelated ones whose ids happen to collide.
    /// The set is applied only when this matches the active server, and is never deleted on a mismatch —
    /// the user may switch back.
    public var serverUrl: String = ""

    public var lockPolicy: PrivacyLockPolicy = .onLeaving
    /// Seconds of absence before `.afterTimeout` re-locks.
    public var lockTimeout: TimeInterval = 300

    public init() {}

    public var isEmpty: Bool { libraries.isEmpty && series.isEmpty && books.isEmpty }

    /// Whether this set applies to `serverUrl`. A fresh set (no server recorded yet) adopts the current one.
    public func applies(to activeServerUrl: String) -> Bool {
        serverUrl.isEmpty || serverUrl == activeServerUrl
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

public typealias HiddenContentRepository = SettingsState<HiddenContent>
