# dd-openfeature-provider-swift

## Overview

This package provides a bridge between [OpenFeature](https://openfeature.dev/)'s vendor-neutral feature flag API and Datadog's flagging client, allowing applications to:

- Use OpenFeature's standardized feature flag interface
- Leverage Datadog's precomputed assignments services
- Support all OpenFeature flag types: Boolean, String, Integer, Double, Object

## Requirements

- **Xcode 15.0+**
- **Swift 5.9+**
- **iOS 14.0+ / macOS 12.0+ / watchOS 7.0+ / tvOS 14.0+**

## Installation

### Prerequisites

1. **Install Xcode** from the Mac App Store or Apple Developer portal
2. **Verify Xcode Command Line Tools** are installed:
   ```bash
   xcode-select --install
   ```

### Swift Package Manager

⚠️ **This package is currently in development and not yet ready for production use.**

Add this package to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/Datadog/dd-openfeature-provider-swift.git", from: "0.1.0")
]
```

Check [releases](https://github.com/DataDog/dd-openfeature-provider-swift/releases) for available versions.

**Requirements:**
- DataDog SDK: 3.2.0+
- OpenFeature Swift SDK: 0.4.0

Or add it through Xcode:
1. **File** → **Add Package Dependencies**
2. Enter: `https://github.com/Datadog/dd-openfeature-provider-swift.git`

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
let context = ImmutableContext(targetingKey: "user123")

// 3. Create and register the OpenFeature provider
let provider = DatadogProvider()
await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context)

// 4. Get OpenFeature client and evaluate flags
let client = OpenFeatureAPI.shared.getClient()
let flagValue = client.getBooleanValue(key: "my-feature-flag", defaultValue: false)
```

### Update With Additional Context Attributes

```swift
// Create detailed user context for advanced targeting
let newContext = ImmutableContext(
    targetingKey: "user123",
    structure: ImmutableStructure(attributes: [
        "segment": Value.string("premium"),
        "beta_user": Value.boolean(true),
        "region": Value.string("us-west")
    ])
)

await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: newContext)

// Flag evaluations will now use the new context
let client = OpenFeatureAPI.shared.getClient()
let flagValue = client.getBooleanValue(key: "my-feature-flag", defaultValue: false)
```

## Architecture

```
┌─────────────────┐    ┌──────────────────┐
│ Your App        │────│ OpenFeature SDK  │
│                 │    │                  │
│ - App code      │    │ - Client API     │
│ - Flag requests │    │ - Provider mgmt  │
│ - Context mgmt  │    │ - Type system    │
└─────────────────┘    │ - Hook system    │
                       └──────────────────┘
                                  │
                                  ▼
                       ┌──────────────────┐
                       │ DatadogProvider  │
                       │                  │
                       │ - Creates &      │
                       │   delegates to   │
                       │   FlagsClient    │
                       │ - Context conv.  │
                       │ - Type mapping   │
                       └──────────────────┘
                                  │
                                  ▼
                       ┌──────────────────┐    ┌──────────────────┐
                       │ DatadogFlags     │────│ Datadog Backend  │
                       │ SDK Client       │    │                  │
                       │ (dd-sdk-ios)     │    │ - Flag configs   │
                       │                  │    │ - User targeting │
                       │ - HTTP requests  │    │ - A/B testing    │
                       │ - Caching        │    └──────────────────┘
                       │ - Networking     │
                       └──────────────────┘
```

### Key Components

- **Your App**: Your application using OpenFeature's standard API
- **OpenFeature SDK**: The core OpenFeature Swift SDK that provides the client API, provider management, type system, and hook system
- **DatadogProvider**: A bridge that creates a DatadogFlags client, converts between OpenFeature and Datadog types, and delegates flag operations to the client
- **DatadogFlags SDK Client**: The client from dd-sdk-ios that communicates with Datadog's backend (created automatically by the provider)
- **Datadog Backend**: Datadog's service that serves flag configurations and handles targeting

## Contributing

We welcome contributions! Please see [DEVELOPMENT.md](DEVELOPMENT.md) for detailed setup instructions, testing guidelines, and contribution workflow.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
