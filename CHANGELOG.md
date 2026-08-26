# Unreleased

- [FIXED] Require OpenFeature Swift SDK 0.3.1 for Swift Package Manager so the advertised watchOS and tvOS platforms use the first upstream release that supports them.
- [FIXED] Align the shared Xcode configuration with the watchOS 8 deployment target declared by the package.
- [CHANGED] Raise the minimum supported watchOS version from 7 to 8.
- [CHANGED] Make generic watchOS and tvOS device builds and cross-package platform compatibility validation required CI checks.
- [CHANGED] Automate release PR preparation, tagging, package publication, GitHub Release creation, and back-merge setup.

# 0.2.0 / 2026-07-02

- [FEATURE] Implement `observe()` and STALE state support. See [#21](https://github.com/DataDog/dd-openfeature-provider-swift/pull/21)
- [CHANGED] Raise the minimum macOS deployment target from 12.0 to 12.6 to match dd-sdk-ios 3.13.0. See [#21](https://github.com/DataDog/dd-openfeature-provider-swift/pull/21)
- [FIXED] Thread flag metadata (`allocationKey`) into OpenFeature `flagMetadata` instead of always returning empty. See [#23](https://github.com/DataDog/dd-openfeature-provider-swift/pull/23)

# 0.1.0 / 2026-01-14

Initial release of Datadog's Provider for the OpenFeature iOS SDK.

- [FEATURE] Support for OpenFeature Boolean, String, Integer, Double, and Object flag types
- [FEATURE] Integration with Datadog Feature Flags client
- [FEATURE] Context management and conversion between OpenFeature and Datadog formats
- [FEATURE] Swift Package Manager and CocoaPods integration
