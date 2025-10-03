import Foundation
import DatadogFlags
import OpenFeature

// MARK: - AnyValue Extensions (DatadogFlags → Swift/OpenFeature)

extension AnyValue {
    /// Creates an AnyValue from Swift Any type
    /// Handles all common Swift types and converts them to appropriate AnyValue cases
    init(_ value: Any) {
        switch value {
        case let bool as Bool:
            self = .bool(bool)
        case let string as String:
            self = .string(string)
        case let int as Int:
            self = .int(int)
        case let int64 as Int64:
            self = .int(Int(int64))
        case let double as Double:
            self = .double(double)
        case let dict as [String: Any]:
            var structure: [String: AnyValue] = [:]
            for (key, value) in dict {
                structure[key] = AnyValue(value)
            }
            self = .dictionary(structure)
        case let array as [Any]:
            self = .array(array.map { AnyValue($0) })
        case is NSNull:
            self = .null
        default:
            self = .string(String(describing: value))
        }
    }
    
    /// Creates an AnyValue from OpenFeature Value
    /// Direct conversion without intermediate steps
    init(_ value: Value) {
        switch value {
        case .boolean(let bool):
            self = .bool(bool)
        case .string(let string):
            self = .string(string)
        case .integer(let int):
            self = .int(Int(int))
        case .double(let double):
            self = .double(double)
        case .date(let date):
            let formatter = ISO8601DateFormatter()
            self = .string(formatter.string(from: date))
        case .structure(let structure):
            self = .dictionary(structure.mapValues { AnyValue($0) })
        case .list(let list):
            self = .array(list.map { AnyValue($0) })
        case .null:
            self = .null
        }
    }
    
    /// Creates an AnyValue from a dictionary
    init(_ dictionary: [String: Any]) {
        var structure: [String: AnyValue] = [:]
        for (key, value) in dictionary {
            structure[key] = AnyValue(value)
        }
        self = .dictionary(structure)
    }
    
    /// Converts AnyValue to Swift Any type
    func toAny() -> Any {
        switch self {
        case .bool(let bool):
            return bool
        case .string(let string):
            return string
        case .int(let int):
            return int
        case .double(let double):
            return double
        case .dictionary(let structure):
            var result: [String: Any] = [:]
            for (key, value) in structure {
                result[key] = value.toAny()
            }
            return result
        case .array(let list):
            return list.map { $0.toAny() }
        case .null:
            return NSNull()
        }
    }
    
    /// Converts AnyValue to dictionary with special handling for non-dictionary types
    func toDictionary() -> [String: Any] {
        switch self {
        case .dictionary(let structure):
            var result: [String: Any] = [:]
            for (key, value) in structure {
                result[key] = value.toAny()
            }
            return result
        case .array(let list):
            return ["_list": list.map { $0.toAny() }]
        default:
            return ["_value": self.toAny()]
        }
    }
}

// MARK: - Value Extensions (OpenFeature → Swift/DatadogFlags)

extension Value {
    /// Creates OpenFeature Value from DatadogFlags AnyValue
    /// Direct conversion without intermediate steps
    init(_ anyValue: AnyValue) {
        switch anyValue {
        case .bool(let bool):
            self = .boolean(bool)
        case .string(let string):
            self = .string(string)
        case .int(let int):
            self = .integer(Int64(int))
        case .double(let double):
            self = .double(double)
        case .dictionary(let structure):
            self = .structure(structure.mapValues { Value($0) })
        case .array(let list):
            self = .list(list.map { Value($0) })
        case .null:
            self = .null
        }
    }
    
    /// Converts OpenFeature Value to Swift Any type
    func toAny() -> Any {
        switch self {
        case .boolean(let bool):
            return bool
        case .string(let string):
            return string
        case .integer(let int):
            return int
        case .double(let double):
            return double
        case .date(let date):
            return date
        case .structure(let structure):
            return structure.mapValues { $0.toAny() }
        case .list(let list):
            return list.map { $0.toAny() }
        case .null:
            return NSNull()
        }
    }
    
