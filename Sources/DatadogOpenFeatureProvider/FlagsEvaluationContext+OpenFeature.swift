import Foundation
import DatadogFlags
import OpenFeature

// MARK: - FlagsEvaluationContext Extensions

extension FlagsEvaluationContext {
    /// Creates DatadogFlags context from OpenFeature EvaluationContext
    /// Preserves original attribute types when converting from OpenFeature Value to AnyValue
    init(_ context: EvaluationContext) throws {
        let targetingKey = context.getTargetingKey()
        
        var attributes: [String: AnyValue] = [:]
        for (key, value) in context.asMap() {
            // Convert OpenFeature Value to DatadogFlags AnyValue, preserving original types
            attributes[key] = try AnyValue(value)
        }
        
        self.init(targetingKey: targetingKey, attributes: attributes)
    }
}
