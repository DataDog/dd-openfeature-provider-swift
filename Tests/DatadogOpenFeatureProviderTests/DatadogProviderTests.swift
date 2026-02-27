/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

import Testing
import Foundation
import OpenFeature
import DatadogFlags
import DatadogInternal
@testable import DatadogOpenFeatureProvider

// MARK: - DatadogProvider Integration Tests

@Suite("DatadogProvider Flag Evaluation")
internal struct FlagEvaluationTests {
    @Test("Boolean flag evaluation")
    func booleanEvaluation() async throws {
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

    @Test("String flag evaluation")
    func stringEvaluation() async throws {
        let mockFlagsClient = DatadogFlagsClientMock()
        mockFlagsClient.setupFlag(key: "test-flag", value: AnyValue.string("test-value"), variant: "test-variant", reason: "test-reason")

        let provider = DatadogProvider(flagsClient: mockFlagsClient)
        let result = try provider.getStringEvaluation(key: "test-flag", defaultValue: "default", context: nil)

        #expect(result.value == "test-value")
        #expect(result.variant == "test-variant")
        #expect(result.reason == "test-reason")
    }

    @Test("Integer flag evaluation")
    func integerEvaluation() async throws {
        let mockFlagsClient = DatadogFlagsClientMock()
        mockFlagsClient.setupFlag(key: "test-flag", value: AnyValue.int(42), variant: "test-variant", reason: "test-reason")

        let provider = DatadogProvider(flagsClient: mockFlagsClient)
        let result = try provider.getIntegerEvaluation(key: "test-flag", defaultValue: 0, context: nil)

        #expect(result.value == 42)
        #expect(result.variant == "test-variant")
        #expect(result.reason == "test-reason")
    }

    @Test("Double flag evaluation")
    func doubleEvaluation() async throws {
        let mockFlagsClient = DatadogFlagsClientMock()
        mockFlagsClient.setupFlag(key: "test-flag", value: AnyValue.double(3.14), variant: "test-variant", reason: "test-reason")

        let provider = DatadogProvider(flagsClient: mockFlagsClient)
        let result = try provider.getDoubleEvaluation(key: "test-flag", defaultValue: 0.0, context: nil)

        #expect(result.value == 3.14)
        #expect(result.variant == "test-variant")
        #expect(result.reason == "test-reason")
    }

    @Test("Direct provider integration")
    func directProviderIntegration() async throws {
        let mockFlagsClient = DatadogFlagsClientMock()
        mockFlagsClient.setupFlag(key: "test-bool", value: AnyValue.bool(true), variant: "on", reason: "targeting_match")

        let provider = DatadogProvider(flagsClient: mockFlagsClient)

        let result = try provider.getBooleanEvaluation(key: "test-bool", defaultValue: false, context: nil)

        #expect(result.value == true)
        #expect(result.variant == "on")
        #expect(result.reason == "targeting_match")
    }
}

@Suite("DatadogProvider Metadata & Configuration")
internal struct ProviderMetadataTests {
    @Test("Provider metadata")
    func providerMetadata() async throws {
        let mockFlagsClient = DatadogFlagsClientMock()
        let provider = DatadogProvider(flagsClient: mockFlagsClient)

        #expect(provider.metadata.name == "datadog")
    }

    @Test("Provider with mock client")
    func providerWithMockClient() async throws {
        let mockFlagsClient = DatadogFlagsClientMock()
        let provider = DatadogProvider(flagsClient: mockFlagsClient)

        #expect(provider.metadata.name == "datadog")
    }

    @Test("Provider with default constructor")
    func providerWithDefaultConstructor() async throws {
        // Test the public constructor with default parameters
        // In test environment without proper initialization, this returns NOPFlagsClient
        let provider = DatadogProvider()
        #expect(provider.metadata.name == "datadog")

        // Verify it handles flag evaluation gracefully with NOPFlagsClient
        let result = try provider.getBooleanEvaluation(key: "test-flag", defaultValue: false, context: nil)
        #expect(result.value == false) // default value
    }

