import Foundation

/// Typed string identifier — Swift equivalent of the Kotlin `@JvmInline value class Komga*Id(val value: String)`.
/// Encodes/decodes as a bare JSON string (RawRepresentable synthesized Codable).
public protocol KomgaIdentifier: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible,
    ExpressibleByStringLiteral where RawValue == String
{
    init(rawValue: String)
}

extension KomgaIdentifier {
    public init(_ value: String) { self.init(rawValue: value) }
    public init(stringLiteral value: String) { self.init(rawValue: value) }
    public var value: String { rawValue }
    public var description: String { rawValue }
}

public struct KomgaBookId: KomgaIdentifier {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct KomgaSeriesId: KomgaIdentifier {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct KomgaLibraryId: KomgaIdentifier {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct KomgaCollectionId: KomgaIdentifier {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct KomgaReadListId: KomgaIdentifier {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct KomgaUserId: KomgaIdentifier {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct KomgaThumbnailId: KomgaIdentifier {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct KomgaAnnouncementId: KomgaIdentifier {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}
