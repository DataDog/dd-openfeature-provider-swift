# dd-openfeature-provider-swift

## Overview

This package provides a bridge between [OpenFeature](https://openfeature.dev/)'s vendor-neutral feature flag API and DataDog's flagging client, allowing applications to:

- Use OpenFeature's standardized feature flag interface
- Leverage DataDog's precomputed assignments services
- Support all OpenFeature flag types: Boolean, String, Integer, Double, Object

## Requirements

- **Xcode 15.0+**
- **Swift 5.5+**
- **iOS 14.0+ / macOS 11.0+ / watchOS 7.0+ / tvOS 14.0+**

## Installation

### Prerequisites

1. **Install Xcode** from the Mac App Store or Apple Developer portal
2. **Verify Xcode Command Line Tools** are installed:
   ```bash
   xcode-select --install
   ```

### Swift Package Manager

Add this package to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/DataDog/dd-openfeature-provider-swift.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. **File** → **Add Package Dependencies**
2. Enter: `https://github.com/DataDog/dd-openfeature-provider-swift.git`

## Development

### Building the Package

```bash
# Clone the repository
git clone https://github.com/DataDog/dd-openfeature-provider-swift.git
cd dd-openfeature-provider-swift

# Build the package
swift build
```

### Running Tests

```bash
# Run all tests
swift test

# Run tests for specific platform (requires Xcode)
xcodebuild -scheme DataDogOpenFeatureProvider -destination "platform=iOS Simulator,name=iPhone 16" test
```

### Platform Testing

```bash
# Test on different platforms
xcodebuild -scheme DataDogOpenFeatureProvider -destination "platform=iOS Simulator,name=iPhone 16" build
xcodebuild -scheme DataDogOpenFeatureProvider -destination "platform=macOS,arch=arm64" build  
xcodebuild -scheme DataDogOpenFeatureProvider -destination "platform=tvOS Simulator,name=Apple TV" build
```

## Usage

### Complete Setup

```swift
import OpenFeature
import DataDogOpenFeatureProvider
import DataDogCore
import DataDogFlags

// 1. Initialize DataDog SDK
Datadog.initialize(with: configuration, trackingConsent: .granted)

// 2. Get the DataDog flagging client (implements DataDogFlaggingClientWithDetails)
let flagsClient = FlagsClient.shared()

// 3. Create and register the OpenFeature provider
let provider = DataDogOpenFeatureProvider.createProvider(client: flagsClient)
OpenFeatureAPI.shared.setProvider(provider: provider)

// 4. Use OpenFeature API for flag evaluation
let client = OpenFeatureAPI.shared.getClient()
let flagValue = client.getBooleanValue(key: "my-feature-flag", defaultValue: false)
```

### With User Targeting

```swift
// Set user context for targeting
let context = MutableContext(targetingKey: "user123")
context.add(key: "segment", value: .string("premium"))
context.add(key: "beta_user", value: .boolean(true))

OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: context)

// Flag evaluations will now use this context for targeting
let flagValue = client.getBooleanValue(key: "premium-feature", defaultValue: false)
```

**Note:** The DataDog flagging client that implements `DataDogFlaggingClientWithDetails` is provided by the DataDog iOS SDK. This provider package defines the interface that the DataDog SDK implements.

## Architecture

```
┌────────────────-─┐    ┌─────────────────────┐    ┌─────────────-────┐
│ OpenFeature App  │────│ DataDog Provider    │────│ DataDog SDK      │
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
   git clone https://github.com/DataDog/dd-openfeature-provider-swift.git
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
