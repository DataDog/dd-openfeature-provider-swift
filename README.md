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
let config = Datadog.Configuration.builderUsing(
    clientToken: "YOUR_CLIENT_TOKEN",
    environment: "production"
).build()

Datadog.initialize(with: config, trackingConsent: .granted)

let flagsConfig = Flags.Configuration()
Flags.enable(with: flagsConfig)

// 2. Create the DatadogFlags client
let flagsClient = FlagsClient.create(in: Datadog.coreInstance)

// 3. Create user context for targeting
let context = ImmutableContext(
    targetingKey: "user123",
    structure: ImmutableStructure(attributes: [
        "segment": Value.string("premium"),
        "beta_user": Value.boolean(true)
    ])
)

// 4. Create and register the OpenFeature provider using the real DatadogFlags client
let provider = DatadogOpenFeatureProvider.createProvider(flagsClient: flagsClient)
await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: context)

// 5. Get OpenFeature client and evaluate flags
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

### Advanced Usage

```swift
// For more control, you can create the adapter directly
let flagsClient = FlagsClient.create(in: Datadog.coreInstance)
let adapter = DatadogFlagsAdapter(flagsClient: flagsClient)
let provider = DatadogProvider(client: adapter)

// Or use the original interface if you have a custom client implementation
let customClient: DatadogFlaggingClientWithDetails = MyCustomClient()
let provider = DatadogOpenFeatureProvider.createProvider(client: customClient)

// You can also pass any FlagsClientProtocol implementation
let mockClient: FlagsClientProtocol = MockFlagsClient()
let testProvider = DatadogOpenFeatureProvider.createProvider(flagsClient: mockClient)
```

**Note:** This provider now integrates directly with the DatadogFlags SDK from dd-sdk-ios, providing full functionality including context management, async operations, and comprehensive flag evaluation.

## Architecture

```
┌─────────────────-┐    ┌──────────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ OpenFeature App  │────│ DatadogProvider      │────│ DatadogFlags     │────│ Datadog Backend │
│                  │    │                      │    │ Adapter          │    │                 │
│ - getBooleanValue│    │ - Lifecycle mgmt     │    │ - Type mapping   │    │ - Flag configs  │
│ - getStringValue │    │ - Context conversion │    │ - Error handling │    │ - User targeting│
│ - setContext     │    │ - Async operations   │    │ - Protocol bridge│    │ - A/B testing   │
└─────────────────-┘    └──────────────────────┘    └──────────────────┘    └─────────────────┘
                                                            │
                                                            ▼
                                                    ┌─────────────────┐
                                                    │ DatadogFlags    │
                                                    │ SDK Client      │
                                                    │ (dd-sdk-ios)    │
                                                    └─────────────────┘
```

### Key Components

- **OpenFeature App**: Your application using OpenFeature's standard API
- **DatadogProvider**: Main OpenFeature provider implementation that handles lifecycle and context management
- **DatadogFlags Adapter**: Bridge layer that converts between OpenFeature and DatadogFlags protocols/types
- **DatadogFlags SDK Client**: The actual Datadog SDK from dd-sdk-ios that communicates with Datadog's backend
- **Datadog Backend**: Datadog's service that serves flag configurations and handles targeting

### Data Flow

1. App calls OpenFeature API (e.g., `getBooleanValue`)
2. DatadogProvider receives the call and converts OpenFeature context
3. DatadogFlagsAdapter maps OpenFeature types to DatadogFlags types
4. DatadogFlags SDK Client makes the actual flag evaluation
5. Response flows back through the adapter (with type conversion) to the app

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
