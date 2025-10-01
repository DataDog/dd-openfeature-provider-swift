// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DatadogOpenFeatureProvider",
    platforms: [
        .iOS(.v14),
        .macOS(.v12),
        .watchOS(.v7),
        .tvOS(.v14),
    ],
    products: [
        .library(
            name: "DatadogOpenFeatureProvider",
            targets: ["DatadogOpenFeatureProvider"]),
    ],
    dependencies: [
        .package(url: "https://github.com/open-feature/swift-sdk.git", from: "0.1.0"),
        .package(url: "https://github.com/DataDog/dd-sdk-ios.git", branch: "gonzalezreal/FFL-1016/named-client-support")
    ],
    targets: [
        .target(
            name: "DatadogOpenFeatureProvider",
            dependencies: [
                .product(name: "OpenFeature", package: "swift-sdk"),
                .product(name: "DatadogFlags", package: "dd-sdk-ios")
            ]),
        .testTarget(
            name: "DatadogOpenFeatureProviderTests",
            dependencies: [
                "DatadogOpenFeatureProvider",
                .product(name: "DatadogFlags", package: "dd-sdk-ios"),
                .product(name: "OpenFeature", package: "swift-sdk")
            ]
        ),
    ]
)
