import Foundation
import KomgaAPI

/// Port of `snd.komelia.offline.server.model.OfflineMediaServerId`.
public struct OfflineMediaServerId: KomgaIdentifier {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static func random() -> OfflineMediaServerId { OfflineMediaServerId(UUID().uuidString.lowercased()) }
}

/// Port of `OfflineMediaServer` — one Komga server whose content has been downloaded.
public struct OfflineMediaServer: Hashable, Sendable, Identifiable {
    public var id: OfflineMediaServerId
    public var url: String

    public init(id: OfflineMediaServerId = .random(), url: String) {
        self.id = id
        self.url = url
    }
}

/// Port of `snd.komelia.offline.user.model.OfflineUser`.
public struct OfflineUser: Hashable, Sendable, Identifiable {
    /// `OfflineUser.ROOT` — the local user seeded by the offline migration (no server).
    public static let root = KomgaUserId("0")

    public var id: KomgaUserId
    public var serverId: OfflineMediaServerId?
    public var email: String
    public var roles: Set<String>
    public var sharedAllLibraries: Bool
    public var sharedLibrariesIds: Set<KomgaLibraryId>
    public var labelsAllow: Set<String>
    public var labelsExclude: Set<String>
    public var ageRestriction: KomgaAgeRestriction?

    public init(
        id: KomgaUserId, serverId: OfflineMediaServerId?, email: String, roles: Set<String> = [],
        sharedAllLibraries: Bool = true, sharedLibrariesIds: Set<KomgaLibraryId> = [],
        labelsAllow: Set<String> = [], labelsExclude: Set<String> = [], ageRestriction: KomgaAgeRestriction? = nil
    ) {
        // Kotlin `init { check(id != ROOT || serverId == null) }` — a programmer error, not a runtime condition.
        precondition(id != Self.root || serverId == nil, "root user can't have serverId")
        self.id = id
        self.serverId = serverId
        self.email = email
        self.roles = roles
        self.sharedAllLibraries = sharedAllLibraries
        self.sharedLibrariesIds = sharedLibrariesIds
        self.labelsAllow = labelsAllow
        self.labelsExclude = labelsExclude
        self.ageRestriction = ageRestriction
    }

    public func toKomgaUser() -> KomgaUser {
        KomgaUser(
            id: id, email: email, roles: roles, sharedAllLibraries: sharedAllLibraries,
            sharedLibrariesIds: sharedLibrariesIds, labelsAllow: labelsAllow, labelsExclude: labelsExclude,
            ageRestriction: ageRestriction)
    }
}

extension KomgaUser {
    /// `KomgaUser.toOfflineUser(serverId)`
    public func toOfflineUser(serverId: OfflineMediaServerId) -> OfflineUser {
        OfflineUser(
            id: id, serverId: serverId, email: email, roles: roles, sharedAllLibraries: sharedAllLibraries,
            sharedLibrariesIds: sharedLibrariesIds, labelsAllow: labelsAllow, labelsExclude: labelsExclude,
            ageRestriction: ageRestriction)
    }
}

/// Port of `snd.komelia.offline.library.model.OfflineLibrary` — a `KomgaLibrary` snapshot owned by a server.
public struct OfflineLibrary: Hashable, Sendable, Identifiable {
    public var mediaServerId: OfflineMediaServerId
    /// Every Komga library field; the offline copy never diverges from the server shape.
    public var library: KomgaLibrary

    public var id: KomgaLibraryId { library.id }
    public var name: String { library.name }
    public var seriesCover: SeriesCover { library.seriesCover }

    public init(mediaServerId: OfflineMediaServerId, library: KomgaLibrary) {
        self.mediaServerId = mediaServerId
        self.library = library
    }
}

extension KomgaLibrary {
    /// `KomgaLibrary.toOfflineLibrary(serverId)`
    public func toOfflineLibrary(serverId: OfflineMediaServerId) -> OfflineLibrary {
        OfflineLibrary(mediaServerId: serverId, library: self)
    }
}
