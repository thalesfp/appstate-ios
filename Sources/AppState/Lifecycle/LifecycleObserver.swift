import Foundation

#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

public final class LifecycleObserver {
    private let onBackground: @Sendable () -> Void
    private var observers: [NSObjectProtocol] = []

    public init(onBackground: @escaping @Sendable () -> Void) {
        self.onBackground = onBackground
    }

    public func start() {
        let center = NotificationCenter.default

        #if canImport(UIKit) && !os(watchOS)
        observers.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [onBackground] _ in
            onBackground()
        })

        observers.append(center.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: nil
        ) { [onBackground] _ in
            onBackground()
        })
        #endif

        #if canImport(AppKit)
        observers.append(center.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: nil
        ) { [onBackground] _ in
            onBackground()
        })

        observers.append(center.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: nil
        ) { [onBackground] _ in
            onBackground()
        })
        #endif
    }

    public func stop() {
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
    }

    deinit {
        stop()
    }
}
