// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "lidwatch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "lidwatch", targets: ["lidwatch"]),
        .executable(name: "LidwatchApp", targets: ["LidwatchApp"]),
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
        ),
        .executableTarget(
            name: "LidwatchApp",
            dependencies: ["LidwatchCore"]
        ),
        .target(
            name: "LidwatchCore"
        ),
        .testTarget(
            name: "LidwatchCoreTests",
            dependencies: ["LidwatchCore"],
            swiftSettings: [
                .unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-framework", "Testing",
                    "-Xlinker", "-rpath", "-Xlinker",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath", "-Xlinker",
                    "/Library/Developer/CommandLineTools/Library/Developer/usr/lib",
                ]),
            ]
        ),
    ]
)
