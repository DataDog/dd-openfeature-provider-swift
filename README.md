# dd-openfeature-provider-swift

## Overview

This package provides a bridge between [OpenFeature](https://openfeature.dev/) and Datadog feature flags, allowing applications to use OpenFeature's standardized interface with Datadog's feature flagging services running under the hood.

## Requirements

- **Xcode 15.0+**
- **Swift 5.9+**
- **iOS 14.0+ / macOS 12.0+ / watchOS 7.0+ / tvOS 14.0+**

### OpenFeature SDK Version

This provider uses OpenFeature Swift SDK 0.3.0, although there are [newer versions](https://github.com/open-feature/swift-sdk/releases), to match the latest version published on CocoaPods. E.g. this means using `MutableContext` instead of the newer `ImmutableContext`.

## Installation

⚠️ **This package is currently in development and not yet ready for production use.**

Supports **Swift Package Manager** and **CocoaPods** on iOS 14+, macOS 12+, watchOS 7+, and tvOS 14+.

For installation instructions, see **[INSTALLATION.md](INSTALLATION.md)**.

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

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines and [DEVELOPMENT.md](DEVELOPMENT.md) for detailed setup instructions, testing guidelines, and development workflow.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
