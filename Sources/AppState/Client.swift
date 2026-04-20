import Foundation

final class Client {
    private let configuration: Configuration
    private let queue: EventQueue
    private let lifecycle: LifecycleObserver?
    private let autoContext: [String: MetadataValue]

    init(configuration: Configuration) {
        self.configuration = configuration
        self.autoContext = configuration.autoContext ? AutoContext.snapshot() : [:]

        let transport = HTTPClient(
            apiKey: configuration.apiKey,
            baseURL: configuration.baseURL,
            timeout: configuration.requestTimeout
        )

        let directory = Self.bufferDirectory()
        let buffer: DiskBuffer

        do {
            buffer = try DiskBuffer(directory: directory, maxBytes: configuration.maxQueueBytes)
        } catch {
            fatalError("AppState: failed to create disk buffer at \(directory.path): \(error)")
        }

        self.queue = EventQueue(
            transport: transport,
            buffer: buffer,
            batchSize: configuration.batchSize,
            flushInterval: configuration.flushInterval
        )

        if configuration.observeLifecycle {
            let queue = self.queue
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
        let merged = mergeMetadata(metadata)
        let event = Event(name: name, level: level, message: message, metadata: merged)

        Task { await queue.enqueue(event) }
    }

    func flush() async -> EventQueue.FlushOutcome {
        await queue.flush()
    }

    func shutdown() async {
        lifecycle?.stop()
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
