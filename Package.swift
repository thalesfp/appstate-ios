// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppState",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "AppState", targets: ["AppState"]),
    ],
    targets: [
        .target(
            name: "AppState",
            path: "Sources/AppState",
            resources: [
                .copy("Resources/PrivacyInfo.xcprivacy"),
            ]
        ),
        .testTarget(
            name: "AppStateTests",
            dependencies: ["AppState"],
            path: "Tests/AppStateTests"
        ),
    ]
)
