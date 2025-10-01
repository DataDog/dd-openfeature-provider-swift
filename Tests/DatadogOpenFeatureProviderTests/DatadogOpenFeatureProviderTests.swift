import Testing
import OpenFeature
import DatadogFlags
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

// MARK: - Integration Tests with DatadogFlagsAdapter

@Test func testDatadogFlagsAdapterIntegration() async throws {
    let mockFlagsClient = MockDatadogFlagsClient()
    mockFlagsClient.setupFlag(key: "test-bool", value: AnyValue.bool(true), variant: "on", reason: "targeting_match")
    
    let adapter = DatadogFlagsAdapter(flagsClient: mockFlagsClient)
    let provider = DatadogProvider(client: adapter)
    
    let result = try provider.getBooleanEvaluation(key: "test-bool", defaultValue: false, context: nil)
    
    #expect(result.value == true)
    #expect(result.variant == "on")
    #expect(result.reason == "targeting_match")
}

@Test func testDatadogFlagsFactoryMethod() async throws {
    let mockFlagsClient = MockDatadogFlagsClient()
    let provider = DatadogOpenFeatureProvider.createProvider(flagsClient: mockFlagsClient)
    
    #expect(provider.metadata.name == "Datadog OpenFeature Provider")
}

@Test func testContextConversionAndAsyncOperations() async throws {
    let mockFlagsClient = MockDatadogFlagsClient()
    let provider = DatadogProvider(flagsClient: mockFlagsClient)
    
    let context = ImmutableContext(
        targetingKey: "user123",
        structure: ImmutableStructure(attributes: [
            "email": Value.string("test@example.com"),
            "age": Value.integer(25)
        ])
    )
    
    try await provider.initialize(initialContext: context)
    
    #expect(mockFlagsClient.lastSetContext != nil)
    #expect(mockFlagsClient.lastSetContext?.targetingKey == "user123")
}

// MARK: - Mock DatadogFlags Client for Integration Testing

class MockDatadogFlagsClient: FlagsClientProtocol {
    private var flags: [String: (value: AnyValue, variant: String?, reason: String?)] = [:]
    var lastSetContext: FlagsEvaluationContext?
    
    func setupFlag(key: String, value: AnyValue, variant: String? = nil, reason: String? = nil) {
        flags[key] = (value: value, variant: variant, reason: reason)
    }
    
    func getDetails<T>(key: String, defaultValue: T) -> FlagDetails<T> where T: Equatable, T: FlagValue {
        if let flag = flags[key] {
            if let value = convertAnyValueToType(flag.value, as: T.self) {
                return FlagDetails(
                    key: key,
                    value: value,
                    variant: flag.variant,
                    reason: flag.reason,
                    error: nil
                )
            }
        }
        return FlagDetails(
            key: key,
            value: defaultValue,
            variant: nil,
            reason: "default",
            error: nil
        )
    }
    
    func getBooleanDetails(key: String, defaultValue: Bool) -> FlagDetails<Bool> {
        return getDetails(key: key, defaultValue: defaultValue)
    }
    
    func getStringDetails(key: String, defaultValue: String) -> FlagDetails<String> {
        return getDetails(key: key, defaultValue: defaultValue)
    }
    
    func getIntegerDetails(key: String, defaultValue: Int) -> FlagDetails<Int> {
        return getDetails(key: key, defaultValue: defaultValue)
    }
    
    func getDoubleDetails(key: String, defaultValue: Double) -> FlagDetails<Double> {
        return getDetails(key: key, defaultValue: defaultValue)
    }
    
    func getObjectDetails(key: String, defaultValue: AnyValue) -> FlagDetails<AnyValue> {
        return getDetails(key: key, defaultValue: defaultValue)
    }
    
    func getBooleanValue(key: String, defaultValue: Bool) -> Bool {
        return getBooleanDetails(key: key, defaultValue: defaultValue).value
    }
    
    func getStringValue(key: String, defaultValue: String) -> String {
        return getStringDetails(key: key, defaultValue: defaultValue).value
    }
    
    func getIntegerValue(key: String, defaultValue: Int) -> Int {
        return getIntegerDetails(key: key, defaultValue: defaultValue).value
    }
    
    func getDoubleValue(key: String, defaultValue: Double) -> Double {
        return getDoubleDetails(key: key, defaultValue: defaultValue).value
    }
    
    func getObjectValue(key: String, defaultValue: AnyValue) -> AnyValue {
        return getObjectDetails(key: key, defaultValue: defaultValue).value
    }
    
    func setEvaluationContext(_ context: FlagsEvaluationContext, completion: @escaping (Result<Void, FlagsError>) -> Void) {
        lastSetContext = context
        completion(.success(()))
    }
    
    private func convertAnyValueToType<T>(_ anyValue: AnyValue, as type: T.Type) -> T? {
        switch anyValue {
        case .bool(let bool) where T.self == Bool.self:
            return bool as? T
        case .string(let string) where T.self == String.self:
            return string as? T
        case .int(let int) where T.self == Int.self:
            return int as? T
        case .double(let double) where T.self == Double.self:
            return double as? T
        case _ where T.self == AnyValue.self:
            return anyValue as? T
        default:
            return nil
        }
    }
}
