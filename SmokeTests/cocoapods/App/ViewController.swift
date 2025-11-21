/*
* Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
* This product includes software developed at Datadog (https://www.datadoghq.com/).
* Copyright 2019-Present Datadog, Inc.
*/

import UIKit
import DatadogOpenFeatureProvider
import OpenFeature

internal class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Test that DatadogOpenFeatureProvider APIs are visible and can be instantiated:
        let provider = DatadogProvider()
        
        // Test OpenFeature integration
        let context = MutableContext(targetingKey: "smoke-test-user")
        
        print("✓ DatadogProvider successfully created")
        print("✓ OpenFeature context successfully created")

        addLabel()
    }

    private func addLabel() {
        let label = UILabel()
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(label)

        label.text = "Testing DatadogOpenFeatureProvider..."
        label.textColor = .white
        label.sizeToFit()
        label.center = view.center
    }
}
