# Unreleased

- [CHANGED] Install new CocoaPods releases from Git tags. Keep podspecs and consumer smoke tests, and stop automatic publication to CocoaPods Trunk.
- [FEATURE] Add `DatadogProvider(configuration:name:core:)` to configure the native Flags client, including per-subject evaluation telemetry opt-out. Flag evaluation and experiment exposures are preserved.
- [FEATURE] Support the native SDK's experimentation opt-out modes through provider configuration and flag selection through `Flags.Configuration`.
- [FIXED] Translate native evaluation errors from direct provider calls into OpenFeature errors, including invalid experimentation context and missing flags.
- [CHANGED] Require Datadog SDK `>= 3.22.0, < 4.0.0` and Xcode 26 / Swift 6.2 or later. Applications using Xcode 16 must remain on provider 0.3.x with a compatible native SDK. Swift language mode and minimum OS versions are unchanged.

# 0.3.0 / 2026-10-08

- [CHANGED] Require Datadog SDK `>= 3.17.0, < 4.0.0` in Swift Package Manager and CocoaPods.
- [CHANGED] Raise the minimum supported platforms to iOS 15, tvOS 15, and watchOS 9 to match Datadog SDK 3.17.0. macOS 12.6 and visionOS 1 requirements are unchanged. Apps targeting older OS versions must remain on provider `>= 0.2.2, < 0.3.0`.
- [CHANGED] Require at least Xcode 16 and a Swift 6.0+ toolchain for Datadog SDK 3.17.0. Newer SDK versions may require a newer toolchain; SDK 3.19.0 requires Swift 6.2 (Xcode 26 or later). The provider's Swift language mode is unchanged.

# 0.2.2 / 2026-10-08

- [FIXED] Constrain the Datadog SDK dependency to `>= 3.13.0, < 3.17.0` in Swift Package Manager and CocoaPods to preserve the provider's existing deployment targets, including iOS 14.

# 0.2.1 / 2026-08-26

- [FIXED] Require OpenFeature Swift SDK 0.3.1 for Swift Package Manager so the advertised watchOS and tvOS platforms use the first upstream release that supports them.
- [FIXED] Align the shared Xcode configuration with the watchOS 8 deployment target declared by the package.
- [CHANGED] Raise the minimum supported watchOS version from 7 to 8.
- [CHANGED] Make generic watchOS and tvOS device builds and cross-package platform compatibility validation required CI checks.

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
