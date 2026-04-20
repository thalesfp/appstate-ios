import Foundation

public enum MetadataValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([MetadataValue])
    case object([String: MetadataValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }

        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }

        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }

        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }

        if let value = try? container.decode([MetadataValue].self) {
            self = .array(value)
            return
        }

        if let value = try? container.decode([String: MetadataValue].self) {
            self = .object(value)
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "unsupported metadata value"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

extension MetadataValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension MetadataValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .int(value) }
}

extension MetadataValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .double(value) }
}

extension MetadataValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension MetadataValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .null }
}

extension MetadataValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: MetadataValue...) { self = .array(elements) }
}

extension MetadataValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, MetadataValue)...) {
        var dict: [String: MetadataValue] = [:]
        for (key, value) in elements {
            dict[key] = value
        }
        self = .object(dict)
    }
}
