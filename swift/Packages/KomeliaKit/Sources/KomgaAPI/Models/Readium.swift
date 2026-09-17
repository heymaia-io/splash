import Foundation

// Port of snd.komga.client.book.Readium.kt / WebPub.kt.
// Only consumed by the EPUB reader (deferred to v1.1); kept so the KomgaBookApi protocol stays 1:1.

public struct R2Device: Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct R2Location: Codable, Hashable, Sendable {
    public var fragment: [String]?
    public var position: Int?
    public var progression: Float?
    public var totalProgression: Float?
    public init(fragment: [String]? = nil, position: Int? = nil, progression: Float? = nil,
                totalProgression: Float? = nil) {
        self.fragment = fragment
        self.position = position
        self.progression = progression
        self.totalProgression = totalProgression
    }
}

public struct R2LocatorText: Codable, Hashable, Sendable {
    public var after: String?
    public var before: String?
    public var highlight: String?
}

public struct R2Locator: Codable, Hashable, Sendable {
    public var href: String
    public var type: String
    public var title: String?
    public var locations: R2Location?
    public var text: R2LocatorText?
    public var koboSpan: String?

    public init(href: String = "", type: String = "", title: String? = nil, locations: R2Location? = nil,
                text: R2LocatorText? = nil, koboSpan: String? = nil) {
        self.href = href
        self.type = type
        self.title = title
        self.locations = locations
        self.text = text
        self.koboSpan = koboSpan
    }

    private enum CodingKeys: String, CodingKey { case href, type, title, locations, text, koboSpan }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        href = try c.decodeIfPresent(String.self, forKey: .href) ?? ""
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title)
        locations = try c.decodeIfPresent(R2Location.self, forKey: .locations)
        text = try c.decodeIfPresent(R2LocatorText.self, forKey: .text)
        koboSpan = try c.decodeIfPresent(String.self, forKey: .koboSpan)
    }
}

public struct R2Progression: Codable, Hashable, Sendable {
    public var modified: Date
    public var device: R2Device
    public var locator: R2Locator
    public init(modified: Date, device: R2Device, locator: R2Locator) {
        self.modified = modified
        self.device = device
        self.locator = locator
    }
}

public struct R2Positions: Codable, Hashable, Sendable {
    public var total: Int
    public var positions: [R2Locator]
}

/// Arbitrary JSON (`kotlinx.serialization.json.JsonElement`).
public indirect enum JSONValue: Codable, Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if try c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
}

public struct WPPublication: Codable, Hashable, Sendable {
    public var context: String?
    public var metadata: WPMetadata
    public var links: [WPLink]
    public var images: [WPLink]
    public var readingOrder: [WPLink]
    public var resources: [WPLink]
    public var toc: [WPLink]
    public var landmarks: [WPLink]
    public var pageList: [WPLink]

    private enum CodingKeys: String, CodingKey {
        case context, metadata, links, images, readingOrder, resources, toc, landmarks, pageList
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        context = try c.decodeIfPresent(String.self, forKey: .context)
        metadata = try c.decode(WPMetadata.self, forKey: .metadata)
        links = try c.decode([WPLink].self, forKey: .links)
        images = try c.decodeIfPresent([WPLink].self, forKey: .images) ?? []
        readingOrder = try c.decodeIfPresent([WPLink].self, forKey: .readingOrder) ?? []
        resources = try c.decodeIfPresent([WPLink].self, forKey: .resources) ?? []
        toc = try c.decodeIfPresent([WPLink].self, forKey: .toc) ?? []
        landmarks = try c.decodeIfPresent([WPLink].self, forKey: .landmarks) ?? []
        pageList = try c.decodeIfPresent([WPLink].self, forKey: .pageList) ?? []
    }
}

public struct WPMetadata: Codable, Hashable, Sendable {
    public var title: String
    public var identifier: String?
    public var type: String?
    public var conformsTo: String?
    public var sortAs: String?
    public var subtitle: String?
    public var modified: Date?
    public var published: KomgaLocalDate?
    public var language: String?
    public var author: [String]?
    public var publisher: [String]?
    public var subject: [String]?
    public var readingProgression: WPReadingProgression?
    public var description: String?
    public var numberOfPages: Int?
    public var rendition: [String: JSONValue]?
}

public struct WPLink: Codable, Hashable, Sendable {
    public var title: String?
    public var rel: String?
    public var href: String?
    public var type: String?
    public var templated: Bool?
    public var width: Int?
    public var height: Int?
    public var alternate: [WPLink]?
    public var children: [WPLink]?
    public var properties: [String: [String: JSONValue]]?
}

public enum WPReadingProgression: String, Codable, Hashable, Sendable {
    case rtl, ltr, ttb, btt, auto
}
