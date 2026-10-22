/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2026-Present Datadog, Inc.
 */

import XCTest
import UIKit

// run.py compiles this with the shared probe in the existing UIKit app's hosted test target.
final class PrivacyIOSAppTests: XCTestCase {
    @MainActor
    func testNativeAndOpenFeaturePrivacyInsideIOSApp() async throws {
        XCTAssertEqual(Bundle.main.bundleURL.pathExtension, "app")
        XCTAssertTrue(Bundle.main.bundleIdentifier?.hasPrefix("com.datadoghq.CPProject") == true)
        XCTAssertEqual(UIDevice.current.systemName, "iOS")
        XCTAssertNotNil(UIApplication.shared.delegate)
        print("Privacy probe app: \(Bundle.main.bundleIdentifier ?? "unknown"), iOS \(UIDevice.current.systemVersion)")
        try await PrivacyWireProbe.main()
    }
}
