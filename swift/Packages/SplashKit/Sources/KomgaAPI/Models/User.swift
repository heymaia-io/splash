import Foundation

// Port of snd.komga.client.user.*

public struct KomgaUser: Codable, Hashable, Sendable, Identifiable {
    public static let roleUser = "USER"
    public static let roleAdmin = "ADMIN"
    public static let roleFileDownload = "FILE_DOWNLOAD"
    public static let rolePageStreaming = "PAGE_STREAMING"

    public var id: KomgaUserId
    public var email: String
    public var roles: Set<String>
    public var sharedAllLibraries: Bool
    public var sharedLibrariesIds: Set<KomgaLibraryId>
    public var labelsAllow: Set<String>
    public var labelsExclude: Set<String>
    public var ageRestriction: KomgaAgeRestriction?

    public init(
        id: KomgaUserId, email: String, roles: Set<String>, sharedAllLibraries: Bool,
        sharedLibrariesIds: Set<KomgaLibraryId>, labelsAllow: Set<String>, labelsExclude: Set<String>,
        ageRestriction: KomgaAgeRestriction? = nil
    ) {
        self.id = id
        self.email = email
        self.roles = roles
        self.sharedAllLibraries = sharedAllLibraries
        self.sharedLibrariesIds = sharedLibrariesIds
        self.labelsAllow = labelsAllow
        self.labelsExclude = labelsExclude
        self.ageRestriction = ageRestriction
    }

    public var isAdmin: Bool { roles.contains(Self.roleAdmin) }
    public var canDownloadFiles: Bool { roles.contains(Self.roleFileDownload) }
    public var canStreamPages: Bool { roles.contains(Self.rolePageStreaming) }
}

public struct KomgaAgeRestriction: Codable, Hashable, Sendable {
    public var age: Int
    public var restriction: AllowExclude

    public init(age: Int, restriction: AllowExclude) {
        self.age = age
        self.restriction = restriction
    }
}

public enum AllowExclude: String, Codable, Hashable, Sendable {
    case allowOnly = "ALLOW_ONLY"
    case exclude = "EXCLUDE"
}

public struct KomgaUserCreateRequest: Codable, Hashable, Sendable {
    public var email: String
    public var password: String
    public var roles: Set<String>

    public init(email: String, password: String, roles: Set<String>) {
        self.email = email
        self.password = password
        self.roles = roles
    }
}

public struct KomgaSharedLibrariesUpdate: Codable, Hashable, Sendable {
    public var all: Bool
    public var libraryIds: Set<KomgaLibraryId>

    public init(all: Bool, libraryIds: Set<KomgaLibraryId>) {
        self.all = all
        self.libraryIds = libraryIds
    }
}

/// Wire keys follow KomgaUpdateRequestSerializer (note `sharedLibraries` -> `sharedLibrariesIds`).
public struct KomgaUserUpdateRequest: Encodable, Sendable {
    public var ageRestriction: PatchValue<KomgaAgeRestriction> = .unset
    public var labelsAllow: PatchValue<Set<String>> = .unset
    public var labelsExclude: PatchValue<Set<String>> = .unset
    public var roles: PatchValue<Set<String>> = .unset
    public var sharedLibraries: PatchValue<KomgaSharedLibrariesUpdate> = .unset

    private enum CodingKeys: String, CodingKey {
        case ageRestriction, labelsAllow, labelsExclude, roles
        case sharedLibraries = "sharedLibrariesIds"
    }

    public init() {}
}

public struct KomgaAuthenticationActivity: Codable, Hashable, Sendable {
    public var userId: KomgaUserId?
    public var email: String?
    public var ip: String?
    public var userAgent: String?
    public var success: Bool
    public var error: String?
    public var dateTime: Date
    public var source: String
}

// MARK: - Settings (snd.komga.client.settings)

public struct KomgaSettings: Codable, Hashable, Sendable {
    public var deleteEmptyCollections: Bool
    public var deleteEmptyReadLists: Bool
    public var rememberMeDurationDays: Int
    public var thumbnailSize: KomgaThumbnailSize
    public var taskPoolSize: Int
    public var serverPort: SettingMultiSource<Int?>
    public var serverContextPath: SettingMultiSource<String?>
}

