/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

import Foundation
import OpenFeature
import Combine
import DatadogFlags
import DatadogInternal

public class DatadogProvider: FeatureProvider {
    public let hooks: [any Hook] = []
    public let metadata: ProviderMetadata

    private let flagsClient: FlagsClientProtocol
    private var stateListener: ProviderStateListener?

    public init(
        name: String = FlagsClient.defaultName,
        core: DatadogCoreProtocol = CoreRegistry.default
    ) {
        self.flagsClient = FlagsClient.create(name: name, in: core)
        self.metadata = DatadogProviderMetadata()
    }

    /// Internal initializer for testing purposes only
    internal init(flagsClient: FlagsClientProtocol) {
        self.flagsClient = flagsClient
        self.metadata = DatadogProviderMetadata()
    }

    public func initialize(initialContext: EvaluationContext?) async throws {
        if let context = initialContext {
            let ddContext = try FlagsEvaluationContext(context)
            try await setEvaluationContextAsync(ddContext)
        }
    }

    public func onContextSet(oldContext: EvaluationContext?, newContext: EvaluationContext) async throws {
        let ddContext = try FlagsEvaluationContext(newContext)
        try await setEvaluationContextAsync(ddContext)
    }

    private func setEvaluationContextAsync(_ context: FlagsEvaluationContext) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            flagsClient.setEvaluationContext(context) { [weak self] result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    if self?.flagsClient.state.currentState == .stale {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    public func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws -> ProviderEvaluation<Bool> {
        let details = flagsClient.getBooleanDetails(key: key, defaultValue: defaultValue)
        return ProviderEvaluation(details)
    }

    public func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws -> ProviderEvaluation<String> {
        let details = flagsClient.getStringDetails(key: key, defaultValue: defaultValue)
        return ProviderEvaluation(details)
    }

    public func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws -> ProviderEvaluation<Int64> {
        let intValue = Int(defaultValue)
        let details = flagsClient.getIntegerDetails(key: key, defaultValue: intValue)
        return ProviderEvaluation(details)
    }

    public func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws -> ProviderEvaluation<Double> {
        let details = flagsClient.getDoubleDetails(key: key, defaultValue: defaultValue)
        return ProviderEvaluation(details)
    }

    public func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws -> ProviderEvaluation<Value> {
        let defaultAnyValue = try AnyValue(defaultValue)
        let details = flagsClient.getObjectDetails(key: key, defaultValue: defaultAnyValue)
        return ProviderEvaluation(details)
    }
}

internal struct DatadogProviderMetadata: ProviderMetadata {
    let name: String? = "datadog"
}

extension DatadogProvider: EventPublisher {
    public func observe() -> AnyPublisher<ProviderEvent?, Never> {
        let subject = PassthroughSubject<ProviderEvent?, Never>()
        let listener = ProviderStateListener(subject: subject)
        flagsClient.state.addListener(listener)
        self.stateListener = listener
        return subject.eraseToAnyPublisher()
    }
}

internal final class ProviderStateListener: FlagsStateListener {
    private let subject: PassthroughSubject<ProviderEvent?, Never>

    init(subject: PassthroughSubject<ProviderEvent?, Never>) {
        self.subject = subject
    }

    func flagsStateDidChange(_ newState: FlagsClientState) {
        let event: ProviderEvent? = switch newState {
        case .notReady, .reconciling:
            nil
        case .ready:
            .ready
        case .stale:
            .stale
        case .error:
            .error()
        }
        if let event {
            subject.send(event)
        }
    }
}
