// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "burnrate",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "BurnrateCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "burnrate",
            dependencies: ["BurnrateCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