    /// Converts OpenFeature Value to String representation
    func toString() -> String {
        switch self {
        case .boolean(let bool):
            return bool.description
        case .string(let string):
            return string
        case .integer(let int):
            return int.description
        case .double(let double):
            return double.description
        case .date(let date):
            return date.description
        case .structure(let structure):
            // Convert to JSON string for complex types
            if let data = try? JSONSerialization.data(withJSONObject: structure.mapValues { $0.toAny() }),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            return structure.description
        case .list(let list):
            // Convert to JSON string for complex types
            let arrayDict = list.map { $0.toAny() }
            if let data = try? JSONSerialization.data(withJSONObject: arrayDict),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            return list.description
        case .null:
            return ""
        }
    }
    
    /// Converts OpenFeature Value to dictionary with special handling for non-dictionary types
    func toDictionary() -> [String: Any] {
        switch self {
        case .structure(let structure):
            return structure.mapValues { $0.toAny() }
        case .list(let list):
            return ["_list": list.map { $0.toAny() }]
        default:
            return ["_value": self.toAny()]
        }
    }
}

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

// MARK: - ProviderEvaluation Extensions

extension ProviderEvaluation where T == Bool {
    /// Creates ProviderEvaluation<Bool> from DatadogFlags FlagDetails<Bool>
    init(_ details: FlagDetails<Bool>, flagKey: String, context: EvaluationContext?) {
        self.init(
            value: details.value,
            flagMetadata: FlagMetadataBuilder.create(flagKey: flagKey, context: context),
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
            flagMetadata: FlagMetadataBuilder.create(flagKey: flagKey, context: context),
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
            flagMetadata: FlagMetadataBuilder.create(flagKey: flagKey, context: context),
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
            flagMetadata: FlagMetadataBuilder.create(flagKey: flagKey, context: context),
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
            flagMetadata: FlagMetadataBuilder.create(flagKey: flagKey, context: context),
            variant: details.variant,
            reason: details.reason
        )
    }
}

// MARK: - Flag Metadata Utilities

/// Utility for creating flag evaluation metadata
enum FlagMetadataBuilder {
    private static let iso8601Formatter = ISO8601DateFormatter()
    
    /// Creates metadata for flag evaluations
    /// Includes provider info, timing, and context data
    /// Returns ready-to-use FlagMetadataValue dictionary
    static func create(flagKey: String, context: EvaluationContext?) -> [String: FlagMetadataValue] {
        var metadata: [String: FlagMetadataValue] = [:]
        
        // Add flag key for debugging/tracing
        metadata["flagKey"] = .string(flagKey)
        
        // Add provider information
        metadata["provider"] = .string("DatadogFlags")
        
        // Add evaluation timestamp
        metadata["evaluationTime"] = .string(iso8601Formatter.string(from: Date()))
        
        // Extract context information if available
        if let context = context {
            // Add targeting key if present
            let targetingKey = context.getTargetingKey()
            metadata["targetingKey"] = .string(targetingKey)
            
            // Add all context attributes converted to appropriate FlagMetadataValue types
            for (key, value) in context.asMap() {
                if key != "targetingKey" { // Avoid duplication
                    if let metadataValue = convertToFlagMetadataValue(value) {
                        metadata[key] = metadataValue
                    }
                }
            }
        }
        
        return metadata
    }
    
    /// Converts OpenFeature Value to FlagMetadataValue
    private static func convertToFlagMetadataValue(_ value: Value) -> FlagMetadataValue? {
        switch value {
        case .boolean(let bool):
            return .boolean(bool)
        case .string(let string):
            return .string(string)
        case .integer(let int):
            return .integer(int)
        case .double(let double):
            return .double(double)
        case .date(let date):
            return .string(date.description)
        case .structure, .list:
            // For complex types, convert to JSON string
            return .string(value.toString())
        case .null:
            return nil // Don't include null values in metadata
        }
    }
}
