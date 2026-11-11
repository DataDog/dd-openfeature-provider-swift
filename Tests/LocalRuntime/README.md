# Native SDK validation

The runtime tests use the actual OpenFeature client, provider, native Flags client, and loopback HTTP intake. They observe assignment requests, exposures, evaluation events, and RUM annotations. They use fake credentials only with local endpoints.

The evaluation telemetry control requires Datadog SDK 3.21.0 or later and Xcode 26 / Swift 6.2 or later. Validate the published dependency first, without SwiftPM edit mode:

```sh
swift package resolve
swift test
xcodebuild -scheme DatadogOpenFeatureProvider \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' test
```

## Optional native source validation

Use the following workflow only when testing native SDK source changes.

From the provider repository, select the native worktree:

```sh
swift package resolve
swift package edit dd-sdk-ios --path /absolute/path/to/native-sdk-worktree
swift test
```

SwiftPM creates `Packages/dd-sdk-ios` and can rewrite `Package.resolved` while edit mode is active. Do not commit the symlink, edit-mode lockfile changes, or local build output.

Xcode does not use SwiftPM edit mode automatically. This XcodeGen specification uses the identity-matching symlink to override the published native dependency. Generate the test project and select an installed simulator:

```sh
mkdir -p .build/local-runtime
xcodegen generate --spec Tests/LocalRuntime/project.yml --project .build/local-runtime
xcodebuild -project .build/local-runtime/ProviderOptOutRuntime.xcodeproj \
  -scheme ProviderOptOutRuntime \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  -derivedDataPath .build/local-runtime-derived test
```

Check that the build log resolves `Datadog` to `Packages/dd-sdk-ios`. This source override validates native worktree changes; repeat validation without it before releasing the provider.

The XCTest runtime cases include strict types, disabled activation, customer hooks, context refreshes, targeting, exposure attributes, delayed responses, failed refreshes, cached assignments, and independent named clients. The existing Swift Testing suite runs in the same test target.

When finished, run `swift package unedit dd-sdk-ios` to remove the symlink. Check that `git status` shows no edit-mode changes to `Package.resolved`.
