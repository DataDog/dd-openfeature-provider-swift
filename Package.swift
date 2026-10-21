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
        // FFL-3433: review against the exact protected native artifact. Replace with the
        // first protected release minimum (and matching CocoaPods bound) before publication.
        .package(url: "https://github.com/DataDog/dd-sdk-ios.git", revision: "24f1067d08e5f952e65209c99fe0fafaa4984488"),
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
