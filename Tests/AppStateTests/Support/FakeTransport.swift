import Foundation
@testable import AppState

actor FakeTransport: Transport {
    enum Behavior {
        case alwaysAccept
        case alwaysReject(status: Int, body: String)
        case alwaysRetryable(reason: String)
        case scripted([TransportOutcome])
    }

    private(set) var sent: [Event] = []
    private var behavior: Behavior
    private var scriptIndex = 0

    init(behavior: Behavior = .alwaysAccept) {
        self.behavior = behavior
    }

    func setBehavior(_ behavior: Behavior) {
        self.behavior = behavior
        self.scriptIndex = 0
    }

    func send(_ event: Event) async throws -> TransportOutcome {
        sent.append(event)

        switch behavior {
        case .alwaysAccept:
            return .accepted
        case .alwaysReject(let status, let body):
            return .rejected(status: status, body: body)
        case .alwaysRetryable(let reason):
            return .retryable(reason: reason)
        case .scripted(let outcomes):
            guard scriptIndex < outcomes.count else {
                return .accepted
            }
            let outcome = outcomes[scriptIndex]
            scriptIndex += 1
            return outcome
        }
    }
}

struct InstantClock: Clock {
    func now() -> Date { Date() }
    func sleep(seconds: TimeInterval) async throws { /* no-op */ }
}
