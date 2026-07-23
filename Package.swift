// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "lidwatch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "lidwatch", targets: ["lidwatch"]),
        .library(name: "LidwatchCore", targets: ["LidwatchCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "lidwatch",
            dependencies: [
                "LidwatchCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "LidwatchCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "LidwatchCoreTests",
            dependencies: ["LidwatchCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
