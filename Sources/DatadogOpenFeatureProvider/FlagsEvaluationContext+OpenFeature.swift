import Foundation
import DatadogFlags
import OpenFeature

// MARK: - FlagsEvaluationContext Extensions

extension FlagsEvaluationContext {
    /// Creates DatadogFlags context from OpenFeature EvaluationContext
    /// Preserves original attribute types when converting from OpenFeature Value to AnyValue
    init(_ context: EvaluationContext) {
        let targetingKey = context.getTargetingKey()
        
        var attributes: [String: AnyValue] = [:]
        for (key, value) in context.asMap() {
            // Convert OpenFeature Value to DatadogFlags AnyValue, preserving original types
            do {
                attributes[key] = try AnyValue(value)
            } catch {
                // Fallback to string conversion for unsupported types (e.g., dates)
                attributes[key] = AnyValue.string(value.toString())
            }
        }
        
        self.init(targetingKey: targetingKey, attributes: attributes)
    }
}
