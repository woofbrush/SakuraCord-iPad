// swift-tools-version: 6.4
import PackageDescription

// iPadOS build of the SakuraCord app, packaged with xtool
// (`xtool dev build --ipa`). Sources/SakuraCord/Generated is produced from the macOS app.s
// sources; Sources/AppKit implements the AppKit surface they use on top of UIKit, as
// a module named AppKitShim so that dependencies' `canImport(AppKit)` stays false.
let package = Package(
    name: "SakuraCordPad",
    platforms: [.iOS(.v27)],
    products: [.library(name: "SakuraCordPad", targets: ["SakuraCordPad"])],
    dependencies: [
        .package(path: "../Packages/SakuraCordModels"),
        .package(path: "../Packages/DiscordProtocol"),
        .package(path: "../Packages/SakuraCordPersistence"),
        .package(path: "../Packages/MessageRendering"),
        .package(path: "../Packages/MediaPipeline"),
        .package(path: "../Packages/SakuraCordPluginSDK"),
        .package(url: "https://github.com/airbnb/lottie-ios.git", exact: "4.6.1"),
        .package(
            url: "https://github.com/llsc12/hcaptcha",
            revision: "29de12bd290c5cc9c61b3e3c15fe9a9d21449465"
        )
    ],
    targets: [
        .target(
            name: "AppKitShim",
            path: "Sources/AppKit",
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency"), .defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "SakuraCordPad",
            dependencies: [
                "AppKitShim", "SakuraCordModels", "DiscordProtocol", "SakuraCordPersistence",
                "MessageRendering", "MediaPipeline", "SakuraCordPluginSDK",
                .product(name: "Lottie", package: "lottie-ios"),
                .product(name: "HCaptcha", package: "hcaptcha")
            ],
            path: "Sources/SakuraCord",
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .defaultIsolation(MainActor.self),
                .interoperabilityMode(.Cxx)
            ]
        )
    ]
)
