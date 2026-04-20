import Foundation

public struct Configuration: Sendable {
    public let apiKey: String
    public let baseURL: URL
    public let batchSize: Int
    public let flushInterval: TimeInterval
    public let maxQueueBytes: Int
    public let requestTimeout: TimeInterval
    public let autoContext: Bool
    public let observeLifecycle: Bool

    public init(
        apiKey: String,
        baseURL: URL,
        batchSize: Int = 20,
        flushInterval: TimeInterval = 5,
        maxQueueBytes: Int = 5 * 1024 * 1024,
        requestTimeout: TimeInterval = 30,
        autoContext: Bool = true,
        observeLifecycle: Bool = true
    ) throws {
        guard !apiKey.isEmpty else {
            throw ConfigurationError.missingAPIKey
        }

        guard batchSize > 0 else {
            throw ConfigurationError.invalidBatchSize(batchSize)
        }

        guard flushInterval > 0 else {
            throw ConfigurationError.invalidFlushInterval(flushInterval)
        }

        guard maxQueueBytes > 0 else {
            throw ConfigurationError.invalidMaxQueueBytes(maxQueueBytes)
        }

        self.apiKey = apiKey
        self.baseURL = baseURL
        self.batchSize = batchSize
        self.flushInterval = flushInterval
        self.maxQueueBytes = maxQueueBytes
        self.requestTimeout = requestTimeout
        self.autoContext = autoContext
        self.observeLifecycle = observeLifecycle
    }
}

public enum ConfigurationError: Error, Equatable {
    case missingAPIKey
    case invalidBatchSize(Int)
    case invalidFlushInterval(TimeInterval)
    case invalidMaxQueueBytes(Int)
}
