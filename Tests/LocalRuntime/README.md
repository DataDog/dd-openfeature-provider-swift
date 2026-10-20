# Local native SDK validation

The runtime tests use the actual OpenFeature client, provider, native Flags client, and loopback HTTP intake. They observe assignment requests, exposures, evaluation events, and RUM annotations. They use fake credentials only with local endpoints.

The evaluation telemetry control requires the companion native SDK change. No published dependency version is assumed. Before release, update the package and podspec minimum versions to the native release that contains `FlagsClient.Configuration`.

From the provider repository, select the native worktree:

```sh
swift package resolve
swift package edit dd-sdk-ios --path /absolute/path/to/native-sdk-worktree
swift test
```

SwiftPM creates `Packages/dd-sdk-ios`. Do not commit this symlink or local build output.

Xcode does not use SwiftPM edit mode automatically. This XcodeGen specification uses the identity-matching symlink to override the published native dependency. Generate the test project and select an installed simulator:

```sh
mkdir -p .build/local-runtime
xcodegen generate --spec Tests/LocalRuntime/project.yml --project .build/local-runtime
xcodebuild -project .build/local-runtime/ProviderOptOutRuntime.xcodeproj \
  -scheme ProviderOptOutRuntime \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  -derivedDataPath .build/local-runtime-derived test
```

Check that the build log resolves `Datadog` to `Packages/dd-sdk-ios`. A published SDK build does not validate the companion change.

The XCTest runtime cases include strict types, disabled activation, customer hooks, context refreshes, targeting, exposure attributes, delayed responses, failed refreshes, cached assignments, and independent named clients. The existing Swift Testing suite runs in the same test target.