    @Test("Empty metadata in evaluation results")
    func emptyMetadataInResults() async throws {
        let mockFlagsClient = DatadogFlagsClientMock()
        mockFlagsClient.setupFlag(key: "test-flag", value: AnyValue.bool(true), variant: "on", reason: "targeting_match")

        let provider = DatadogProvider(flagsClient: mockFlagsClient)

        // Create context with targeting key and attributes
        let context = MutableContext(
            targetingKey: "user456",
            structure: MutableStructure(attributes: [
                "segment": Value.string("beta"),
                "plan": Value.string("pro"),
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
}

@Suite("DatadogProvider Context Management")
internal struct ContextManagementTests {
    @Test("Provider initialization with context")
    func providerInitializationWithContext() async throws {
        // Given
        let mockFlagsClient = DatadogFlagsClientMock()
        let provider = DatadogProvider(flagsClient: mockFlagsClient)
        let context = MutableContext(
            targetingKey: "user123",
            structure: MutableStructure(attributes: [
                "email": Value.string("test@example.com"),
                "age": Value.integer(25),
            ])
        )

        // When
        try await provider.initialize(initialContext: context)

        // Then
        #expect(mockFlagsClient.lastSetContext != nil)
        #expect(mockFlagsClient.lastSetContext?.targetingKey == "user123")
    }

    @Test("Initialize does not throw when state is stale")
    func initializeDoesNotThrowWhenStale() async throws {
        // Given
        let mockFlagsClient = DatadogFlagsClientMock()
        mockFlagsClient.setEvaluationContextResult = .failure(.networkError(URLError(.notConnectedToInternet)))
        mockFlagsClient.mockStateManager.simulateStateChange(.stale)
        let provider = DatadogProvider(flagsClient: mockFlagsClient)
        let context = MutableContext(targetingKey: "user123")

        // When/Then — should not throw because we're in stale state (cached flags available)
        try await provider.initialize(initialContext: context)
    }

    @Test("Initialize throws when state is error")
    func initializeThrowsWhenError() async throws {
        // Given
        let mockFlagsClient = DatadogFlagsClientMock()
        mockFlagsClient.setEvaluationContextResult = .failure(.networkError(URLError(.notConnectedToInternet)))
        mockFlagsClient.mockStateManager.simulateStateChange(.error)
        let provider = DatadogProvider(flagsClient: mockFlagsClient)
        let context = MutableContext(targetingKey: "user123")

        // When/Then — should throw because we're in error state (no cached flags)
        await #expect(throws: FlagsError.self) {
            try await provider.initialize(initialContext: context)
        }
    }

    @Test("onContextSet does not throw when state is stale")
    func onContextSetDoesNotThrowWhenStale() async throws {
        // Given
        let mockFlagsClient = DatadogFlagsClientMock()
        mockFlagsClient.setEvaluationContextResult = .failure(.networkError(URLError(.timedOut)))
        mockFlagsClient.mockStateManager.simulateStateChange(.stale)
        let provider = DatadogProvider(flagsClient: mockFlagsClient)
        let oldContext = MutableContext(targetingKey: "user123")
        let newContext = MutableContext(targetingKey: "user456")

        // When/Then — should not throw because we're in stale state
        try await provider.onContextSet(oldContext: oldContext, newContext: newContext)
    }
}

@Suite("DatadogProvider State Events")
internal struct StateEventTests {
    @Test("observe() emits .ready when state transitions to ready")
    func observeEmitsReady() async throws {
        // Given
        let mockFlagsClient = DatadogFlagsClientMock()
        let provider = DatadogProvider(flagsClient: mockFlagsClient)
        var receivedEvents: [ProviderEvent] = []
        let cancellable = provider.observe().sink { event in
            if let event { receivedEvents.append(event) }
        }

        // When
        mockFlagsClient.mockStateManager.simulateStateChange(.ready)

        // Then
        #expect(receivedEvents.contains(.ready))
        _ = cancellable
    }

    @Test("observe() emits .stale when state transitions to stale")
    func observeEmitsStale() async throws {
        // Given
        let mockFlagsClient = DatadogFlagsClientMock()
        let provider = DatadogProvider(flagsClient: mockFlagsClient)
        var receivedEvents: [ProviderEvent] = []
        let cancellable = provider.observe().sink { event in
            if let event { receivedEvents.append(event) }
        }

        // When
        mockFlagsClient.mockStateManager.simulateStateChange(.stale)

        // Then
        #expect(receivedEvents.contains(.stale))
        _ = cancellable
    }

    @Test("observe() emits .error when state transitions to error")
    func observeEmitsError() async throws {
        // Given
        let mockFlagsClient = DatadogFlagsClientMock()
        let provider = DatadogProvider(flagsClient: mockFlagsClient)
        var receivedEvents: [ProviderEvent] = []
        let cancellable = provider.observe().sink { event in
            if let event { receivedEvents.append(event) }
        }

        // When
        mockFlagsClient.mockStateManager.simulateStateChange(.error)

        // Then
        #expect(receivedEvents.contains(where: { if case .error = $0 { return true } else { return false } }))
        _ = cancellable
    }

    @Test("observe() filters notReady and reconciling states")
    func observeFiltersNotReadyAndReconciling() async throws {
        // Given
        let mockFlagsClient = DatadogFlagsClientMock()
        let provider = DatadogProvider(flagsClient: mockFlagsClient)
        var receivedEvents: [ProviderEvent] = []
        let cancellable = provider.observe().sink { event in
            if let event { receivedEvents.append(event) }
        }

        // When
        mockFlagsClient.mockStateManager.simulateStateChange(.notReady)
        mockFlagsClient.mockStateManager.simulateStateChange(.reconciling)

        // Then — neither should produce events
        #expect(receivedEvents.isEmpty)
        _ = cancellable
    }

    @Test("observe() emits full state transition sequence")
    func observeEmitsFullSequence() async throws {
        // Given
        let mockFlagsClient = DatadogFlagsClientMock()
        let provider = DatadogProvider(flagsClient: mockFlagsClient)
        var receivedEvents: [ProviderEvent] = []
        let cancellable = provider.observe().sink { event in
            if let event { receivedEvents.append(event) }
        }

        // When — simulate: notReady -> reconciling -> ready -> reconciling -> stale
        mockFlagsClient.mockStateManager.simulateStateChange(.reconciling)
        mockFlagsClient.mockStateManager.simulateStateChange(.ready)
        mockFlagsClient.mockStateManager.simulateStateChange(.reconciling)
        mockFlagsClient.mockStateManager.simulateStateChange(.stale)

        // Then — only ready and stale should be emitted
        #expect(receivedEvents.count == 2)
        #expect(receivedEvents[0] == .ready)
        #expect(receivedEvents[1] == .stale)
        _ = cancellable
    }
}
