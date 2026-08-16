// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InfluencerRatio",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "InfluencerRatio",
            path: "Sources/InfluencerRatio",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
