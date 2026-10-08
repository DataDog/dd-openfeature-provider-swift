# Development Guide

This guide covers development setup, testing, and contribution workflows for the Datadog OpenFeature Provider for Swift.

## Quick Commands

This project uses a Makefile for common development tasks:

```bash
make help       # Show all available targets
make lint       # Run SwiftLint on source and test files  
make test       # Run Swift tests
make spm-build  # Build with Swift Package Manager
make clean      # Clean build artifacts
```

## Development Setup

### Prerequisites

1. **Install Xcode** from the Mac App Store or Apple Developer portal
2. **Verify Xcode Command Line Tools** are installed:
   ```bash
   xcode-select --install
   ```
3. **Install SwiftLint** (for code linting):
   ```bash
   brew install swiftlint
   ```

### Clone and Build

```bash
# Clone the repository
git clone https://github.com/Datadog/dd-openfeature-provider-swift.git
cd dd-openfeature-provider-swift

# Resolve dependencies
swift package resolve

# Build the package
make spm-build

# Or use Swift directly
swift build
```

## Testing

### Running Tests

```bash
# Run all tests
make test

# Or use Swift directly
swift test

# Run tests for specific platform (requires Xcode - adjust device name/OS as needed)
xcodebuild -scheme DatadogOpenFeatureProvider -destination "platform=iOS Simulator,name=iPhone 16,OS=18.5" test
```

### Platform Testing

```bash
# Test on different platforms (adjust device names/OS versions as available)
xcodebuild -scheme DatadogOpenFeatureProvider -destination "platform=iOS Simulator,name=iPhone 16,OS=18.5" build
xcodebuild -scheme DatadogOpenFeatureProvider -destination "platform=macOS,arch=arm64" build
xcodebuild -scheme DatadogOpenFeatureProvider -destination "generic/platform=tvOS" build
xcodebuild -scheme DatadogOpenFeatureProvider -destination "platform=tvOS Simulator,name=Apple TV,OS=latest" build test
xcodebuild -scheme DatadogOpenFeatureProvider -destination "generic/platform=watchOS" build
```

### Latest Datadog SDK Compatibility

`make latest-sdk-compatibility` checks the newest stable Datadog SDK tag allowed by `Package.swift`, independently of the SDK version pinned in `Package.resolved`. It works in a temporary copy and leaves the checkout and lockfile unchanged.

The check explicitly requests that SDK version and verifies the resolved pin, so an incompatible release cannot be hidden by a fallback to an older SDK. It reuses platform compatibility validation, runs provider unit tests, and builds a consumer for iOS, macOS, tvOS, and watchOS at the provider's advertised deployment minimums. The consumer pins the selected SDK exactly. Prerelease tags are excluded; dependency constraints are never widened. CocoaPods remains covered by the existing smoke tests.

Run `make test-compatibility-tools` for offline regression tests, or `python3 -B tools/test-latest-sdk-compatibility.py --check-only` for dependency resolution and platform validation without builds. `--repository-root PATH` can check a different provider checkout or extracted release for regression investigations.

The **Latest SDK Compatibility** GitLab job runs in regular provider pipelines and supports scheduled pipelines. To detect SDK releases without a provider commit, a maintainer must create a [GitLab pipeline schedule](https://docs.gitlab.com/ci/pipelines/schedules/) targeting `develop` after this change merges (and `main` once it contains the job). The schedule is configured in GitLab, not created by this PR. These pipelines also run the normal checks and must not set `RELEASE_GIT_TAG` or publishing variables. No cross-repository release trigger is configured.

## Code Quality

### Linting

This project uses [SwiftLint](https://github.com/realm/SwiftLint) to enforce Swift style and conventions with separate configurations for source and test files.

```bash
# Run SwiftLint
make lint

# Auto-fix violations where possible
./tools/lint/run-linter.sh --fix
```

### Environment Check

```bash
# Validate development environment
make env-check
```

## Dependency Management

The project uses Swift Package Manager with the following dependency strategy:

- **OpenFeature Swift SDK**: Constrained to the supported 0.3.x API and pinned in `Package.resolved`
- **Datadog SDK**: `>= 3.17.0, < 4.0.0`, requiring iOS 15, tvOS 15, watchOS 9, and a Swift 6.0+ toolchain

### Updating Dependencies

1. **For OpenFeature SDK** (breaking changes possible):
   ```bash
   # Update the Package.swift version range and Package.resolved pin
   # Test thoroughly with: make platform-compatibility test
   # Update DEVELOPMENT.md requirements
   ```

2. **For Datadog SDK**:
   ```bash
   # Keep Package.swift and the podspec dependency bounds aligned
   # Check deployment targets before widening the supported range
   # Test compatibility with: make platform-compatibility test
   # Update README.md and INSTALLATION.md requirements if needed
   ```

## CI/CD

The this repository uses GitLab CI for automated testing. **Contributors using forks won't have access to this CI pipeline.**

**Before submitting a pull request, run these commands locally to ensure your changes will pass CI:**
```bash
make env-check  # Environment validation
make lint       # Code quality checks
make test       # Unit tests
make spm-build  # Package builds
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

1. **Fork and clone** the repository
2. **Create a feature branch**: `git checkout -b feature/your-feature`
3. **Make your changes** following the existing code style
4. **Run tests**: `make test`
5. **Run linting**: `make lint`
6. **Commit your changes** with clear commit messages
7. **Push to your fork** and create a pull request

### Code Style Guidelines

- Follow existing Swift conventions in the codebase
- Use SwiftLint rules (configuration in `tools/lint/`)
- Write tests for new functionality
- Update documentation for public API changes
- Keep commits focused and well-described

### Testing Guidelines

- Write unit tests for new features
- Test edge cases and error conditions
- Ensure all platforms build successfully
- Verify backward compatibility with supported Datadog SDK versions
