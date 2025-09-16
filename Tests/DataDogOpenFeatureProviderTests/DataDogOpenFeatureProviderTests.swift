import Testing
import OpenFeature
@testable import DatadogOpenFeatureProvider

class MockDatadogClient: DatadogFlaggingClientWithDetails {
    var booleanValues: [String: Bool] = [:]
    var stringValues: [String: String] = [:]
    var integerValues: [String: Int64] = [:]
    var doubleValues: [String: Double] = [:]
    var objectValues: [String: [String: Any]] = [:]
    
    func getBooleanValue(key: String, defaultValue: Bool) -> Bool {
        return booleanValues[key] ?? defaultValue
    }
    
    func getBooleanValue(key: String, defaultValue: Bool, options: [String: Any]?) -> Bool {
        return booleanValues[key] ?? defaultValue
    }
    
    func getStringValue(key: String, defaultValue: String) -> String {
        return stringValues[key] ?? defaultValue
    }
    
    func getStringValue(key: String, defaultValue: String, options: [String: Any]?) -> String {
        return stringValues[key] ?? defaultValue
    }
    
    func getIntegerValue(key: String, defaultValue: Int64) -> Int64 {
        return integerValues[key] ?? defaultValue
    }
    
    func getIntegerValue(key: String, defaultValue: Int64, options: [String: Any]?) -> Int64 {
        return integerValues[key] ?? defaultValue
    }
    
    func getDoubleValue(key: String, defaultValue: Double) -> Double {
        return doubleValues[key] ?? defaultValue
    }
    
    func getDoubleValue(key: String, defaultValue: Double, options: [String: Any]?) -> Double {
        return doubleValues[key] ?? defaultValue
    }
    
    func getObjectValue(key: String, defaultValue: [String: Any]) -> [String: Any] {
        return objectValues[key] ?? defaultValue
    }
    
    func getObjectValue(key: String, defaultValue: [String: Any], options: [String: Any]?) -> [String: Any] {
        return objectValues[key] ?? defaultValue
    }
    
    func getBooleanDetails(key: String, defaultValue: Bool) -> DatadogFlaggingDetails<Bool> {
        let value = booleanValues[key] ?? defaultValue
        return DatadogFlaggingDetails(value: value, variant: "test-variant", reason: "test-reason")
    }
    
    func getBooleanDetails(key: String, defaultValue: Bool, options: [String: Any]?) -> DatadogFlaggingDetails<Bool> {
        let value = booleanValues[key] ?? defaultValue
        return DatadogFlaggingDetails(value: value, variant: "test-variant", reason: "test-reason")
    }
    
    func getStringDetails(key: String, defaultValue: String) -> DatadogFlaggingDetails<String> {
        let value = stringValues[key] ?? defaultValue
        return DatadogFlaggingDetails(value: value, variant: "test-variant", reason: "test-reason")
    }
    
    func getStringDetails(key: String, defaultValue: String, options: [String: Any]?) -> DatadogFlaggingDetails<String> {
        let value = stringValues[key] ?? defaultValue
        return DatadogFlaggingDetails(value: value, variant: "test-variant", reason: "test-reason")
    }
    
    func getIntegerDetails(key: String, defaultValue: Int64) -> DatadogFlaggingDetails<Int64> {
        let value = integerValues[key] ?? defaultValue
        return DatadogFlaggingDetails(value: value, variant: "test-variant", reason: "test-reason")
    }
    
    func getIntegerDetails(key: String, defaultValue: Int64, options: [String: Any]?) -> DatadogFlaggingDetails<Int64> {
        let value = integerValues[key] ?? defaultValue
        return DatadogFlaggingDetails(value: value, variant: "test-variant", reason: "test-reason")
    }
    
    func getDoubleDetails(key: String, defaultValue: Double) -> DatadogFlaggingDetails<Double> {
        let value = doubleValues[key] ?? defaultValue
        return DatadogFlaggingDetails(value: value, variant: "test-variant", reason: "test-reason")
    }
    
    func getDoubleDetails(key: String, defaultValue: Double, options: [String: Any]?) -> DatadogFlaggingDetails<Double> {
        let value = doubleValues[key] ?? defaultValue
        return DatadogFlaggingDetails(value: value, variant: "test-variant", reason: "test-reason")
    }
    
    func getObjectDetails(key: String, defaultValue: [String: Any]) -> DatadogFlaggingDetails<[String: Any]> {
        let value = objectValues[key] ?? defaultValue
        return DatadogFlaggingDetails(value: value, variant: "test-variant", reason: "test-reason")
    }
    
    func getObjectDetails(key: String, defaultValue: [String: Any], options: [String: Any]?) -> DatadogFlaggingDetails<[String: Any]> {
        let value = objectValues[key] ?? defaultValue
        return DatadogFlaggingDetails(value: value, variant: "test-variant", reason: "test-reason")
    }
}

@Test func testBooleanEvaluation() async throws {
    let mockClient = MockDatadogClient()
    mockClient.booleanValues["test-flag"] = true
    
    let provider = DatadogProvider(client: mockClient)
    let result = try provider.getBooleanEvaluation(key: "test-flag", defaultValue: false, context: nil)
    
    #expect(result.value == true)
    #expect(result.variant == "test-variant")
    #expect(result.reason == "test-reason")
}

@Test func testStringEvaluation() async throws {
    let mockClient = MockDatadogClient()
    mockClient.stringValues["test-flag"] = "test-value"
    
    let provider = DatadogProvider(client: mockClient)
    let result = try provider.getStringEvaluation(key: "test-flag", defaultValue: "default", context: nil)
    
    #expect(result.value == "test-value")
    #expect(result.variant == "test-variant")
    #expect(result.reason == "test-reason")
}

@Test func testIntegerEvaluation() async throws {
    let mockClient = MockDatadogClient()
    mockClient.integerValues["test-flag"] = 42
    
    let provider = DatadogProvider(client: mockClient)
    let result = try provider.getIntegerEvaluation(key: "test-flag", defaultValue: 0, context: nil)
    
    #expect(result.value == 42)
    #expect(result.variant == "test-variant")
    #expect(result.reason == "test-reason")
}

@Test func testDoubleEvaluation() async throws {
    let mockClient = MockDatadogClient()
    mockClient.doubleValues["test-flag"] = 3.14
    
    let provider = DatadogProvider(client: mockClient)
    let result = try provider.getDoubleEvaluation(key: "test-flag", defaultValue: 0.0, context: nil)
    
    #expect(result.value == 3.14)
    #expect(result.variant == "test-variant")
    #expect(result.reason == "test-reason")
}

@Test func testProviderMetadata() async throws {
    let mockClient = MockDatadogClient()
    let provider = DatadogProvider(client: mockClient)
    
    #expect(provider.metadata.name == "Datadog OpenFeature Provider")
}

@Test func testProviderFactory() async throws {
    let mockClient = MockDatadogClient()
    let provider = DatadogOpenFeatureProvider.createProvider(client: mockClient)
    
    #expect(provider.metadata.name == "Datadog OpenFeature Provider")
}
