# Unreleased

- [FEATURE] Implement `observe()` and STALE state support. See [#21](https://github.com/DataDog/dd-openfeature-provider-swift/pull/21)
- [CHANGED] Raise the minimum macOS deployment target from 12.0 to 12.6 to match dd-sdk-ios 3.13.0. See [#21](https://github.com/DataDog/dd-openfeature-provider-swift/pull/21)
- [FIXED] Thread flag metadata (`allocationKey`) into OpenFeature `flagMetadata` instead of always returning empty. See [#23](https://github.com/DataDog/dd-openfeature-provider-swift/pull/23)

# 0.1.0 / 2026-01-14

Initial release of Datadog's Provider for the OpenFeature iOS SDK.

- [FEATURE] Support for OpenFeature Boolean, String, Integer, Double, and Object flag types
- [FEATURE] Integration with Datadog Feature Flags client
- [FEATURE] Context management and conversion between OpenFeature and Datadog formats
- [FEATURE] Swift Package Manager and CocoaPods integration
