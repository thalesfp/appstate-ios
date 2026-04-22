import Foundation
import os

final class Client {
    private let configuration: Configuration
    private let queue: EventQueue?
    private let lifecycle: LifecycleObserver?
    private let autoContext: [String: MetadataValue]
    private let traitsTransport: TraitsTransport
    private let logger = Logger(subsystem: "cc.appstate.sdk", category: "Client")

    init(configuration: Configuration) {
        self.configuration = configuration
        self.autoContext = configuration.autoContext ? AutoContext.snapshot() : [:]

        let transport = HTTPClient(
            apiKey: configuration.apiKey,
            baseURL: configuration.baseURL,
            timeout: configuration.requestTimeout
        )
        self.traitsTransport = transport

        let directory = Self.bufferDirectory()
        let buffer: DiskBuffer?

        do {
            buffer = try DiskBuffer(directory: directory, maxBytes: configuration.maxQueueBytes)
        } catch {
            logger.error("failed to create disk buffer at \(directory.path, privacy: .public): \(String(describing: error), privacy: .public) — SDK will drop events")
            buffer = nil
        }

        guard let buffer else {
            self.queue = nil
            self.lifecycle = nil
            return
        }

        let queue = EventQueue(
            transport: transport,
            buffer: buffer,
            batchSize: configuration.batchSize,
            flushInterval: configuration.flushInterval
        )
        self.queue = queue

        if configuration.observeLifecycle {
            self.lifecycle = LifecycleObserver {
                Task { await queue.flush() }
            }
            self.lifecycle?.start()
        } else {
            self.lifecycle = nil
        }

        Task { await queue.start() }
    }

    func capture(
        name: String,
        level: LogLevel,
        message: String,
        metadata: [String: MetadataValue]
    ) {
        guard let queue else { return }

        let merged = mergeMetadata(metadata)
        let event = Event(name: name, level: level, message: message, metadata: merged)

        Task { await queue.enqueue(event) }
    }

    func flush() async -> EventQueue.FlushOutcome {
        guard let queue else { return .idle }
        return await queue.flush()
    }

    func setTraits(deviceId: String, traits: [String: TraitValue]) async {
        do {
            let outcome = try await traitsTransport.setTraits(deviceId: deviceId, traits: traits)

            switch outcome {
            case .accepted:
                return
            case .rejected(let status, let body):
                logger.error("setTraits rejected (http \(status, privacy: .public)): \(body, privacy: .public)")
            case .retryable(let reason):
                logger.warning("setTraits dropped: \(reason, privacy: .public)")
            }
        } catch {
            // Swallow per SDK host-safety rule — never let the host app see
            // a transport error from a telemetry call.
            logger.error("setTraits threw: \(String(describing: error), privacy: .public)")
        }
    }

    func shutdown() async {
        lifecycle?.stop()
        guard let queue else { return }
        await queue.stop()
        _ = await queue.flush()
    }

    private func mergeMetadata(_ user: [String: MetadataValue]) -> [String: MetadataValue] {
        guard !autoContext.isEmpty else {
            return user
        }

        var result = user
        result["_ctx"] = .object(autoContext)
        return result
    }

    private static func bufferDirectory() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return caches.appendingPathComponent("cc.appstate.sdk")
    }
}
