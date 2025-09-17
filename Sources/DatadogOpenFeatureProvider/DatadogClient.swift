import Foundation

public protocol DatadogFlaggingClient {
    func getBooleanValue(key: String, defaultValue: Bool) -> Bool
    func getBooleanValue(key: String, defaultValue: Bool, options: [String: Any]?) -> Bool
    
    func getStringValue(key: String, defaultValue: String) -> String
    func getStringValue(key: String, defaultValue: String, options: [String: Any]?) -> String
    
    func getIntegerValue(key: String, defaultValue: Int64) -> Int64
    func getIntegerValue(key: String, defaultValue: Int64, options: [String: Any]?) -> Int64
    
    func getDoubleValue(key: String, defaultValue: Double) -> Double
    func getDoubleValue(key: String, defaultValue: Double, options: [String: Any]?) -> Double
    
    func getObjectValue(key: String, defaultValue: [String: Any]) -> [String: Any]
    func getObjectValue(key: String, defaultValue: [String: Any], options: [String: Any]?) -> [String: Any]
}

public struct DatadogFlaggingDetails<T> {
    public let value: T
    public let variant: String?
    public let reason: String?
    public let metadata: [String: Any]
    
    public init(value: T, variant: String? = nil, reason: String? = nil, metadata: [String: Any] = [:]) {
        self.value = value
        self.variant = variant
        self.reason = reason
        self.metadata = metadata
    }
}

public protocol DatadogFlaggingClientWithDetails: DatadogFlaggingClient {
    func getBooleanDetails(key: String, defaultValue: Bool) -> DatadogFlaggingDetails<Bool>
    func getBooleanDetails(key: String, defaultValue: Bool, options: [String: Any]?) -> DatadogFlaggingDetails<Bool>
    
    func getStringDetails(key: String, defaultValue: String) -> DatadogFlaggingDetails<String>
    func getStringDetails(key: String, defaultValue: String, options: [String: Any]?) -> DatadogFlaggingDetails<String>
    
    func getIntegerDetails(key: String, defaultValue: Int64) -> DatadogFlaggingDetails<Int64>
    func getIntegerDetails(key: String, defaultValue: Int64, options: [String: Any]?) -> DatadogFlaggingDetails<Int64>
    
    func getDoubleDetails(key: String, defaultValue: Double) -> DatadogFlaggingDetails<Double>
    func getDoubleDetails(key: String, defaultValue: Double, options: [String: Any]?) -> DatadogFlaggingDetails<Double>
    
    func getObjectDetails(key: String, defaultValue: [String: Any]) -> DatadogFlaggingDetails<[String: Any]>
    func getObjectDetails(key: String, defaultValue: [String: Any], options: [String: Any]?) -> DatadogFlaggingDetails<[String: Any]>
}
