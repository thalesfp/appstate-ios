import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(WatchKit)
import WatchKit
#endif

public enum AutoContext {
    public static func snapshot() -> [String: MetadataValue] {
        var ctx: [String: MetadataValue] = [
            "sdk": "appstate-ios",
            "sdk_version": Self.sdkVersion,
            "os": Self.osName,
            "os_version": .string(ProcessInfo.processInfo.operatingSystemVersionString),
            "device_model": .string(Self.deviceModel),
        ]

        if let bundleId = Bundle.main.bundleIdentifier {
            ctx["bundle_id"] = .string(bundleId)
        }

        let info = Bundle.main.infoDictionary

        if let appVersion = info?["CFBundleShortVersionString"] as? String {
            ctx["app_version"] = .string(appVersion)
        }

        if let appBuild = info?["CFBundleVersion"] as? String {
            ctx["app_build"] = .string(appBuild)
        }

        ctx["locale"] = .string(Locale.current.identifier)

        return ctx
    }

    static let sdkVersion: MetadataValue = "0.1.0"

    static var osName: MetadataValue {
        #if os(iOS)
        return "ios"
        #elseif os(macOS)
        return "macos"
        #elseif os(tvOS)
        return "tvos"
        #elseif os(watchOS)
        return "watchos"
        #elseif os(visionOS)
        return "visionos"
        #else
        return "unknown"
        #endif
    }

    static var deviceModel: String {
        #if os(macOS)
        return hardwareModel() ?? "mac"
        #elseif os(watchOS)
        return WKInterfaceDevice.current().model
        #elseif canImport(UIKit)
        return UIDevice.current.model
        #else
        return "unknown"
        #endif
    }

    private static func hardwareModel() -> String? {
        var size: Int = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)

        guard size > 0 else { return nil }

        var buffer = [CChar](repeating: 0, count: size)
        let result = sysctlbyname("hw.model", &buffer, &size, nil, 0)

        guard result == 0 else { return nil }

        return String(cString: buffer)
    }
}
