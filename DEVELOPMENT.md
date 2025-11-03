# Development Guide

This guide covers development setup, testing, and contribution workflows for the DataDog OpenFeature Provider for Swift.

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

# Run tests for specific platform (requires Xcode)
xcodebuild -scheme DatadogOpenFeatureProvider -destination "platform=iOS Simulator,name=iPhone 15" test
```

### Platform Testing

```bash
# Test on different platforms (use available simulators)
xcodebuild -scheme DatadogOpenFeatureProvider -destination "platform=iOS Simulator,name=iPhone 15" build
xcodebuild -scheme DatadogOpenFeatureProvider -destination "platform=macOS,arch=arm64" build  
xcodebuild -scheme DatadogOpenFeatureProvider -destination "platform=tvOS Simulator,name=Apple TV" build
```

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

- **OpenFeature Swift SDK**: Pinned to exact version (see Package.swift)
- **DataDog SDK**: Flexible range from minimum supported version (see Package.swift)

### Updating Dependencies

1. **For OpenFeature SDK** (breaking changes possible):
   ```bash
   # Update Package.swift exact version
   # Test thoroughly with: make test
   # Update DEVELOPMENT.md requirements
   ```

2. **For DataDog SDK** (backward compatible):
   ```bash
   # Version range automatically allows newer versions
   # Test compatibility with: make test
   # Update README.md minimum version if needed
   ```

## CI/CD

This repository uses GitLab CI for automated testing:
- Environment validation and tool checking
- SwiftLint enforcement  
- Unit tests using Swift Package Manager
- Multi-platform builds (iOS, macOS, tvOS, watchOS)

Local development commands mirror the CI pipeline:
```bash
make env-check  # Environment validation
make lint       # Code quality checks
make test       # Unit tests
make spm-build  # Package builds
```


## Contributing

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
- Verify backward compatibility with supported DataDog SDK versions