# AppState iOS SDK

Swift SDK for sending events to [AppState](https://appstate.cc) from iOS, macOS, tvOS, watchOS and visionOS apps.

## Install

Add the package to your project via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/thalesfp/appstate-ios.git", from: "0.1.0"),
]
```

Or in Xcode: **File → Add Package Dependencies** and paste the URL.

## Platforms

| Platform | Minimum |
|----------|---------|
| iOS      | 15      |
| macOS    | 12      |
| tvOS     | 15      |
| watchOS  | 8       |
| visionOS | 1       |

## Usage

Configure once at app launch:

```swift
import AppState

try? AppState.configure(
    Configuration(apiKey: "ak_live_...")
)
```

`baseURL` defaults to `https://api.appstate.cc`. Override it to point at staging or a local `wrangler dev`.

Capture events anywhere:

```swift
AppState.info("checkout.completed", message: "Order placed", metadata: [
    "order_id": "ord_123",
    "plan": "pro",
    "amount": 4900,
])

AppState.error("sync.failed", message: error.localizedDescription, metadata: [
    "code": "timeout",
])
```

Short-hand methods: `debug`, `info`, `warn`, `error`, `fatal`.

Flush before the app terminates (optional — lifecycle observer does this automatically):

```swift
await AppState.flush()
```

## How it works

- Events are written to a size-capped, append-only JSONL outbox under `Caches/` so they survive relaunches and poor connectivity.
- A background actor batches sends (20 events or 5 s, whichever first) and sends to `POST /v1/events` with `Authorization: Bearer <apiKey>`.
- Lifecycle observers flush on app background / terminate.
- 5xx and network failures retry with exponential backoff up to 60 s; 4xx is a poison message and is dropped.
- `capture()` is non-blocking and never throws — the SDK will never crash your app.

## Auto-context

By default every event carries a `_ctx` metadata object with: `sdk`, `sdk_version`, `os`, `os_version`, `device_model`, `bundle_id`, `app_version`, `app_build`, `locale`.

Opt out with `Configuration(..., autoContext: false)`.

## Configuration options

```swift
try Configuration(
    apiKey: "ak_live_...",
    baseURL: Configuration.defaultBaseURL, // override for staging or local dev
    batchSize: 20,            // events per flush
    flushInterval: 5,         // seconds between automatic flushes
    maxQueueBytes: 5_242_880, // disk cap; oldest events drop past this
    requestTimeout: 30,       // per-request timeout
    autoContext: true,        // attach device/app metadata
    observeLifecycle: false   // call AppState.flush() yourself, or set true to flush on background/terminate
)
```

## Privacy

Ships a `PrivacyInfo.xcprivacy` declaring the required-reason APIs it uses (`FileTimestamp`, `SystemBootTime`, `DiskSpace`) and that it performs no tracking.

## Development

```sh
swift build
swift test
```
