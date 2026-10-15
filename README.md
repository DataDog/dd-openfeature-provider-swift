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

### Evaluation telemetry control

This capability requires the companion native SDK change that adds `FlagsClient.Configuration`. It is not available with the current minimum SDK version. Before releasing this provider change, update the package and podspec minimum versions to the native release that includes the API. For local validation, see [Local native SDK validation](Tests/LocalRuntime/README.md).

Enable the control when creating the provider:

```swift
let provider = DatadogProvider(enableEvaluationTelemetryOptOutParameter: true)
let context = MutableContext(
    targetingKey: "user123",
    structure: MutableStructure(attributes: [
        "dd_evaluation_telemetry_opt_out": .boolean(true)
    ])
)
await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context)
```

The original `DatadogProvider(name:core:)` initializer leaves the control disabled. When enabled, only typed boolean `true` suppresses new evaluation events, counts, and automatic RUM flag annotations. Missing, false, null, strings, numbers, and other types preserve telemetry.

Change the policy through `OpenFeatureAPI.setEvaluationContextAndWait(evaluationContext:)`. Changes to only this reserved attribute apply locally. They do not request assignments, clear cached values, or change native readiness. The native client consumes this attribute before assignment requests. Genuine targeting changes retain normal refresh behavior.

Flag values, details, exposures, unrelated telemetry, and customer hooks remain unchanged. Each named client keeps its own configuration. Reusing a name keeps its original configuration. The control does not remove previously recorded events or RUM annotations.

Exposure events can still contain subject data. This control does not replace SDK tracking consent.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines and [DEVELOPMENT.md](DEVELOPMENT.md) for detailed setup instructions, testing guidelines, and development workflow.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
