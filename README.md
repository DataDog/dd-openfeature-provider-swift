# dd-openfeature-provider-swift

## Overview

This package provides a bridge between [OpenFeature](https://openfeature.dev/)'s vendor-neutral feature flag API and Datadog's flagging client, allowing applications to:

- Use OpenFeature's standardized feature flag interface
- Leverage Datadog's precomputed assignments services
- Support all OpenFeature flag types: Boolean, String, Integer, Double, Object

## Requirements

- **Xcode 15.0+**
- **Swift 5.9+**
- **iOS 14.0+ / macOS 11.0+ / watchOS 7.0+ / tvOS 14.0+**

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

### Platform Testing

```bash
# Test on different platforms
xcodebuild -scheme DatadogOpenFeatureProvider -destination "platform=iOS Simulator,name=iPhone 16" build
xcodebuild -scheme DatadogOpenFeatureProvider -destination "platform=macOS,arch=arm64" build  
xcodebuild -scheme DatadogOpenFeatureProvider -destination "platform=tvOS Simulator,name=Apple TV" build
```

## Usage

### Complete Setup

```swift
import OpenFeature
import DatadogOpenFeatureProvider
import DatadogCore
import DatadogFlags

// 1. Initialize Datadog SDK and enable flags
Datadog.initialize(with: config, trackingConsent: .granted)
Flags.enable(with: flagsConfig)
let ddFlagsClient = FlagsClient.create(with: flagsClientConfig)

// 2. Create user context for targeting
let context = ImmutableContext(
    targetingKey: "user123",
    structure: ImmutableStructure(attributes: [
        "segment": Value.string("premium"),
        "beta_user": Value.boolean(true)
    ])
)

// 3. Create and register the OpenFeature provider
let provider = DatadogOpenFeatureProvider.createProvider(client: ddFlagsClient)
await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context)

// 4. Get OpenFeature client and evaluate flags
let client = OpenFeatureAPI.shared.getClient()
let flagValue = client.getBooleanValue(key: "my-feature-flag", defaultValue: false)
```

### Dynamic Context Updates

```swift
// Update context using mutable context builder. Immutable is okay too.
let updatedContext = MutableContext(targetingKey: "user123")
updatedContext.add(key: "segment", value: .string("enterprise"))
updatedContext.add(key: "beta_user", value: .boolean(false))
updatedContext.add(key: "region", value: .string("us-west"))

await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: updatedContext)

// Flag evaluations will now use the updated context
let client = OpenFeatureAPI.shared.getClient()
let flagValue = client.getBooleanValue(key: "my-feature-flag", defaultValue: false)
```

**Note:** The Datadog flagging client that implements `DatadogFlaggingClientWithDetails` is provided by the Datadog iOS SDK. This provider package defines the interface that the Datadog SDK implements.

## Architecture

```
┌────────────────-─┐    ┌─────────────────────┐    ┌─────────────-────┐
│ OpenFeature App  │────│ Datadog Provider    │────│ Datadog SDK      │
│                  │    │                     │    │                  │  
│ - getBooleanValue│    │ - Protocol adapter  │    │ - Flag evaluation│
│ - getStringValue │    │ - Context conversion│    │ - Precomputed    │
│ - setContext     │    │ - Value mapping     │    │   assignments    │
└────────────────-─┘    └─────────────────────┘    └────────────────-─┘
```

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

3. **Format code** (if using SwiftFormat):
   ```bash
   swiftformat .
   ```

### CI/CD

This repository includes GitHub Actions workflows that:
- Test on multiple Swift versions (5.9, 5.10, 6.0)
- Test on multiple platforms (iOS, macOS, tvOS, watchOS)
- Run on both Ubuntu and macOS runners
- Cache dependencies for faster builds

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
