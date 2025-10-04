import Foundation
import DatadogFlags
import OpenFeature

// MARK: - ProviderEvaluation Extensions

extension ProviderEvaluation where T == Bool {
    /// Creates ProviderEvaluation<Bool> from DatadogFlags FlagDetails<Bool>
    init(_ details: FlagDetails<Bool>, flagKey: String, context: EvaluationContext?) {
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
    init(_ details: FlagDetails<String>, flagKey: String, context: EvaluationContext?) {
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
    init(_ details: FlagDetails<Double>, flagKey: String, context: EvaluationContext?) {
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
    init(_ details: FlagDetails<Int>, flagKey: String, context: EvaluationContext?) {
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
    init(_ details: FlagDetails<AnyValue>, flagKey: String, context: EvaluationContext?) {
        self.init(
            value: Value(details.value),
            flagMetadata: [:],
            variant: details.variant,
            reason: details.reason
        )
    }
}
