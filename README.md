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

### Per-subject experimentation opt-out

Enable immediate exclusion when creating the provider:

```swift
let provider = DatadogProvider(experimentationOptOutMode: .immediate)
var attributes: [String: Value] = [:]
if let optedOutAt = user.experimentationOptOutAt {
    attributes["dd_experimentation_opt_out_at"] = .string(
        ISO8601DateFormatter().string(from: optedOutAt)
    )
}
let context = MutableContext(
    targetingKey: user.id,
    structure: MutableStructure(attributes: attributes)
)
await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context)
let enabled = OpenFeatureAPI.shared.getClient().getBooleanValue(key: "new-feature", defaultValue: false)
```

The application supplies the opt-out time as an RFC3339 string. Omit the attribute for subjects who can participate.
Any valid timestamp takes effect immediately, including a future timestamp. It does not schedule exclusion.
The edge skips experiment allocations and continues through ordinary feature allocations. If none match, evaluation returns the application's default.

The native client requires the edge to acknowledge opt-out. It does not reuse eligible assignments when that acknowledgement is missing.
Invalid timestamps also prevent reuse and return defaults. Direct provider calls throw `OpenFeatureError.invalidContextError`.
OpenFeature Swift 0.3.1 reports `GENERAL` from its client while the provider is in the error state.

The default mode is `.disabled`, which ignores this attribute. Use a separate client name for each mode; a named native client keeps its initial configuration.
This control does not disable evaluation telemetry. Immediate withdrawal can change an enrolled subject's experience; account for that change in analysis.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines and [DEVELOPMENT.md](DEVELOPMENT.md) for detailed setup instructions, testing guidelines, and development workflow.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
