// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DatadogOpenFeatureProvider",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .watchOS(.v7),
        .tvOS(.v14),
    ],
    products: [
        .library(
            name: "DatadogOpenFeatureProvider",
            targets: ["DatadogOpenFeatureProvider"]),
    ],
    dependencies: [
        .package(url: "https://github.com/open-feature/swift-sdk.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "DatadogOpenFeatureProvider",
            dependencies: [
                .product(name: "OpenFeature", package: "swift-sdk")
            ]),
        .testTarget(
            name: "DatadogOpenFeatureProviderTests",
            dependencies: ["DatadogOpenFeatureProvider"]
        ),
    ]
)
