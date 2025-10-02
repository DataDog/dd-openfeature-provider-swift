import Foundation
import DatadogFlags
import OpenFeature


internal class DatadogFlagsAdapter {
    let flagsClient: FlagsClientProtocol
    private static let iso8601Formatter = ISO8601DateFormatter()
    
    init(flagsClient: FlagsClientProtocol) {
        self.flagsClient = flagsClient
    }
    
    // MARK: - Flag Evaluation Methods
    
    internal func getBooleanDetails(key: String, defaultValue: Bool, options: [String: Any]?) -> ProviderEvaluation<Bool> {
        let details = flagsClient.getBooleanDetails(key: key, defaultValue: defaultValue)
        let metadata = extractMetadata(flagKey: key, options: options)
        return ProviderEvaluation(
            value: details.value,
            flagMetadata: metadataToFlagMetadata(metadata),
            variant: details.variant,
            reason: details.reason
        )
    }
    
    internal func getStringDetails(key: String, defaultValue: String, options: [String: Any]?) -> ProviderEvaluation<String> {
        let details = flagsClient.getStringDetails(key: key, defaultValue: defaultValue)
        let metadata = extractMetadata(flagKey: key, options: options)
        return ProviderEvaluation(
            value: details.value,
            flagMetadata: metadataToFlagMetadata(metadata),
            variant: details.variant,
            reason: details.reason
        )
    }
    
    internal func getIntegerDetails(key: String, defaultValue: Int64, options: [String: Any]?) -> ProviderEvaluation<Int64> {
        let intValue = Int(defaultValue)
        let details = flagsClient.getIntegerDetails(key: key, defaultValue: intValue)
        let metadata = extractMetadata(flagKey: key, options: options)
        return ProviderEvaluation(
            value: Int64(details.value),
            flagMetadata: metadataToFlagMetadata(metadata),
            variant: details.variant,
            reason: details.reason
        )
    }
    
    internal func getDoubleDetails(key: String, defaultValue: Double, options: [String: Any]?) -> ProviderEvaluation<Double> {
        let details = flagsClient.getDoubleDetails(key: key, defaultValue: defaultValue)
        let metadata = extractMetadata(flagKey: key, options: options)
        return ProviderEvaluation(
            value: details.value,
            flagMetadata: metadataToFlagMetadata(metadata),
            variant: details.variant,
            reason: details.reason
        )
    }
    
    internal func getObjectDetails(key: String, defaultValue: Value, options: [String: Any]?) -> ProviderEvaluation<Value> {
        let defaultDict = defaultValue.toDictionary()
        let anyValue = AnyValue(defaultDict)
        let details = flagsClient.getObjectDetails(key: key, defaultValue: anyValue)
        let metadata = extractMetadata(flagKey: key, options: options)
        return ProviderEvaluation(
            value: details.value.toValue(),
            flagMetadata: metadataToFlagMetadata(metadata),
            variant: details.variant,
            reason: details.reason
        )
    }
    
    // MARK: - Metadata Extraction
    
    private func extractMetadata(flagKey: String, options: [String: Any]?) -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        // Add flag key for debugging/tracing
        metadata["flagKey"] = flagKey
        
        // Add provider information
        metadata["provider"] = "DatadogFlags"
        
        // Add evaluation timestamp
        metadata["evaluationTime"] = Self.iso8601Formatter.string(from: Date())
        
        // Extract context information from options if available
        if let options = options {
            // Add targeting key if present
            if let targetingKey = options["targetingKey"] {
                metadata["targetingKey"] = targetingKey
            }
            
            // Add all other context attributes (excluding targetingKey to avoid duplication)
            for (key, value) in options {
                if key != "targetingKey" {
                    metadata[key] = value
                }
            }
        }
        
        return metadata
    }
    
    // MARK: - Helper Methods
    
    private func metadataToFlagMetadata(_ metadata: [String: Any]) -> [String: FlagMetadataValue] {
        return metadata.compactMapValues { value in
            switch value {
            case let bool as Bool:
                return .boolean(bool)
            case let string as String:
                return .string(string)
            case let int as Int:
                return .integer(Int64(int))
            case let int64 as Int64:
                return .integer(int64)
            case let double as Double:
                return .double(double)
            default:
                return nil
            }
        }
    }
    
}

// MARK: - DatadogFlags AnyValue Extensions
extension AnyValue {
    /// Creates an AnyValue from Any type
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
    
    /// Creates an AnyValue from a dictionary
    init(_ dictionary: [String: Any]) {
        var structure: [String: AnyValue] = [:]
        for (key, value) in dictionary {
            structure[key] = AnyValue(value)
        }
        self = .dictionary(structure)
    }
    
    /// Converts AnyValue to Any type
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
    
    /// Converts AnyValue to OpenFeature Value
    func toValue() -> Value {
        switch self {
        case .bool(let bool):
            return .boolean(bool)
        case .string(let string):
            return .string(string)
        case .int(let int):
            return .integer(Int64(int))
        case .double(let double):
            return .double(double)
        case .dictionary(let structure):
            var result: [String: Value] = [:]
            for (key, value) in structure {
                result[key] = value.toValue()
            }
            return .structure(result)
        case .array(let list):
            return .list(list.map { $0.toValue() })
        case .null:
            return .null
        }
    }
}
