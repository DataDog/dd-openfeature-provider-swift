/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

import Foundation
import DatadogFlags
import OpenFeature

// MARK: - ProviderEvaluation Extensions

extension ProviderEvaluation where T == Bool {
    /// Creates ProviderEvaluation<Bool> from DatadogFlags FlagDetails<Bool>
    init(_ details: FlagDetails<Bool>) {
        self.init(
            value: details.value,
            flagMetadata: [:],
            variant: details.variant,
            reason: details.reason
        )
    }
}

extension ProviderEvaluation where T == String {
    /// Creates ProviderEvaluation<String> from DatadogFlags FlagDetails<String>
    init(_ details: FlagDetails<String>) {
        self.init(
            value: details.value,
            flagMetadata: [:],
            variant: details.variant,
            reason: details.reason
        )
    }
}

extension ProviderEvaluation where T == Double {
    /// Creates ProviderEvaluation<Double> from DatadogFlags FlagDetails<Double>
    init(_ details: FlagDetails<Double>) {
        self.init(
            value: details.value,
            flagMetadata: [:],
            variant: details.variant,
            reason: details.reason
        )
    }
}

extension ProviderEvaluation where T == Int64 {
    /// Specialized initializer for Int64 evaluations that handles Int->Int64 conversion
    /// from DatadogFlags FlagDetails<Int> to ProviderEvaluation<Int64>
    init(_ details: FlagDetails<Int>) {
        self.init(
            value: Int64(details.value),
            flagMetadata: [:],
            variant: details.variant,
            reason: details.reason
        )
    }
}

extension ProviderEvaluation where T == Value {
    /// Specialized initializer for Value evaluations that handles AnyValue->Value conversion
    /// from DatadogFlags FlagDetails<AnyValue> to ProviderEvaluation<Value>
    init(_ details: FlagDetails<AnyValue>) {
        self.init(
            value: Value(details.value),
            flagMetadata: [:],
            variant: details.variant,
            reason: details.reason
        )
    }
}
