# dd-openfeature-provider-swift

## Overview

This package provides a bridge between [OpenFeature](https://openfeature.dev/) and Datadog feature flags, allowing applications to use OpenFeature's standardized interface with Datadog's feature flagging services running under the hood.

## Requirements

- **Xcode 26+ / Swift 6.2+ toolchain** (the provider continues to use Swift 5 language mode)
- **iOS 15.0+ / macOS 12.6+ / watchOS 9.0+ / tvOS 15.0+**

### Datadog SDK Version

Provider 0.4.0 requires Datadog SDK versions `>= 3.22.0, < 4.0.0` and adopts its minimum platform versions. Datadog SDK 3.22.0 requires Swift tools 6.2 for Swift Package Manager.

Applications that need Xcode 16 must remain on provider `>= 0.3.0, < 0.4.0` and select Datadog SDK 3.17.0 or 3.18.0. See the [installation guide](INSTALLATION.md) for details.

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

This capability uses `FlagsClient.Configuration` from Datadog SDK 3.22.0 or later. For runtime validation, see [Native SDK validation](Tests/LocalRuntime/README.md).

Enable the control when creating the provider:

```swift
let provider = DatadogProvider(configuration: .init(enableEvaluationTelemetryOptOutParameter: true))
let context = MutableContext(
    targetingKey: "user123",
    structure: MutableStructure(attributes: [
        "dd_evaluation_telemetry_opt_out": .boolean(true)
    ])
)
await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context)
```

The original `DatadogProvider(name:core:)` initializer leaves the control disabled. When enabled, evaluation telemetry is suppressed until the initial cached policy is known or an explicit context is supplied. After that, only typed boolean `true` opts a subject out of new evaluation events, counts, and automatic RUM flag annotations. Missing, false, null, strings, numbers, and other types do not opt a subject out.

Update the context through `OpenFeatureAPI.setEvaluationContextAndWait(evaluationContext:)`. The attribute remains available in assignment requests, stored context, and exposure attributes. Applications can use it in targeting rules. Changes use the normal assignment refresh and exposure deduplication behavior. Telemetry is suppressed while either the latest requested subject or the subject whose assignments are loaded has opted out. Each subject's latest requested value decides for that subject.

Telemetry suppression does not change flag evaluation, exposure logging, unrelated telemetry, or customer hooks. A targeting rule can change an assignment when the attribute changes. Each named client keeps its own configuration. Reusing a name keeps its original configuration. The control does not remove previously recorded events or RUM annotations.

Exposure events can still contain subject data. This control does not replace SDK tracking consent.

### Flag selection

Configure flag selection when enabling the native Flags feature, before creating a provider:

```swift
Flags.enable(with: .init(
    flagSelection: .init(tags: ["mobile"], keyPatterns: ["checkout-*"])
))
let provider = DatadogProvider()
```

The selection applies to every native client in the same Datadog core. A flag matches any supplied tag or key pattern.
Key patterns match the whole key, and `*` matches any sequence of characters.
The selection is fixed when Flags is enabled. An unsupported or invalid selection can load all flags.
See the [native SDK selection rules](https://github.com/DataDog/dd-sdk-ios/blob/3.22.0/DatadogFlags/Sources/Flags.swift) for limits and fallback behavior.

### Experimentation opt-out

After enabling Flags, configure the provider with a native experimentation opt-out mode:

```swift
let provider = DatadogProvider(configuration: .init(
    experimentationOptOutMode: .immediate
))
let context = MutableContext(
    targetingKey: "user123",
    structure: MutableStructure(attributes: [
        "dd_experimentation_opt_out_at": .string("2026-11-12T12:00:00Z")
    ])
)
await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context)
```

The default mode, `.disabled`, ignores the attribute. `.immediate` excludes experiment allocations for a valid timestamp, including a future timestamp.
`.futureExperimentsOnly` retains experiments activated before the timestamp. It excludes experiments with equal, later, or unknown activation times.
Ordinary feature allocations remain available. Experimentation opt-out does not enable evaluation telemetry suppression.

Supply a timestamp string in the [native SDK's supported format](https://github.com/DataDog/dd-sdk-ios/blob/3.22.0/DatadogFlags/Sources/Models/FlagsEvaluationContext.swift).
In an enabled mode, malformed timestamps fail context initialization or refresh without sending an assignment request.
Provider evaluation methods translate native errors, including `.invalidContext`, into OpenFeature errors.
Reusing a named native client retains its original mode and configuration.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines and [DEVELOPMENT.md](DEVELOPMENT.md) for detailed setup instructions, testing guidelines, and development workflow.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
