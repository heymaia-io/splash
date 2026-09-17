import Foundation

/// JSON configuration matching the Kotlin client (`ignoreUnknownKeys = true`, `encodeDefaults = false`).
/// Foundation's decoder already ignores unknown keys; "defaults not encoded" is handled by `PatchValue`
/// and `encodeIfPresent` for optionals.
public enum KomgaJSON {
    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = KomgaInstant.parse(string) else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Invalid ISO-8601 instant: \(string)")
            }
            return date
        }
        return decoder
    }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(KomgaInstant.format(date))
        }
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

/// kotlin.time.Instant <-> Foundation.Date. Komga emits both `2026-09-17T08:08:36Z`
/// and `2026-09-17T08:10:57.524+00:00`, so parsing tries with and without fractional seconds.
public enum KomgaInstant {
    public static func parse(_ string: String) -> Date? {
        if let date = try? Date(string, strategy: fractional) { return date }
        return try? Date(string, strategy: plain)
    }

    public static func format(_ date: Date) -> String {
        date.formatted(fractional)
    }

    private static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let plain = Date.ISO8601FormatStyle()
}

/// kotlinx.datetime.LocalDate — calendar date without time zone, serialized as `yyyy-MM-dd`.
public struct KomgaLocalDate: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init?(_ string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = KomgaLocalDate(raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid LocalDate: \(raw)")
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: KomgaLocalDate, rhs: KomgaLocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

/// kotlin.time.Duration serialized as ISO-8601 (`PT720H`, `PT1H30M`), which is what
/// kotlinx.serialization emits and `java.time.Duration.parse` on the server accepts.
public struct KomgaDuration: Codable, Hashable, Sendable {
    public let seconds: Int64

    public init(seconds: Int64) { self.seconds = seconds }
    public static func days(_ days: Int) -> KomgaDuration { KomgaDuration(seconds: Int64(days) * 86_400) }

    public var isoString: String {
        if seconds == 0 { return "PT0S" }
        var remainder = abs(seconds)
        let hours = remainder / 3600
        remainder %= 3600
        let minutes = remainder / 60
        let secs = remainder % 60
        var result = seconds < 0 ? "-PT" : "PT"
        if hours > 0 { result += "\(hours)H" }
        if minutes > 0 { result += "\(minutes)M" }
        if secs > 0 { result += "\(secs)S" }
        return result
    }

    public init?(isoString: String) {
        var string = Substring(isoString)
        let negative = string.hasPrefix("-")
        if negative { string = string.dropFirst() }
        guard string.hasPrefix("PT") else { return nil }
        string = string.dropFirst(2)
        var total: Int64 = 0
        var number = ""
        for char in string {
            if char.isNumber || char == "." {
                number.append(char)
                continue
            }
            guard let value = Double(number) else { return nil }
            number = ""
            switch char {
            case "H": total += Int64(value * 3600)
            case "M": total += Int64(value * 60)
            case "S": total += Int64(value)
            default: return nil
            }
        }
        guard number.isEmpty else { return nil }
        seconds = negative ? -total : total
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = KomgaDuration(isoString: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid duration: \(raw)")
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(isoString)
    }
}

/// Decodes an enum leniently: unknown raw values become `nil` instead of failing the whole payload.
/// Mirrors `MediaProfileSerializer` / `KomgaReadingDirectionSerializer` in komga-client.
@propertyWrapper
public struct LenientEnum<Value: RawRepresentable & Hashable & Sendable>: Hashable, Sendable
where Value.RawValue == String {
    public var wrappedValue: Value?
    public init(wrappedValue: Value?) { self.wrappedValue = wrappedValue }
}

extension LenientEnum: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            wrappedValue = nil
        } else {
            wrappedValue = Value(rawValue: try container.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let wrappedValue { try container.encode(wrappedValue.rawValue) } else { try container.encodeNil() }
    }
}

extension KeyedDecodingContainer {
    // Missing key => nil (property wrappers otherwise require the key to be present).
    public func decode<Value>(_ type: LenientEnum<Value>.Type, forKey key: Key) throws -> LenientEnum<Value> {
        try decodeIfPresent(type, forKey: key) ?? LenientEnum(wrappedValue: nil)
    }
}
