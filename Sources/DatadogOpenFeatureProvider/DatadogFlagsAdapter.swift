import Foundation
import DatadogFlags
import OpenFeature

internal struct AdapterFlagResult<T> {
    let value: T
    let variant: String?
    let reason: String?
    let metadata: [String: Any]
    
    init(value: T, variant: String? = nil, reason: String? = nil, metadata: [String: Any] = [:]) {
        self.value = value
        self.variant = variant
        self.reason = reason
        self.metadata = metadata
    }
}

internal class DatadogFlagsAdapter {
    let flagsClient: FlagsClientProtocol
    
    init(flagsClient: FlagsClientProtocol) {
        self.flagsClient = flagsClient
    }
    
    // MARK: - Flag Evaluation Methods
    
    internal func getBooleanDetails(key: String, defaultValue: Bool, options: [String: Any]?) -> AdapterFlagResult<Bool> {
        let details = flagsClient.getBooleanDetails(key: key, defaultValue: defaultValue)
        return AdapterFlagResult(
            value: details.value,
            variant: details.variant,
            reason: details.reason,
            metadata: extractMetadata(flagKey: key, options: options)
        )
    }
    
    internal func getStringDetails(key: String, defaultValue: String, options: [String: Any]?) -> AdapterFlagResult<String> {
        let details = flagsClient.getStringDetails(key: key, defaultValue: defaultValue)
        return AdapterFlagResult(
            value: details.value,
            variant: details.variant,
            reason: details.reason,
            metadata: extractMetadata(flagKey: key, options: options)
        )
    }
    
    internal func getIntegerDetails(key: String, defaultValue: Int64, options: [String: Any]?) -> AdapterFlagResult<Int64> {
        let intValue = Int(defaultValue)
        let details = flagsClient.getIntegerDetails(key: key, defaultValue: intValue)
        return AdapterFlagResult(
            value: Int64(details.value),
            variant: details.variant,
            reason: details.reason,
            metadata: extractMetadata(flagKey: key, options: options)
        )
    }
    
    internal func getDoubleDetails(key: String, defaultValue: Double, options: [String: Any]?) -> AdapterFlagResult<Double> {
        let details = flagsClient.getDoubleDetails(key: key, defaultValue: defaultValue)
        return AdapterFlagResult(
            value: details.value,
            variant: details.variant,
            reason: details.reason,
            metadata: extractMetadata(flagKey: key, options: options)
        )
    }
    
    internal func getObjectDetails(key: String, defaultValue: [String: Any], options: [String: Any]?) -> AdapterFlagResult<[String: Any]> {
        let anyValue = convertDictToAnyValue(defaultValue)
        let details = flagsClient.getObjectDetails(key: key, defaultValue: anyValue)
        return AdapterFlagResult(
            value: convertAnyValueToDict(details.value),
            variant: details.variant,
            reason: details.reason,
            metadata: extractMetadata(flagKey: key, options: options)
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
        let formatter = ISO8601DateFormatter()
        metadata["evaluationTime"] = formatter.string(from: Date())
        
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
    
    // MARK: - Helper Methods for Type Conversion
    
    private func convertAnyToAnyValue(_ any: Any) -> AnyValue {
        switch any {
        case let bool as Bool:
            return .bool(bool)
        case let string as String:
            return .string(string)
        case let int as Int:
            return .int(int)
        case let int64 as Int64:
            return .int(Int(int64))
        case let double as Double:
            return .double(double)
        case let dict as [String: Any]:
            var structure: [String: AnyValue] = [:]
            for (key, value) in dict {
                structure[key] = convertAnyToAnyValue(value)
            }
            return .dictionary(structure)
        case let array as [Any]:
            return .array(array.map { convertAnyToAnyValue($0) })
        case is NSNull:
            return .null
        default:
            return .string(String(describing: any))
        }
    }
    
    private func convertDictToAnyValue(_ dict: [String: Any]) -> AnyValue {
        var structure: [String: AnyValue] = [:]
        for (key, value) in dict {
            structure[key] = convertAnyToAnyValue(value)
        }
        return .dictionary(structure)
    }
    
    private func convertAnyValueToDict(_ anyValue: AnyValue) -> [String: Any] {
        switch anyValue {
        case .dictionary(let structure):
            var result: [String: Any] = [:]
            for (key, value) in structure {
                result[key] = convertAnyValueToAny(value)
            }
            return result
        case .array(let list):
            return ["_list": list.map { convertAnyValueToAny($0) }]
        default:
            return ["_value": convertAnyValueToAny(anyValue)]
        }
    }
    
    private func convertAnyValueToAny(_ anyValue: AnyValue) -> Any {
        switch anyValue {
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
                result[key] = convertAnyValueToAny(value)
            }
            return result
        case .array(let list):
            return list.map { convertAnyValueToAny($0) }
        case .null:
            return NSNull()
        }
    }
}
