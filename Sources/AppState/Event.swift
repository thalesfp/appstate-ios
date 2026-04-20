import Foundation

public enum LogLevel: String, Codable, Sendable, CaseIterable {
    case debug
    case info
    case warn
    case error
    case fatal
}

public struct Event: Codable, Sendable, Equatable {
    public let name: String
    public let level: LogLevel
    public let message: String
    public let metadata: [String: MetadataValue]
    public let timestamp: Date

    public init(
        name: String,
        level: LogLevel = .info,
        message: String = "",
        metadata: [String: MetadataValue] = [:],
        timestamp: Date = Date()
    ) {
        self.name = name
        self.level = level
        self.message = message
        self.metadata = metadata
        self.timestamp = timestamp
    }

    private enum CodingKeys: String, CodingKey {
        case name, level, message, metadata, timestamp
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(level, forKey: .level)
        try container.encode(message, forKey: .message)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(Self.isoFormatter.string(from: timestamp), forKey: .timestamp)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.level = try container.decode(LogLevel.self, forKey: .level)
        self.message = try container.decode(String.self, forKey: .message)
        self.metadata = try container.decodeIfPresent([String: MetadataValue].self, forKey: .metadata) ?? [:]

        let timestampString = try container.decode(String.self, forKey: .timestamp)
        guard let parsed = Self.isoFormatter.date(from: timestampString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .timestamp,
                in: container,
                debugDescription: "timestamp is not a valid ISO 8601 date: \(timestampString)"
            )
        }
        self.timestamp = parsed
    }

    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
