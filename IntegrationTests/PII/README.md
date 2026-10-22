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

`evidence.json`, `wire-macos.json`, `wire-ios-dynamic.json`, `wire-ios-static.json`, `build-and-run.log`, `Package.resolved` and (when requested) `Podfile.lock` record the result and artifact/source identities. Keep these with the review evidence. A failed build/probe or missing assertion is a failure, not a skip. Python verifier tests only test the harness; they are not SDK wire evidence.

CocoaPods mode retains the existing OpenFeature 0.3.0 smoke-test minimum and builds/tests static and dynamic iOS consumers with local DatadogFlags, DatadogInternal, DatadogCore and provider podspecs. It runs the shared direct-native/OpenFeature probe in the existing UIKit smoke apps' hosted XCTest targets (`TEST_HOST=App.app/App`). The test verifies its app bundle and iOS runtime before exercising the production SDK; only the remote configuration/intake service is replaced by a loopback HTTP fixture. Each linkage gets a fresh intake and independently must deliver exactly 72 evaluations. The runner retains separate wire bodies, app/framework/test-binary hashes and `ios-*.xcresult` bundles. This tests an iOS app process, but does not claim physical-device or live-backend dogfooding coverage. SPM uses OpenFeature 0.3.1..<0.4.0. Platform declarations remain iOS 15, macOS 12.6, watchOS 9, tvOS 15 and visionOS 1. The newer native package already requires Swift tools 6.2; existing pinned-provider CI uses Xcode 16.2 and needs a compatible toolchain for this paired validation.

## Draft/release status

Editing and Python harness checks ran on Linux; Apple compilation and execution ran remotely on the native repository's Xcode 26 / Swift 6.2 runner. [Artifact validation job 2162788628](https://gitlab.ddbuild.io/DataDog/dd-sdk-ios/-/jobs/2162788628) passed with native commit `768090df0426e2aadd12d550f6ad0371b32dd13f` and provider commit `57d5840122567bc1127c4f7e1a9436af44429a40`:

- 55 provider tests and the actual SPM-linked native/provider executable passed.
- Wire assertions verified 72 evaluations in 35 buckets, including the normal uploader's retry after HTTP 500, and 24 unchanged assignment requests.
- CocoaPods resolved OpenFeature 0.3.0 with local native/provider podspecs; static and dynamic iOS simulator consumer tests passed.

The executable SHA-256 was `68e229f902a521981f8b95e5c2c922f526908cdc424a22b3158e9912be4fd90c`. The job retains source identities, binary hash, lockfiles, build logs and captured wire evidence. Native lint, API verification and SPI documentation builds passed separately. SDK-owner review, native XCTest and broader supported-platform CI remain separate review checks. The provider's normal Xcode 16.2 pipeline fails on the native Swift 6.2 tools requirement; its runner must be upgraded before merge/release.

The previous released dependency minimum and lockfile were SDK 3.17.0; they do **not** provide the new consent SPI. This provider change requires the paired FFL-3432 SDK source and is not publishable with those bounds. The draft's SPM manifest and lockfile are pinned to native commit `857450f49a322dfd82fe52f1952915e8a69d9890` for review; local validation overrides it explicitly. Once the first protected SDK version is confirmed, update `Package.swift`, `Package.resolved`, `DatadogOpenFeatureProvider.podspec`, the CocoaPods smoke constraint, README/INSTALLATION/DEVELOPMENT requirements, and CI toolchain/pins together. Do not infer a release number or silently widen/change platform floors. Re-run both package-manager paths against that released artifact before release.

Native unit tests cover exact Unicode hashing, empty/missing native keys, error allowlisting, caller mutation and cache/bridge consent. Swift strings cannot contain unpaired UTF-16 surrogates; raw malformed/null input validation belongs at the React Native boundary, which must be validated separately before that SDK releases. This probe does not claim React Native conformance or replace supported Apple-platform build validation.
