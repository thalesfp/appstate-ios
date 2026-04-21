import Foundation

public protocol TraitsTransport: Sendable {
    func setTraits(userId: String, traits: [String: TraitValue]) async throws -> TraitsUpdateOutcome
}

public enum TraitsUpdateOutcome: Equatable, Sendable {
    case accepted
    case rejected(status: Int, body: String)
    case retryable(reason: String)
}
