import Foundation
import DatadogFlags
import OpenFeature

// MARK: - FlagsEvaluationContext Extensions

extension FlagsEvaluationContext {
    /// Creates DatadogFlags context from OpenFeature EvaluationContext
    /// Converts all attribute values to strings as required by DatadogFlags
    init(_ context: EvaluationContext) {
        let targetingKey = context.getTargetingKey()
        
        var attributes: [String: String] = [:]
        for (key, value) in context.asMap() {
            // DatadogFlags only supports String attributes
            attributes[key] = value.toString()
        }
        
        self.init(targetingKey: targetingKey, attributes: attributes)
    }
}
