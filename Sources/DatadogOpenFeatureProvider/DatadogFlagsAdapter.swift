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
    private static let iso8601Formatter = ISO8601DateFormatter()
    
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
        let anyValue = AnyValue(defaultValue)
        let details = flagsClient.getObjectDetails(key: key, defaultValue: anyValue)
        return AdapterFlagResult(
            value: details.value.toDictionary(),
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
}
