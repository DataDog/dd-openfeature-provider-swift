import Testing
import Foundation
import OpenFeature
import DatadogFlags
@testable import DatadogOpenFeatureProvider


@Test func testBooleanEvaluation() async throws {
    let mockFlagsClient = MockDatadogFlagsClient()
    mockFlagsClient.setupFlag(key: "test-flag", value: AnyValue.bool(true), variant: "test-variant", reason: "test-reason")
    
    let provider = DatadogProvider(flagsClient: mockFlagsClient)
    let result = try provider.getBooleanEvaluation(key: "test-flag", defaultValue: false, context: nil)
    
    #expect(result.value == true)
    #expect(result.variant == "test-variant")
    #expect(result.reason == "test-reason")
}

@Test func testStringEvaluation() async throws {
    let mockFlagsClient = MockDatadogFlagsClient()
    mockFlagsClient.setupFlag(key: "test-flag", value: AnyValue.string("test-value"), variant: "test-variant", reason: "test-reason")
    
    let provider = DatadogProvider(flagsClient: mockFlagsClient)
    let result = try provider.getStringEvaluation(key: "test-flag", defaultValue: "default", context: nil)
    
    #expect(result.value == "test-value")
    #expect(result.variant == "test-variant")
    #expect(result.reason == "test-reason")
}

@Test func testIntegerEvaluation() async throws {
    let mockFlagsClient = MockDatadogFlagsClient()
    mockFlagsClient.setupFlag(key: "test-flag", value: AnyValue.int(42), variant: "test-variant", reason: "test-reason")
    
    let provider = DatadogProvider(flagsClient: mockFlagsClient)
    let result = try provider.getIntegerEvaluation(key: "test-flag", defaultValue: 0, context: nil)
    
    #expect(result.value == 42)
    #expect(result.variant == "test-variant")
    #expect(result.reason == "test-reason")
}

@Test func testDoubleEvaluation() async throws {
    let mockFlagsClient = MockDatadogFlagsClient()
    mockFlagsClient.setupFlag(key: "test-flag", value: AnyValue.double(3.14), variant: "test-variant", reason: "test-reason")
    
    let provider = DatadogProvider(flagsClient: mockFlagsClient)
    let result = try provider.getDoubleEvaluation(key: "test-flag", defaultValue: 0.0, context: nil)
    
    #expect(result.value == 3.14)
    #expect(result.variant == "test-variant")
    #expect(result.reason == "test-reason")
}

@Test func testProviderMetadata() async throws {
    let mockFlagsClient = MockDatadogFlagsClient()
    let provider = DatadogProvider(flagsClient: mockFlagsClient)
    
    #expect(provider.metadata.name == "Datadog OpenFeature Provider")
}

@Test func testProviderFactory() async throws {
    let mockFlagsClient = MockDatadogFlagsClient()
    let provider = DatadogOpenFeatureProvider.createProvider(flagsClient: mockFlagsClient)
    
    #expect(provider.metadata.name == "Datadog OpenFeature Provider")
}

// MARK: - Integration Tests with DatadogFlagsAdapter

@Test func testDatadogFlagsAdapterIntegration() async throws {
    let mockFlagsClient = MockDatadogFlagsClient()
    mockFlagsClient.setupFlag(key: "test-bool", value: AnyValue.bool(true), variant: "on", reason: "targeting_match")
    
    let provider = DatadogProvider(flagsClient: mockFlagsClient)
    
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

@Test func testMetadataPopulation() async throws {
    let mockFlagsClient = MockDatadogFlagsClient()
    mockFlagsClient.setupFlag(key: "test-flag", value: AnyValue.bool(true), variant: "on", reason: "targeting_match")
    
    let provider = DatadogProvider(flagsClient: mockFlagsClient)
    
    // Create context with targeting key and attributes
    let context = ImmutableContext(
        targetingKey: "user456",
        structure: ImmutableStructure(attributes: [
            "segment": Value.string("beta"),
            "plan": Value.string("pro")
        ])
    )
    
    let result = try provider.getBooleanEvaluation(key: "test-flag", defaultValue: false, context: context)
    
    // Verify basic flag evaluation
    #expect(result.value == true)
    #expect(result.variant == "on")
    #expect(result.reason == "targeting_match")
    
    // Verify metadata is populated
    #expect(result.flagMetadata.count > 0)
    
    // Check that metadata contains expected keys
    let metadataKeys = result.flagMetadata.keys
    #expect(metadataKeys.contains("flagKey"))
    #expect(metadataKeys.contains("provider"))
    #expect(metadataKeys.contains("evaluationTime"))
    #expect(metadataKeys.contains("targetingKey"))
    #expect(metadataKeys.contains("segment"))
    #expect(metadataKeys.contains("plan"))
    
    // Check metadata values
    #expect(result.flagMetadata["flagKey"]?.asString() == "test-flag")
    #expect(result.flagMetadata["provider"]?.asString() == "DatadogFlags")
    #expect(result.flagMetadata["targetingKey"]?.asString() == "user456")
    #expect(result.flagMetadata["segment"]?.asString() == "beta")
    #expect(result.flagMetadata["plan"]?.asString() == "pro")
    
    // Check that evaluationTime is a valid ISO 8601 timestamp
    if let evaluationTime = result.flagMetadata["evaluationTime"]?.asString() {
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: evaluationTime)
        #expect(date != nil)
    }
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
