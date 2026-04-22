import Foundation
import os

public final class AppState {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var client: Client?
    private static let logger = Logger(subsystem: "cc.appstate.sdk", category: "AppState")

    public static func configure(_ configuration: Configuration) {
        lock.lock()
        defer { lock.unlock() }

        if client != nil {
            logger.warning("AppState.configure called more than once; ignoring")
            return
        }

        client = Client(configuration: configuration)
    }

    public static func capture(
        name: String,
        level: LogLevel = .info,
        message: String = "",
        metadata: [String: MetadataValue] = [:]
    ) {
        guard let client = currentClient() else {
            logger.warning("AppState.capture called before configure; dropping event")
            return
        }

        client.capture(name: name, level: level, message: message, metadata: metadata)
    }

    public static func debug(_ name: String, message: String = "", metadata: [String: MetadataValue] = [:]) {
        capture(name: name, level: .debug, message: message, metadata: metadata)
    }

    public static func info(_ name: String, message: String = "", metadata: [String: MetadataValue] = [:]) {
        capture(name: name, level: .info, message: message, metadata: metadata)
    }

    public static func warn(_ name: String, message: String = "", metadata: [String: MetadataValue] = [:]) {
        capture(name: name, level: .warn, message: message, metadata: metadata)
    }

    public static func error(_ name: String, message: String = "", metadata: [String: MetadataValue] = [:]) {
        capture(name: name, level: .error, message: message, metadata: metadata)
    }

    public static func fatal(_ name: String, message: String = "", metadata: [String: MetadataValue] = [:]) {
        capture(name: name, level: .fatal, message: message, metadata: metadata)
    }

    @discardableResult
    public static func flush() async -> EventQueue.FlushOutcome {
        guard let client = currentClient() else {
            return .idle
        }

        return await client.flush()
    }

    public static func setTraits(deviceId: String, _ traits: [String: TraitValue]) async {
        guard let client = currentClient() else {
            logger.warning("AppState.setTraits called before configure; dropping")
            return
        }

        await client.setTraits(deviceId: deviceId, traits: traits)
    }

    public static func shutdown() async {
        let taken = takeClient()
        await taken?.shutdown()
    }

    private static func takeClient() -> Client? {
        lock.lock()
        defer { lock.unlock() }
        let taken = client
        client = nil
        return taken
    }

    private static func currentClient() -> Client? {
        lock.lock()
        defer { lock.unlock() }
        return client
    }
}
