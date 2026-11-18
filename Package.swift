// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DatadogOpenFeatureProvider",
    platforms: [
        .iOS(.v15),
        .macOS("12.6"),
        .watchOS(.v9),
        .tvOS(.v15),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "DatadogOpenFeatureProvider",
            targets: ["DatadogOpenFeatureProvider"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/open-feature/swift-sdk.git", "0.3.1"..<"0.4.0"),
        // Temporary: DataDog/dd-sdk-ios#3468, until the dd-sdk-ios release that contains getDetailsWithExposure.
        // Then this becomes the release floor.
        .package(url: "https://github.com/DataDog/dd-sdk-ios.git", revision: "2c1b2f3f6db2a653e5459498be6bcd2d89fd0ebc"),
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
