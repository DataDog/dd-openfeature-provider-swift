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
            targets: ["DatadogOpenFeatureProvider"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/open-feature/swift-sdk.git", "0.3.0"..<"0.4.0"),
        .package(url: "https://github.com/DataDog/dd-sdk-ios.git", from: "3.2.0"),
    ],
    targets: [
        .target(
            name: "DatadogOpenFeatureProvider",
            dependencies: [
                .product(name: "DatadogFlags", package: "dd-sdk-ios"),
                .product(name: "OpenFeature", package: "swift-sdk"),
            ]
        ),
        .testTarget(
            name: "DatadogOpenFeatureProviderTests",
            dependencies: [
                "DatadogOpenFeatureProvider",
                .product(name: "DatadogFlags", package: "dd-sdk-ios"),
                .product(name: "OpenFeature", package: "swift-sdk"),
            ]
        ),
    ]
)