public struct SettingMultiSource<T: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    public var configurationSource: T
    public var databaseSource: T
    public var effectiveValue: T

    private enum CodingKeys: String, CodingKey { case configurationSource, databaseSource, effectiveValue }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        configurationSource = try Self.decodeField(c, .configurationSource)
        databaseSource = try Self.decodeField(c, .databaseSource)
        effectiveValue = try Self.decodeField(c, .effectiveValue)
    }

    // T is itself Optional for these settings; a missing key must decode as `null`.
    private static func decodeField(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) throws -> T {
        if !c.contains(key), let nilValue = (Optional<Any>.none as Any) as? T { return nilValue }
        return try c.decode(T.self, forKey: key)
    }
}

public enum KomgaThumbnailSize: String, Codable, Hashable, Sendable, CaseIterable {
    case `default` = "DEFAULT"
    case medium = "MEDIUM"
    case large = "LARGE"
    case xlarge = "XLARGE"
}

public struct KomgaSettingsUpdateRequest: Encodable, Sendable {
    public var deleteEmptyCollections: PatchValue<Bool> = .unset
    public var deleteEmptyReadLists: PatchValue<Bool> = .unset
    public var rememberMeDurationDays: PatchValue<Int> = .unset
    public var renewRememberMeKey: PatchValue<Bool> = .unset
    public var thumbnailSize: PatchValue<KomgaThumbnailSize> = .unset
    public var taskPoolSize: PatchValue<Int> = .unset
    public var serverPort: PatchValue<Int> = .unset
    public var serverContextPath: PatchValue<String> = .unset

    public init() {}
}

// MARK: - Announcements (snd.komga.client.announcements.KomgaJsonFeed)

public struct KomgaJsonFeed: Codable, Hashable, Sendable {
    public var version: String
    public var title: String
    public var homePageUrl: String?
    public var description: String?
    public var items: [KomgaAnnouncement]

    private enum CodingKeys: String, CodingKey {
        case version, title, description, items
        case homePageUrl = "home_page_url"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(String.self, forKey: .version)
        title = try c.decode(String.self, forKey: .title)
        homePageUrl = try c.decodeIfPresent(String.self, forKey: .homePageUrl)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        items = try c.decodeIfPresent([KomgaAnnouncement].self, forKey: .items) ?? []
    }

    public struct KomgaAnnouncement: Codable, Hashable, Sendable, Identifiable {
        public var id: KomgaAnnouncementId
        public var url: String?
        public var title: String?
        public var summary: String?
        public var contentHtml: String?
        public var dateModified: Date?
        public var author: Author?
        public var tags: Set<String>
        public var komgaExtension: KomgaExtension?

        private enum CodingKeys: String, CodingKey {
            case id, url, title, summary, author, tags
            case contentHtml = "content_html"
            case dateModified = "date_modified"
            case komgaExtension = "_komga"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(KomgaAnnouncementId.self, forKey: .id)
            url = try c.decodeIfPresent(String.self, forKey: .url)
            title = try c.decodeIfPresent(String.self, forKey: .title)
            summary = try c.decodeIfPresent(String.self, forKey: .summary)
            contentHtml = try c.decodeIfPresent(String.self, forKey: .contentHtml)
            dateModified = try c.decodeIfPresent(Date.self, forKey: .dateModified)
            author = try c.decodeIfPresent(Author.self, forKey: .author)
            tags = try c.decodeIfPresent(Set<String>.self, forKey: .tags) ?? []
            komgaExtension = try c.decodeIfPresent(KomgaExtension.self, forKey: .komgaExtension)
        }
    }

    public struct Author: Codable, Hashable, Sendable {
        public var name: String?
        public var url: String?
    }

    public struct KomgaExtension: Codable, Hashable, Sendable {
        public var read: Bool
    }
}

// MARK: - Errors (common/ErrorResponse.kt, ViolationErrorResponse.kt)

public struct KomgaErrorResponse: Codable, Hashable, Sendable {
    public var error: String
    public var message: String
    public var path: String
    public var status: Int
    public var timestamp: Date
}

public struct KomgaViolationErrorResponse: Codable, Hashable, Sendable {
    public var violations: [DataViolation]

    public struct DataViolation: Codable, Hashable, Sendable {
        public var fieldName: String
        public var message: String
    }
}

extension KomgaAgeRestriction {
    /// One-line form for the account screen, e.g. "Only under 16" / "Nothing under 18".
    public var summary: String {
        switch restriction {
        case .allowOnly: String(localized: "Only content rated \(age) and under")
        case .exclude: String(localized: "Excludes content rated \(age) and over")
        }
    }
}
