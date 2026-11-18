# dd-openfeature-provider-swift

## Overview

This package provides a bridge between [OpenFeature](https://openfeature.dev/) and Datadog feature flags, allowing applications to use OpenFeature's standardized interface with Datadog's feature flagging services running under the hood.

## Requirements

- **Xcode 16.0+ / Swift 6.0+ toolchain with Datadog SDK 3.17.0**; newer SDK releases may require a newer toolchain (the provider continues to use Swift 5 language mode)
- **iOS 15.0+ / macOS 12.6+ / watchOS 9.0+ / tvOS 15.0+**

### Datadog SDK Version

Provider 0.3.0 requires Datadog SDK versions `>= 3.17.0, < 4.0.0` and adopts its minimum platform versions. Datadog SDK 3.17.0 also requires Swift tools 6.0 for Swift Package Manager.

Datadog SDK 3.19.0 requires Swift tools 6.2 (Xcode 26 or later). If you use an older toolchain, select a compatible SDK version within the supported range. See the [installation guide](INSTALLATION.md) for details.

For apps targeting iOS 14, tvOS 14, or watchOS 8, use provider `>= 0.2.2, < 0.3.0` with Datadog SDK `>= 3.13.0, < 3.17.0`. See the [installation guide](INSTALLATION.md) for version constraints.

### OpenFeature SDK Version

Swift Package Manager uses OpenFeature Swift SDK 0.3.1, the first release with watchOS and tvOS support. OpenFeature 0.4 and later require compatibility changes that will be handled separately.

CocoaPods continues to use OpenFeature 0.3.0 because it is the latest version published to CocoaPods. As a result, CocoaPods installation remains iOS-only.

## Installation

- **Swift Package Manager**: iOS 15+, macOS 12.6+, watchOS 9+, and tvOS 15+
- **CocoaPods**: iOS 15+ only (the published OpenFeature 0.3.0 pod does not support tvOS or watchOS)

For installation instructions, see **[INSTALLATION.md](INSTALLATION.md)**.

## Platform Compatibility Validation

Platform support is enforced by a required CI contract in addition to platform builds. Run the same validation locally after changing a dependency or deployment target:

```bash
make platform-compatibility
```

The check verifies that:

- `Package.swift` deployment floors match `xcconfigs/Base.xcconfig`.
- The OpenFeature minimum accepted by Swift Package Manager matches the version pinned and tested in `Package.resolved`.
- Resolved dependency checkouts match their locked revisions.
- OpenFeature and `dd-sdk-ios` explicitly support every advertised iOS, macOS, watchOS, and tvOS target without requiring a higher deployment version.

CI also requires generic watchOS and tvOS device builds. The tvOS job additionally runs the package test suite on an Apple TV simulator.

## Development

See [DEVELOPMENT.md](DEVELOPMENT.md) for detailed development setup, testing, and contribution guidelines.

## Usage

### Quick Start

```swift
import OpenFeature
import DatadogOpenFeatureProvider
import DatadogCore
import DatadogFlags

// 1. Initialize Datadog SDK and enable flags
let config = Datadog.Configuration.builderUsing(
    clientToken: "YOUR_CLIENT_TOKEN",
    environment: "production"
).build()

Datadog.initialize(with: config, trackingConsent: .granted)

let flagsConfig = Flags.Configuration()
Flags.enable(with: flagsConfig)

// 2. Create user context for targeting
let context = MutableContext(targetingKey: "user123")

// 3. Create and register the OpenFeature provider
let provider = DatadogProvider()
await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context)

// 4. Get OpenFeature client and evaluate flags
let client = OpenFeatureAPI.shared.getClient()
let flagValue = client.getBooleanValue(key: "my-feature-flag", defaultValue: false)
```

### Exposures in your own data store

Register `ExposureHook` to receive every evaluation of `DatadogProvider` with the exposure decision that the Datadog SDK uses for Datadog. Set `Flags.Configuration.trackExposures` to `false` to stop sending exposures to Datadog at the same time.

```swift
let flagsConfig = Flags.Configuration(trackExposures: false)
Flags.enable(with: flagsConfig)

OpenFeatureAPI.shared.addHooks(hooks: ExposureHook { evaluation in
    guard evaluation.shouldSend else {
        return
    }
    exposureQueue.enqueue(
        flag: evaluation.flagKey,
        variant: evaluation.variant,
        allocation: evaluation.allocationKey,
        subject: evaluation.targetingKey,
        holdoutKey: evaluation.features["holdout.key"]
    )
})
```

`ExposureEvaluation` has these members:

| Member | Meaning |
| --- | --- |
| `isExposure` | A successful evaluation of an allocation that logs exposures, with a non-blank allocation key and variant, repeats included. |
| `isCacheHit` | For an exposure, the client's exposure cache holds the same allocation, variant and split for the subject and flag. After an exposure of another assignment, or after the cache evicts the entry, the next exposure is new. |
| `shouldSend` | A new exposure (`isExposure` and a cache miss). The Datadog write depends on `trackExposures` and the tracking consent. |
| `features` | Features of the selected split for customer code, for example `holdout.key`, `holdout.assignment_group` and `holdout.should_include_in_holdout_analysis`. |
| `flagKey`, `variant`, `allocationKey`, `targetingKey`, `evaluationContext`, `errorCode` | The evaluation. A failed evaluation has a `nil` `variant` and `allocationKey`, and its `errorCode`. `targetingKey` is `nil` for an evaluation made before any context was set. `evaluationContext` is a copy. |

- Register the hook on `OpenFeatureAPI.shared` or on a client. It reports evaluations of `DatadogProvider` and skips other providers, with one warning.
- The callback runs synchronously in the hook's `finally` stage, on the thread that evaluated the flag, including the main thread. Several threads can call it at the same time, so it must be thread-safe. Keep it short and move I/O to another queue. An evaluation inside the callback calls the hook again, so avoid unbounded recursion.
- The hook catches an error thrown by the callback and leaves the evaluation unchanged. It logs the first error as a warning and later errors at debug level. Swift runtime traps, such as a failed force unwrap, stop the app as usual.
- Each `FlagsClient` deduplicates exposures in memory, for up to 5,000 subject and flag pairs. After the app restarts, the first evaluation of a flag is a new exposure.
- The SDK records each exposure when the flag resolves, for Datadog and for the hook. OpenFeature Swift hooks are non-throwing, so the result that the provider returns is final.
- Flag metadata carries the split features as `__dd_feature.<key>` entries, next to `allocationKey`. The `__dd_feature.` prefix is the stable contract.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines and [DEVELOPMENT.md](DEVELOPMENT.md) for detailed setup instructions, testing guidelines, and development workflow.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
