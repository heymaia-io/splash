import Foundation

// Port of snd.komga.client.search.KomgaSearchOperator.
// Wire format: `{"operator": "<name>", "value"|"dateTime"|"duration": ...}` (JsonClassDiscriminator("operator")).
// Kotlin models one generic `Is<T>` shared by several sealed interfaces; Swift uses one enum per
// operator family so each condition only admits the operators the server accepts.

public typealias SearchValue = Codable & Hashable & Sendable

private enum OperatorKeys: String, CodingKey {
    case `operator`, value, dateTime, duration
}

private func decodeOperatorName(_ decoder: Decoder) throws -> (String, KeyedDecodingContainer<OperatorKeys>) {
    let c = try decoder.container(keyedBy: OperatorKeys.self)
    return (try c.decode(String.self, forKey: .operator), c)
}

private func unknownOperator(_ name: String, _ c: KeyedDecodingContainer<OperatorKeys>) -> DecodingError {
    .dataCorruptedError(forKey: .operator, in: c, debugDescription: "Unsupported operator '\(name)'")
}

/// `KomgaSearchOperator.Equality<T>`: is / isNot
public enum EqualityOp<T: SearchValue>: SearchValue {
    case isEqualTo(T)
    case isNotEqualTo(T)

    public init(from decoder: Decoder) throws {
        let (name, c) = try decodeOperatorName(decoder)
        switch name {
        case "is": self = .isEqualTo(try c.decode(T.self, forKey: .value))
        case "isNot": self = .isNotEqualTo(try c.decode(T.self, forKey: .value))
        default: throw unknownOperator(name, c)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: OperatorKeys.self)
        switch self {
        case .isEqualTo(let v): try c.encode("is", forKey: .operator); try c.encode(v, forKey: .value)
        case .isNotEqualTo(let v): try c.encode("isNot", forKey: .operator); try c.encode(v, forKey: .value)
        }
    }
}

/// `KomgaSearchOperator.EqualityNullable<T>`: is / isNot / isNull / isNotNull
public enum EqualityNullableOp<T: SearchValue>: SearchValue {
    case isEqualTo(T)
    case isNotEqualTo(T)
    case isNull
    case isNotNull

    public init(from decoder: Decoder) throws {
        let (name, c) = try decodeOperatorName(decoder)
        switch name {
        case "is": self = .isEqualTo(try c.decode(T.self, forKey: .value))
        case "isNot": self = .isNotEqualTo(try c.decode(T.self, forKey: .value))
        case "isNull": self = .isNull
        case "isNotNull": self = .isNotNull
        default: throw unknownOperator(name, c)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: OperatorKeys.self)
        switch self {
        case .isEqualTo(let v): try c.encode("is", forKey: .operator); try c.encode(v, forKey: .value)
        case .isNotEqualTo(let v): try c.encode("isNot", forKey: .operator); try c.encode(v, forKey: .value)
        case .isNull: try c.encode("isNull", forKey: .operator)
        case .isNotNull: try c.encode("isNotNull", forKey: .operator)
        }
    }
}

/// `KomgaSearchOperator.StringOp`
public enum StringOp: SearchValue {
    case isEqualTo(String)
    case isNotEqualTo(String)
    case contains(String)
    case doesNotContain(String)
    case beginsWith(String)
    case doesNotBeginWith(String)
    case endsWith(String)
    case doesNotEndWith(String)

    private var wire: (String, String) {
        switch self {
        case .isEqualTo(let v): ("is", v)
        case .isNotEqualTo(let v): ("isNot", v)
        case .contains(let v): ("contains", v)
        case .doesNotContain(let v): ("doesNotContain", v)
        case .beginsWith(let v): ("beginsWith", v)
        case .doesNotBeginWith(let v): ("doesNotBeginWith", v)
        case .endsWith(let v): ("endsWith", v)
        case .doesNotEndWith(let v): ("doesNotEndWith", v)
        }
    }

    private static let factories: [String: @Sendable (String) -> StringOp] = [
        "is": StringOp.isEqualTo, "isNot": StringOp.isNotEqualTo, "contains": StringOp.contains,
        "doesNotContain": StringOp.doesNotContain, "beginsWith": StringOp.beginsWith,
        "doesNotBeginWith": StringOp.doesNotBeginWith, "endsWith": StringOp.endsWith,
        "doesNotEndWith": StringOp.doesNotEndWith,
    ]

    public init(from decoder: Decoder) throws {
        let (name, c) = try decodeOperatorName(decoder)
        guard let factory = Self.factories[name] else { throw unknownOperator(name, c) }
        self = factory(try c.decode(String.self, forKey: .value))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: OperatorKeys.self)
        let (name, value) = wire
        try c.encode(name, forKey: .operator)
        try c.encode(value, forKey: .value)
    }
}

