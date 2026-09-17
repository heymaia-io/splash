import Foundation

/// Tri-state PATCH field — port of `snd.komga.client.common.PatchValue`.
/// - `unset`: key omitted from the JSON body (Kotlin: default value + `encodeDefaults = false`)
/// - `none`: key sent as `null` (clear the field on the server)
/// - `some`: key sent with the value
public enum PatchValue<Value: Encodable & Sendable>: Sendable {
    case unset
    case none
    case some(Value)

    public var isUnset: Bool {
        if case .unset = self { return true }
        return false
    }
}

extension PatchValue: Equatable where Value: Equatable {}
extension PatchValue: Hashable where Value: Hashable {}

extension PatchValue {
    /// `patch(original, patch)` from PatchValue.kt: unchanged -> unset, cleared -> none, changed -> some.
    public static func diff(original: Value?, patch: Value?) -> PatchValue where Value: Equatable {
        if original == patch { return .unset }
        guard let patch else { return .none }
        return .some(patch)
    }
}

extension PatchValue: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .unset:
            throw EncodingError.invalidValue(
                self, .init(codingPath: encoder.codingPath, debugDescription: "PatchValue is unset; the key must be omitted"))
        case .none:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case .some(let value):
            try value.encode(to: encoder)
        }
    }
}

extension KeyedEncodingContainer {
    /// Picked by synthesized `Encodable` conformances over the generic overload, so `.unset`
    /// properties are skipped entirely — the Swift equivalent of `encodeDefaults = false`.
    public mutating func encode<Value>(_ value: PatchValue<Value>, forKey key: Key) throws {
        switch value {
        case .unset: return
        case .none: try encodeNil(forKey: key)
        case .some(let wrapped): try encode(wrapped, forKey: key)
        }
    }
}
