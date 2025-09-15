import Foundation

public protocol DataDogFlaggingClient {
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

public struct DataDogFlaggingDetails<T> {
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

public protocol DataDogFlaggingClientWithDetails: DataDogFlaggingClient {
    func getBooleanDetails(key: String, defaultValue: Bool) -> DataDogFlaggingDetails<Bool>
    func getBooleanDetails(key: String, defaultValue: Bool, options: [String: Any]?) -> DataDogFlaggingDetails<Bool>
    
    func getStringDetails(key: String, defaultValue: String) -> DataDogFlaggingDetails<String>
    func getStringDetails(key: String, defaultValue: String, options: [String: Any]?) -> DataDogFlaggingDetails<String>
    
    func getIntegerDetails(key: String, defaultValue: Int64) -> DataDogFlaggingDetails<Int64>
    func getIntegerDetails(key: String, defaultValue: Int64, options: [String: Any]?) -> DataDogFlaggingDetails<Int64>
    
    func getDoubleDetails(key: String, defaultValue: Double) -> DataDogFlaggingDetails<Double>
    func getDoubleDetails(key: String, defaultValue: Double, options: [String: Any]?) -> DataDogFlaggingDetails<Double>
    
    func getObjectDetails(key: String, defaultValue: [String: Any]) -> DataDogFlaggingDetails<[String: Any]>
    func getObjectDetails(key: String, defaultValue: [String: Any], options: [String: Any]?) -> DataDogFlaggingDetails<[String: Any]>
}