/// `KomgaSearchOperator.Numeric<T>`
public enum NumericOp<T: SearchValue>: SearchValue {
    case isEqualTo(T)
    case isNotEqualTo(T)
    case greaterThan(T)
    case lessThan(T)

    public init(from decoder: Decoder) throws {
        let (name, c) = try decodeOperatorName(decoder)
        let value = try c.decode(T.self, forKey: .value)
        switch name {
        case "is": self = .isEqualTo(value)
        case "isNot": self = .isNotEqualTo(value)
        case "greaterThan": self = .greaterThan(value)
        case "lessThan": self = .lessThan(value)
        default: throw unknownOperator(name, c)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: OperatorKeys.self)
        let (name, value): (String, T) = switch self {
        case .isEqualTo(let v): ("is", v)
        case .isNotEqualTo(let v): ("isNot", v)
        case .greaterThan(let v): ("greaterThan", v)
        case .lessThan(let v): ("lessThan", v)
        }
        try c.encode(name, forKey: .operator)
        try c.encode(value, forKey: .value)
    }
}

/// `KomgaSearchOperator.NumericNullable<T>`
public enum NumericNullableOp<T: SearchValue>: SearchValue {
    case isEqualTo(T)
    case isNotEqualTo(T)
    case greaterThan(T)
    case lessThan(T)
    case isNull
    case isNotNull

    public init(from decoder: Decoder) throws {
        let (name, c) = try decodeOperatorName(decoder)
        switch name {
        case "isNull": self = .isNull
        case "isNotNull": self = .isNotNull
        default:
            let value = try c.decode(T.self, forKey: .value)
            switch name {
            case "is": self = .isEqualTo(value)
            case "isNot": self = .isNotEqualTo(value)
            case "greaterThan": self = .greaterThan(value)
            case "lessThan": self = .lessThan(value)
            default: throw unknownOperator(name, c)
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: OperatorKeys.self)
        switch self {
        case .isNull: try c.encode("isNull", forKey: .operator)
        case .isNotNull: try c.encode("isNotNull", forKey: .operator)
        case .isEqualTo(let v): try c.encode("is", forKey: .operator); try c.encode(v, forKey: .value)
        case .isNotEqualTo(let v): try c.encode("isNot", forKey: .operator); try c.encode(v, forKey: .value)
        case .greaterThan(let v): try c.encode("greaterThan", forKey: .operator); try c.encode(v, forKey: .value)
        case .lessThan(let v): try c.encode("lessThan", forKey: .operator); try c.encode(v, forKey: .value)
        }
    }
}

/// `KomgaSearchOperator.Date`
public enum DateOp: SearchValue {
    case before(Date)
    case after(Date)
    case isInTheLast(KomgaDuration)
    case isNotInTheLast(KomgaDuration)
    case isNull
    case isNotNull

    public init(from decoder: Decoder) throws {
        let (name, c) = try decodeOperatorName(decoder)
        switch name {
        case "before": self = .before(try c.decode(Date.self, forKey: .dateTime))
        case "after": self = .after(try c.decode(Date.self, forKey: .dateTime))
        case "isInTheLast": self = .isInTheLast(try c.decode(KomgaDuration.self, forKey: .duration))
        case "isNotInTheLast": self = .isNotInTheLast(try c.decode(KomgaDuration.self, forKey: .duration))
        case "isNull": self = .isNull
        case "isNotNull": self = .isNotNull
        default: throw unknownOperator(name, c)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: OperatorKeys.self)
        switch self {
        case .before(let d): try c.encode("before", forKey: .operator); try c.encode(d, forKey: .dateTime)
        case .after(let d): try c.encode("after", forKey: .operator); try c.encode(d, forKey: .dateTime)
        case .isInTheLast(let d): try c.encode("isInTheLast", forKey: .operator); try c.encode(d, forKey: .duration)
        case .isNotInTheLast(let d):
            try c.encode("isNotInTheLast", forKey: .operator); try c.encode(d, forKey: .duration)
        case .isNull: try c.encode("isNull", forKey: .operator)
        case .isNotNull: try c.encode("isNotNull", forKey: .operator)
        }
    }
}

/// `KomgaSearchOperator.Boolean`
public enum BooleanOp: String, SearchValue {
    case isTrue
    case isFalse

    private enum Keys: String, CodingKey { case `operator` }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let name = try c.decode(String.self, forKey: .operator)
        guard let value = BooleanOp(rawValue: name) else {
            throw DecodingError.dataCorruptedError(forKey: .operator, in: c, debugDescription: "Unknown \(name)")
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(rawValue, forKey: .operator)
    }
}
