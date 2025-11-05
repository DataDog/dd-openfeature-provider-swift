// swift-tools-version: 5.7.1

import PackageDescription

let package = Package(
    name: "api-surface",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "api-surface",
            targets: ["api-surface"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.2"),
        .package(url: "https://github.com/jpsim/SourceKitten", exact: "0.37.2"),
    ],
    targets: [
        .executableTarget(
            name: "api-surface",
            dependencies: [
                "APISurfaceCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "APISurfaceCore",
            dependencies: [
                .product(name: "SourceKittenFramework", package: "SourceKitten"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "APISurfaceCoreTests",
            dependencies: ["APISurfaceCore"]
        ),
    ]
)