# Installation Guide

This guide covers how to install the Datadog OpenFeature Provider in your iOS, macOS, tvOS, or watchOS project.

## Requirements

- **Xcode 15.0+**
- **Swift 5.9+**
- **iOS 14.0+ / macOS 12.0+ / watchOS 7.0+ / tvOS 14.0+**

## Prerequisites

1. **Install Xcode** from the Mac App Store or Apple Developer portal
2. **Verify Xcode Command Line Tools** are installed:
   ```bash
   xcode-select --install
   ```

## Package Managers

⚠️ **This package is currently in development and not yet ready for production use.**

### Swift Package Manager (Recommended)

Add this package to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/Datadog/dd-openfeature-provider-swift.git", from: "0.1.0")
]
```

**Requirements:**
- Datadog SDK: 3.2.0+
- OpenFeature Swift SDK: 0.4.0

**Via Xcode:**
1. **File** → **Add Package Dependencies**
2. Enter: `https://github.com/Datadog/dd-openfeature-provider-swift.git`
3. Select the latest version

### CocoaPods

Add this to your `Podfile`:

```ruby
pod 'DatadogOpenFeatureProvider', '~> 0.1.0'
```

Then run:
```bash
pod install
```

**Requirements:**
- DatadogFlags: 3.2.0+
- OpenFeature: ~> 0.4.0

## Releases

Check [releases](https://github.com/DataDog/dd-openfeature-provider-swift/releases) for available versions.

## Next Steps

After installation, see the main [README.md](README.md) for usage examples and configuration.