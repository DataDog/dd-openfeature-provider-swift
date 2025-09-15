// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DataDogOpenFeatureProvider",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .watchOS(.v7),
        .tvOS(.v14),
    ],
    products: [
        .library(
            name: "DataDogOpenFeatureProvider",
            targets: ["DataDogOpenFeatureProvider"]),
    ],
    dependencies: [
        .package(url: "https://github.com/open-feature/swift-sdk.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "DataDogOpenFeatureProvider",
            dependencies: [
                .product(name: "OpenFeature", package: "swift-sdk")
            ]),
        .testTarget(
            name: "DataDogOpenFeatureProviderTests",
            dependencies: ["DataDogOpenFeatureProvider"]
        ),
    ]
)
