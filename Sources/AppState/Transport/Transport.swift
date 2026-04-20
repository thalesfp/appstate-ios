import Foundation

public protocol Transport: Sendable {
    func send(_ event: Event) async throws -> TransportOutcome
}

public enum TransportOutcome: Equatable, Sendable {
    case accepted
    case rejected(status: Int, body: String)
    case retryable(reason: String)
}

public enum TransportError: Error, Equatable {
    case invalidURL
    case invalidResponse
}
