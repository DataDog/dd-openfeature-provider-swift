# Installation Guide

This guide covers how to install the Datadog OpenFeature Provider in your iOS, macOS, tvOS, or watchOS project.

The requirements and installation examples below apply to the upcoming 0.3.0 release. Until it is published, use the [0.2.2 installation guide](https://github.com/DataDog/dd-openfeature-provider-swift/blob/0.2.2/INSTALLATION.md).

## Requirements

- **Xcode 16.0+ / Swift 6.0+ toolchain with Datadog SDK 3.17.0**; newer SDK releases may require a newer toolchain (the provider continues to use Swift 5 language mode)
- **Platform Support:**
  - **Swift Package Manager**: iOS 15.0+, macOS 12.6+, watchOS 9.0+, tvOS 15.0+
  - **CocoaPods**: iOS 15.0+ only
- **Dependencies:**
  - Datadog SDK: `>= 3.17.0, < 4.0.0`
  - OpenFeature Swift SDK: 0.3.1 with Swift Package Manager; 0.3.0 with CocoaPods

If your app also declares the Datadog SDK directly, its dependency requirement must overlap `>= 3.17.0, < 4.0.0`.

For Swift Package Manager, the required toolchain depends on the resolved SDK version: SDK 3.17.0 requires Swift tools 6.0, while SDK 3.19.0 requires Swift tools 6.2 (Xcode 26 or later). To keep using Xcode 16 with Swift 6.0, explicitly select a compatible SDK, for example `.package(url: "https://github.com/DataDog/dd-sdk-ios.git", exact: "3.17.0")`. Do not pin SDK 3.19.0 on a toolchain that cannot build its manifest.

### Older OS Targets

Apps that need iOS 14, tvOS 14, or watchOS 8 must stay on provider `>= 0.2.2, < 0.3.0`, which requires Datadog SDK `>= 3.13.0, < 3.17.0`. Use `"0.2.2"..<"0.3.0"` in Swift Package Manager or `~> 0.2.2` in CocoaPods.

## Prerequisites

1. **Install Xcode** from the Mac App Store or Apple Developer portal
2. **Verify Xcode Command Line Tools** are installed:
   ```bash
   xcode-select --install
   ```

## Package Managers

### Swift Package Manager

Add this package to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/Datadog/dd-openfeature-provider-swift.git", "0.3.0"..<"0.4.0")
]
```

**Via Xcode:**
1. **File** → **Add Package Dependencies**
2. Enter: `https://github.com/Datadog/dd-openfeature-provider-swift.git`
3. Choose a version range of `0.3.0..<0.4.0`.

### CocoaPods

> **Note:** CocoaPods installation only supports iOS because OpenFeature 0.3.0 is the latest version published to CocoaPods and its podspec does not include tvOS or watchOS. For full platform support, use Swift Package Manager.

Add this to your `Podfile`:

```ruby
pod 'DatadogOpenFeatureProvider', '~> 0.3.0'
```

Then run:
```bash
pod install
```

## Releases

Check [releases](https://github.com/DataDog/dd-openfeature-provider-swift/releases) for available versions.

## Next Steps

After installation, see the main [README.md](README.md) for usage examples and configuration.
