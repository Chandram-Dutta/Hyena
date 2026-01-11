// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Hyena",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "HyenaEngine"
        ),
        .executableTarget(
            name: "HyenaCLI",
            dependencies: [
                "HyenaEngine",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
