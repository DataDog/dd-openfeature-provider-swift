# Local artifact privacy validation (FFL-3433)

Native iOS owns telemetry emission and protection. The provider forwards evaluation-time consent as `__dd_observe_full_evaluation_data` and maps native error classifications for all five result types. It does not hash or emit a second event.

## Run on macOS

Use Xcode 26 / Swift 6.2 for the paired native source. Install the repository's Bundler dependencies before requesting CocoaPods smoke tests. Pick an installed simulator with `xcrun simctl list devices available`.

```sh
python3 -B IntegrationTests/PII/run.py \
  --sdk /absolute/path/to/dd-sdk-ios \
  --output /absolute/path/to/new-evidence-directory \
  --cocoapods-destination 'platform=iOS Simulator,name=<installed simulator>,OS=<installed OS>'
```

The runner copies the provider into a temporary directory and replaces its native dependency with the supplied local checkout. It runs the provider unit tests and compiles a separate executable linked to the actual local provider, native Core/Flags and OpenFeature 0.3.1 packages. No mock provider/client or copied telemetry implementation is used. A loopback server serves the five consent states, forces an upload retry, records assignment requests and checks native evaluation request bodies. The probe exercises all value types, missing flags, type mismatches, consent changes before flush, disk restoration/offline evaluations, DoLog false and tracking disable. Exact count assertions detect duplicate emission; the canonical targeting hash detects double hashing. Raw assignment requests must remain unchanged.

`evidence.json`, `wire.json`, `build-and-run.log`, `Package.resolved` and (when requested) `Podfile.lock` record the result and artifact/source identities. Keep these with the review evidence. A failed build/probe or missing assertion is a failure, not a skip. Python verifier tests only test the harness; they are not SDK wire evidence.

CocoaPods mode retains the existing OpenFeature 0.3.0 smoke-test minimum and builds/tests static and dynamic iOS consumers with local DatadogFlags, DatadogInternal, DatadogCore and provider podspecs. SPM uses OpenFeature 0.3.1..<0.4.0. Platform declarations remain iOS 15, macOS 12.6, watchOS 9, tvOS 15 and visionOS 1. The newer native package already requires Swift tools 6.2; existing pinned-provider CI uses Xcode 16.2 and needs a compatible toolchain for this paired validation.

## Draft/release status

This work was prepared on Linux without Swift, Xcode, CocoaPods or Apple SDKs. Native/provider Swift tests, actual compiled-artifact wire proof, CocoaPods resolution/builds, platform builds and SwiftLint have **not run**. The runner deliberately fails on Linux. An SDK-owner review and macOS evidence remain required.

The previous released dependency minimum and lockfile were SDK 3.17.0; they do **not** provide the new consent SPI. This provider change requires the paired FFL-3432 SDK source and is not publishable with those bounds. The draft's SPM manifest and lockfile are pinned to native commit `857450f49a322dfd82fe52f1952915e8a69d9890` for review; local validation overrides it explicitly. Once the first protected SDK version is confirmed, update `Package.swift`, `Package.resolved`, `DatadogOpenFeatureProvider.podspec`, the CocoaPods smoke constraint, README/INSTALLATION/DEVELOPMENT requirements, and CI toolchain/pins together. Do not infer a release number or silently widen/change platform floors. Re-run both package-manager paths against that released artifact before release.

Native unit tests cover exact Unicode hashing, empty/missing native keys, error allowlisting, caller mutation and cache/bridge consent. Swift strings cannot contain unpaired UTF-16 surrogates; raw malformed/null input validation belongs at the React Native boundary, which must be validated separately before that SDK releases. This probe does not claim React Native conformance or replace supported Apple-platform build validation.
