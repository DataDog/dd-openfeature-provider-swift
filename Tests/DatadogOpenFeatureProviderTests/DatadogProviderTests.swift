import Testing
import Foundation
import OpenFeature
import DatadogFlags
import DatadogInternal
@testable import DatadogOpenFeatureProvider

// MARK: - DatadogProvider Integration Tests

@Test func testBooleanEvaluation() async throws {
    // Given
    let mockFlagsClient = DatadogFlagsClientMock()
    mockFlagsClient.setupFlag(key: "test-flag", value: AnyValue.bool(true), variant: "test-variant", reason: "test-reason")
    let provider = DatadogProvider(flagsClient: mockFlagsClient)
    
    // When
    let result = try provider.getBooleanEvaluation(key: "test-flag", defaultValue: false, context: nil)
    
    // Then
    #expect(result.value == true)
    #expect(result.variant == "test-variant")
    #expect(result.reason == "test-reason")
}

@Test func testStringEvaluation() async throws {
    let mockFlagsClient = DatadogFlagsClientMock()
    mockFlagsClient.setupFlag(key: "test-flag", value: AnyValue.string("test-value"), variant: "test-variant", reason: "test-reason")
    
    let provider = DatadogProvider(flagsClient: mockFlagsClient)
    let result = try provider.getStringEvaluation(key: "test-flag", defaultValue: "default", context: nil)
    
    #expect(result.value == "test-value")
    #expect(result.variant == "test-variant")
    #expect(result.reason == "test-reason")
}

@Test func testIntegerEvaluation() async throws {
    let mockFlagsClient = DatadogFlagsClientMock()
    mockFlagsClient.setupFlag(key: "test-flag", value: AnyValue.int(42), variant: "test-variant", reason: "test-reason")
    
    let provider = DatadogProvider(flagsClient: mockFlagsClient)
    let result = try provider.getIntegerEvaluation(key: "test-flag", defaultValue: 0, context: nil)
    
    #expect(result.value == 42)
    #expect(result.variant == "test-variant")
    #expect(result.reason == "test-reason")
}

@Test func testDoubleEvaluation() async throws {
    let mockFlagsClient = DatadogFlagsClientMock()
    mockFlagsClient.setupFlag(key: "test-flag", value: AnyValue.double(3.14), variant: "test-variant", reason: "test-reason")
    
    let provider = DatadogProvider(flagsClient: mockFlagsClient)
    let result = try provider.getDoubleEvaluation(key: "test-flag", defaultValue: 0.0, context: nil)
    
    #expect(result.value == 3.14)
    #expect(result.variant == "test-variant")
    #expect(result.reason == "test-reason")
}

@Test func testProviderMetadata() async throws {
    let mockFlagsClient = DatadogFlagsClientMock()
    let provider = DatadogProvider(flagsClient: mockFlagsClient)
    
    #expect(provider.metadata.name == "datadog")
}

@Test func testProviderWithMockClient() async throws {
    let mockFlagsClient = DatadogFlagsClientMock()
    let provider = DatadogProvider(flagsClient: mockFlagsClient)
    
    #expect(provider.metadata.name == "datadog")
}

@Test func testProviderWithDefaultConstructor() async throws {
    // Test the public constructor with default parameters
    // In test environment without proper initialization, this returns NOPFlagsClient
    let provider = DatadogProvider()
    #expect(provider.metadata.name == "datadog")
    
    // Verify it handles flag evaluation gracefully with NOPFlagsClient
    let result = try provider.getBooleanEvaluation(key: "test-flag", defaultValue: false, context: nil)
    #expect(result.value == false) // default value
}

@Test func testDirectProviderIntegration() async throws {
    let mockFlagsClient = DatadogFlagsClientMock()
    mockFlagsClient.setupFlag(key: "test-bool", value: AnyValue.bool(true), variant: "on", reason: "targeting_match")
    
    let provider = DatadogProvider(flagsClient: mockFlagsClient)
    
    let result = try provider.getBooleanEvaluation(key: "test-bool", defaultValue: false, context: nil)
    
    #expect(result.value == true)
    #expect(result.variant == "on")
    #expect(result.reason == "targeting_match")
}

@Test func testProviderInitializationWithContext() async throws {
    // Given
    let mockFlagsClient = DatadogFlagsClientMock()
    let provider = DatadogProvider(flagsClient: mockFlagsClient)
    let context = ImmutableContext(
        targetingKey: "user123",
        structure: ImmutableStructure(attributes: [
            "email": Value.string("test@example.com"),
            "age": Value.integer(25)
        ])
    )
    
    // When
    try await provider.initialize(initialContext: context)
    
    // Then
    #expect(mockFlagsClient.lastSetContext != nil)
    #expect(mockFlagsClient.lastSetContext?.targetingKey == "user123")
}

@Test func testEmptyMetadataInResults() async throws {
    let mockFlagsClient = DatadogFlagsClientMock()
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
    
    // Verify metadata is empty as expected
    #expect(result.flagMetadata.isEmpty)
}