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
    .package(url: "https://github.com/Datadog/dd-openfeature-provider-swift.git", from: "1.0.0")
]
```

For development/testing purposes only, you can use the main branch:

```swift
dependencies: [
    .package(url: "https://github.com/Datadog/dd-openfeature-provider-swift.git", branch: "main")
]
```

Or add it through Xcode:
1. **File** → **Add Package Dependencies**
2. Enter: `https://github.com/Datadog/dd-openfeature-provider-swift.git`

## Development

### Building the Package

```bash
# Clone the repository
git clone https://github.com/Datadog/dd-openfeature-provider-swift.git
cd dd-openfeature-provider-swift

# Build the package
swift build
```

### Running Tests

```bash
# Run all tests
swift test

# Run tests for specific platform (requires Xcode)
xcodebuild -scheme DatadogOpenFeatureProvider -destination "platform=iOS Simulator,name=iPhone 16" test
```

### Code Linting

This project uses [SwiftLint](https://github.com/realm/SwiftLint) to enforce Swift style and conventions.

```bash
# Install SwiftLint (if not already installed)
brew install swiftlint

# Run SwiftLint
swiftlint lint

# Auto-fix violations where possible
swiftlint lint --fix
```

### Platform Testing

```bash
# Test on different platforms
xcodebuild -scheme DatadogOpenFeatureProvider -destination "platform=iOS Simulator,name=iPhone 16" build
xcodebuild -scheme DatadogOpenFeatureProvider -destination "platform=macOS,arch=arm64" build  
xcodebuild -scheme DatadogOpenFeatureProvider -destination "platform=tvOS Simulator,name=Apple TV" build
```

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
┌─────────────────-┐    ┌──────────────────────┐    ┌─────────────────┐
│ OpenFeature App  │────│ DatadogProvider      │────│ Datadog Backend │
│                  │    │                      │    │                 │
│ - getBooleanValue│    │ - FlagsClient mgmt   │    │ - Flag configs  │
│ - getStringValue │    │ - Lifecycle mgmt     │    │ - User targeting│
│ - setContext     │    │ - Context conversion │    │ - A/B testing   │
└─────────────────-┘    │ - Type mapping       │    └─────────────────┘
                        │ - Error handling     │            ▲
                        └──────────────────────┘            │
                                    │                       │
                                    ▼                       │
                            ┌─────────────────┐             │
                            │ DatadogFlags    │──────-──────┘
                            │ SDK Client      │
                            │ (dd-sdk-ios)    │
                            └─────────────────┘
```

### Key Components

- **OpenFeature App**: Your application using OpenFeature's standard API
- **DatadogProvider**: Main OpenFeature provider that creates and manages the FlagsClient internally, handles lifecycle, context management, and type conversions
- **DatadogFlags SDK Client**: The client from dd-sdk-ios that communicates with Datadog's backend (created automatically by the provider)
- **Datadog Backend**: Datadog's service that serves flag configurations and handles targeting

## Contributing

### Development Setup

1. **Clone and set up:**
   ```bash
   git clone https://github.com/Datadog/dd-openfeature-provider-swift.git
   cd dd-openfeature-provider-swift
   swift package resolve
   ```

2. **Run tests:**
   ```bash
   swift test
   ```

3. **Run SwiftLint to ensure code quality:**
   ```bash
   # Install SwiftLint if needed
   brew install swiftlint
   
   # Check for violations
   swiftlint lint
   
   # Auto-fix where possible
   swiftlint lint --fix
   ```

### CI/CD

This repository includes GitHub Actions workflows that:
- Run SwiftLint to enforce code quality and style
- Test on multiple Swift versions (5.9, 5.10, 6.0)
- Test on multiple platforms (iOS, macOS, tvOS, watchOS)
- Run on both Ubuntu and macOS runners
- Cache dependencies for faster builds

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
