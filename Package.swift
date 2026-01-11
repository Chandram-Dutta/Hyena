// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Hyena",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.0"),
    ],
    targets: [
        .target(
            name: "HyenaParser",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "HyenaIRStore"
        ),
        .target(
            name: "HyenaGraphBuilder",
            dependencies: [
                "HyenaIRStore"
            ]
        ),
        .target(
            name: "HyenaSignalEngine",
            dependencies: [
                "HyenaGraphBuilder"
            ]
        ),
        .target(
            name: "HyenaReporters",
            dependencies: [
                "HyenaIRStore",
                "HyenaGraphBuilder",
                "HyenaSignalEngine"
            ]
        ),
        .target(
            name: "HyenaEngine",
            dependencies: [
                "HyenaParser",
                "HyenaIRStore",
                "HyenaGraphBuilder",
                "HyenaSignalEngine",
                "HyenaReporters",
            ]
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
