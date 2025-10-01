import Foundation
import DatadogFlags
import OpenFeature

public class DatadogFlagsAdapter: DatadogFlaggingClientWithDetails {
    public let flagsClient: FlagsClientProtocol
    
    public init(flagsClient: FlagsClientProtocol) {
        self.flagsClient = flagsClient
    }
    
    // MARK: - DatadogFlaggingClient Methods (Simple Values)
    
    public func getBooleanValue(key: String, defaultValue: Bool) -> Bool {
        return flagsClient.getBooleanValue(key: key, defaultValue: defaultValue)
    }
    
    public func getBooleanValue(key: String, defaultValue: Bool, options: [String: Any]?) -> Bool {
        // Note: DatadogFlags doesn't support per-evaluation context, so we ignore options here
        return flagsClient.getBooleanValue(key: key, defaultValue: defaultValue)
    }
    
    public func getStringValue(key: String, defaultValue: String) -> String {
        return flagsClient.getStringValue(key: key, defaultValue: defaultValue)
    }
    
    public func getStringValue(key: String, defaultValue: String, options: [String: Any]?) -> String {
        // Note: DatadogFlags doesn't support per-evaluation context, so we ignore options here
        return flagsClient.getStringValue(key: key, defaultValue: defaultValue)
    }
    
    public func getIntegerValue(key: String, defaultValue: Int64) -> Int64 {
        let intValue = Int(defaultValue)
        let result = flagsClient.getIntegerValue(key: key, defaultValue: intValue)
        return Int64(result)
    }
    
    public func getIntegerValue(key: String, defaultValue: Int64, options: [String: Any]?) -> Int64 {
        // Note: DatadogFlags doesn't support per-evaluation context, so we ignore options here
        let intValue = Int(defaultValue)
        let result = flagsClient.getIntegerValue(key: key, defaultValue: intValue)
        return Int64(result)
    }
    
    public func getDoubleValue(key: String, defaultValue: Double) -> Double {
        return flagsClient.getDoubleValue(key: key, defaultValue: defaultValue)
    }
    
    public func getDoubleValue(key: String, defaultValue: Double, options: [String: Any]?) -> Double {
        // Note: DatadogFlags doesn't support per-evaluation context, so we ignore options here
        return flagsClient.getDoubleValue(key: key, defaultValue: defaultValue)
    }
    
    public func getObjectValue(key: String, defaultValue: [String: Any]) -> [String: Any] {
        let anyValue = convertDictToAnyValue(defaultValue)
        let result = flagsClient.getObjectValue(key: key, defaultValue: anyValue)
        return convertAnyValueToDict(result)
    }
    
    public func getObjectValue(key: String, defaultValue: [String: Any], options: [String: Any]?) -> [String: Any] {
        // Note: DatadogFlags doesn't support per-evaluation context, so we ignore options here
        let anyValue = convertDictToAnyValue(defaultValue)
        let result = flagsClient.getObjectValue(key: key, defaultValue: anyValue)
        return convertAnyValueToDict(result)
    }
    
    // MARK: - DatadogFlaggingClientWithDetails Methods (Detailed Responses)
    
    public func getBooleanDetails(key: String, defaultValue: Bool) -> DatadogFlaggingDetails<Bool> {
        let details = flagsClient.getBooleanDetails(key: key, defaultValue: defaultValue)
        return DatadogFlaggingDetails(
            value: details.value,
            variant: details.variant,
            reason: details.reason,
            metadata: [:]
        )
    }
    
    public func getBooleanDetails(key: String, defaultValue: Bool, options: [String: Any]?) -> DatadogFlaggingDetails<Bool> {
        // Note: DatadogFlags doesn't support per-evaluation context, so we ignore options here
        let details = flagsClient.getBooleanDetails(key: key, defaultValue: defaultValue)
        return DatadogFlaggingDetails(
            value: details.value,
            variant: details.variant,
            reason: details.reason,
            metadata: [:]
        )
    }
    
    public func getStringDetails(key: String, defaultValue: String) -> DatadogFlaggingDetails<String> {
        let details = flagsClient.getStringDetails(key: key, defaultValue: defaultValue)
        return DatadogFlaggingDetails(
            value: details.value,
            variant: details.variant,
            reason: details.reason,
            metadata: [:]
        )
    }
    
    public func getStringDetails(key: String, defaultValue: String, options: [String: Any]?) -> DatadogFlaggingDetails<String> {
        // Note: DatadogFlags doesn't support per-evaluation context, so we ignore options here
        let details = flagsClient.getStringDetails(key: key, defaultValue: defaultValue)
        return DatadogFlaggingDetails(
            value: details.value,
            variant: details.variant,
            reason: details.reason,
            metadata: [:]
        )
    }
    
    public func getIntegerDetails(key: String, defaultValue: Int64) -> DatadogFlaggingDetails<Int64> {
        let intValue = Int(defaultValue)
        let details = flagsClient.getIntegerDetails(key: key, defaultValue: intValue)
        return DatadogFlaggingDetails(
            value: Int64(details.value),
            variant: details.variant,
            reason: details.reason,
            metadata: [:]
        )
    }
    
    public func getIntegerDetails(key: String, defaultValue: Int64, options: [String: Any]?) -> DatadogFlaggingDetails<Int64> {
        // Note: DatadogFlags doesn't support per-evaluation context, so we ignore options here
        let intValue = Int(defaultValue)
        let details = flagsClient.getIntegerDetails(key: key, defaultValue: intValue)
        return DatadogFlaggingDetails(
            value: Int64(details.value),
            variant: details.variant,
            reason: details.reason,
            metadata: [:]
        )
    }
    
    public func getDoubleDetails(key: String, defaultValue: Double) -> DatadogFlaggingDetails<Double> {
        let details = flagsClient.getDoubleDetails(key: key, defaultValue: defaultValue)
        return DatadogFlaggingDetails(
            value: details.value,
            variant: details.variant,
            reason: details.reason,
            metadata: [:]
        )
    }
    
    public func getDoubleDetails(key: String, defaultValue: Double, options: [String: Any]?) -> DatadogFlaggingDetails<Double> {
        // Note: DatadogFlags doesn't support per-evaluation context, so we ignore options here
        let details = flagsClient.getDoubleDetails(key: key, defaultValue: defaultValue)
        return DatadogFlaggingDetails(
            value: details.value,
            variant: details.variant,
            reason: details.reason,
            metadata: [:]
        )
    }
    
    public func getObjectDetails(key: String, defaultValue: [String: Any]) -> DatadogFlaggingDetails<[String: Any]> {
        let anyValue = convertDictToAnyValue(defaultValue)
        let details = flagsClient.getObjectDetails(key: key, defaultValue: anyValue)
        return DatadogFlaggingDetails(
            value: convertAnyValueToDict(details.value),
            variant: details.variant,
            reason: details.reason,
            metadata: [:]
        )
    }
    
    public func getObjectDetails(key: String, defaultValue: [String: Any], options: [String: Any]?) -> DatadogFlaggingDetails<[String: Any]> {
        // Note: DatadogFlags doesn't support per-evaluation context, so we ignore options here
        let anyValue = convertDictToAnyValue(defaultValue)
        let details = flagsClient.getObjectDetails(key: key, defaultValue: anyValue)
        return DatadogFlaggingDetails(
            value: convertAnyValueToDict(details.value),
            variant: details.variant,
            reason: details.reason,
            metadata: [:]
        )
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
