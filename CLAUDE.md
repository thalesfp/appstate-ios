# CLAUDE.md

Guidance for working inside the AppState iOS SDK (`sdks/ios/`).

## Premise

This is a telemetry SDK shipped inside customer apps. It observes an app — it must never be the reason that app crashes, hangs, or spikes battery. Every design choice is weighed against that rule first, everything else second.

## Code rules

- **Never crash the host app.** No `fatalError`, no `preconditionFailure`, no force-unwrap of values that could be nil at runtime, no unhandled throws escaping a public API. URL literals built from compile-time-constant strings (e.g. `URL(string: "https://api.appstate.cc")!`) are the only acceptable force-unwraps.
- **Log and degrade on failure.** When a recoverable error occurs (disk-buffer setup, decode failure, network error, file-handle throw), log via `os.Logger` and turn the operation into a safe no-op: drop the event, return `.idle`, skip the corrupt line. Logging to `os.Logger` is not a silent error — it is the platform-appropriate surface.
- **Configuration errors may throw at setup.** Validation of user-supplied `Configuration` input is a contract, not a runtime failure of the SDK itself. Throwing from `Configuration.init` is fine; throwing from `AppState.capture` is not.
- **Design for testability.** Keep side effects (network, disk, clock, lifecycle notifications) behind injectable protocols (`Transport`, `Clock`, a directory URL). Unit tests must run without a real network, real URLSession, real time, or the filesystem's default cache dir.
- **No background thread work on the hot path.** `capture()` must return to the caller in microseconds. Actual I/O is done by the `EventQueue` actor on its own executor; the public facade just enqueues.
- **No unbounded growth.** Every buffer, queue, and retry loop has an explicit cap. The disk outbox is size-capped with FIFO eviction; retries have a max delay; observer lists are released on `stop()`.
- **Readability first.** Intention-revealing names, short functions, shallow nesting. Code in an SDK is read far more than it is written, and customers audit it before adopting.

## Testing

- Unit tests live under `Tests/AppStateTests/` and use `XCTest`.
- Test names follow Given / When / Then form (e.g. `test_givenCorruptLineBetweenValidOnes_whenReading_thenSkipsCorruptAndReturnsValid`) so each reads as a spec for the behavior it protects.
- `FakeTransport` (actor) and `InstantClock` live under `Tests/AppStateTests/Support/` and stand in for `Transport` and `Clock`. `StubURLProtocol` in `HTTPClientTests.swift` intercepts `URLSession` without touching the network.
- Run locally with `swift test` at the SDK root.

## Layout

```
Sources/AppState/
├── AppState.swift            # public facade (configure/capture/flush/shutdown)
├── Client.swift              # internal orchestrator, non-throwing init
├── Configuration.swift       # public Configuration struct + ConfigurationError
├── Event.swift               # Event + LogLevel (ISO 8601 timestamps)
├── MetadataValue.swift       # typed JSON value with expressible-by-literal sugar
├── Context/AutoContext.swift # device/app/os snapshot under `_ctx`
├── Lifecycle/LifecycleObserver.swift  # UIKit + AppKit background/terminate hooks
├── Queue/
│   ├── Clock.swift           # Clock protocol + SystemClock
│   ├── DiskBuffer.swift      # append-only JSONL outbox, size-capped, corruption-tolerant
│   └── EventQueue.swift      # actor; batching, backoff, flush orchestration
├── Transport/
│   ├── Transport.swift       # protocol + TransportOutcome
│   └── HTTPClient.swift      # URLSession + Bearer auth implementation
└── Resources/PrivacyInfo.xcprivacy
```

## Platform matrix

iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1 — chosen to have full Swift Concurrency without back-deploy shims. Do not lower these without discussion; doing so affects every downstream consumer.

## Distribution

Source of truth lives in the public repo `github.com/thalesfp/appstate-ios` (present in the parent monorepo as a git submodule at `sdks/ios`). Releases are tagged on that repo. The monorepo itself is not a publishable SPM package.

## Privacy

`Resources/PrivacyInfo.xcprivacy` must stay accurate: declare any required-reason API the SDK uses (file timestamp, boot time, disk space) and report no tracking and no data collection. App Store review will reject consumers whose embedded SDK manifests lie.
