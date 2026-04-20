import Foundation
import os

public actor EventQueue {
    private let transport: Transport
    private let buffer: DiskBuffer
    private let clock: Clock
    private let batchSize: Int
    private let flushInterval: TimeInterval
    private let maxRetryDelay: TimeInterval
    private let logger: Logger

    private var timerTask: Task<Void, Never>?
    private var inflight: Task<FlushOutcome, Never>?
    private var retryDelay: TimeInterval

    public enum FlushOutcome: Equatable {
        case sent(Int)
        case partial(sent: Int, pending: Int)
        case idle
        case failed(reason: String)
    }

    public init(
        transport: Transport,
        buffer: DiskBuffer,
        clock: Clock = SystemClock(),
        batchSize: Int = 20,
        flushInterval: TimeInterval = 5,
        maxRetryDelay: TimeInterval = 60
    ) {
        self.transport = transport
        self.buffer = buffer
        self.clock = clock
        self.batchSize = batchSize
        self.flushInterval = flushInterval
        self.maxRetryDelay = maxRetryDelay
        self.retryDelay = 1
        self.logger = Logger(subsystem: "cc.appstate.sdk", category: "EventQueue")
    }

    public func start() {
        guard timerTask == nil else { return }

        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                let interval = await self.flushInterval

                do {
                    try await self.clock.sleep(seconds: interval)
                } catch {
                    return
                }

                _ = await self.flush()
            }
        }
    }

    public func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    public func enqueue(_ event: Event) {
        do {
            try buffer.append(event)
        } catch {
            logger.error("failed to persist event: \(String(describing: error))")
            return
        }

        let count = (try? buffer.readAll().count) ?? 0

        if count >= batchSize {
            Task { await self.flush() }
        }
    }

    @discardableResult
    public func flush() async -> FlushOutcome {
        if let inflight {
            return await inflight.value
        }

        let task = Task { await self.performFlush() }
        inflight = task

        let outcome = await task.value
        inflight = nil
        return outcome
    }

    private func performFlush() async -> FlushOutcome {
        let pending: [Event]

        do {
            pending = try buffer.readAll()
        } catch {
            logger.error("failed to read buffer: \(String(describing: error))")
            return .failed(reason: "read_buffer")
        }

        guard !pending.isEmpty else {
            return .idle
        }

        var sent = 0
        var retryReason: String?

        for event in pending {
            let outcome: TransportOutcome

            do {
                outcome = try await transport.send(event)
            } catch {
                retryReason = "transport_error"
                break
            }

            switch outcome {
            case .accepted:
                sent += 1
            case .rejected(let status, let body):
                logger.warning("server rejected event (\(status)): \(body)")
                sent += 1
            case .retryable(let reason):
                retryReason = reason
            }

            if retryReason != nil {
                break
            }
        }

        if sent > 0 {
            do {
                try buffer.remove(sent)
            } catch {
                logger.error("failed to trim buffer: \(String(describing: error))")
            }
        }

        if let retryReason {
            await applyBackoff()
            return .partial(sent: sent, pending: pending.count - sent)
        }

        retryDelay = 1
        return .sent(sent)
    }

    private func applyBackoff() async {
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, maxRetryDelay)

        do {
            try await clock.sleep(seconds: delay)
        } catch {
            return
        }
    }
}
