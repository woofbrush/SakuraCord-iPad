// swift-tools-version: 6.4
import PackageDescription

// iPadOS app built with xtool (`xtool dev build --ipa`). It shares the
// platform-neutral packages with the macOS app; AppKit presentation, voice,
// plugins and Sparkle updates stay in App/.
let package = Package(
    name: "SakuraCordPad",
    platforms: [.iOS(.v27)],
    products: [.library(name: "SakuraCordPad", targets: ["SakuraCordPad"])],
    dependencies: [
        .package(path: "../Packages/SakuraCordModels"),
        .package(path: "../Packages/DiscordProtocol"),
        .package(path: "../Packages/MessageRendering"),
        .package(
            url: "https://github.com/llsc12/hcaptcha",
            revision: "29de12bd290c5cc9c61b3e3c15fe9a9d21449465"
        )
    ],
    targets: [
        // Shared/ holds symlinks to the macOS app's platform-neutral sign-in
        // services so both apps run the same authentication code.
        .target(
            name: "SakuraCordPad",
            dependencies: [
                "SakuraCordModels", "DiscordProtocol", "MessageRendering",
                .product(name: "HCaptcha", package: "hcaptcha")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .defaultIsolation(MainActor.self)
            ]
        )
    ]
)
