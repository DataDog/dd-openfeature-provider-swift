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
        return try await withCheckedThrowingContinuation { [flagsClient] continuation in
            flagsClient.setEvaluationContext(context) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    // Reading `state.currentState` here relies on a load-bearing ordering
                    // guarantee: upstream `FlagsRepository.setEvaluationContext` updates the
                    // state (to `.stale` or `.error`) *before* invoking this failure
                    // completion. Verified against dd-sdk-ios 3.11.0. A refactor on either side
                    // that reorders the state update relative to the callback would silently
                    // break this check.
                    if flagsClient.state.currentState == .stale {
                        // The client fell back to cached flags, so treat the context change as
                        // a success and surface staleness via `observe()` (matches Android).
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
        Deferred { [flagsClient] in
            // Seed a `CurrentValueSubject` and let `addListener` populate the initial value.
            // `addListener` synchronously calls `flagsStateDidChange` with the current state,
            // so the initial event is captured atomically with listener registration.
            //
            // Reading `currentState` separately and using `.prepend` instead would open a
            // race: if the state changed between that read and `addListener`, the prepended
            // snapshot would be stale while the listener's immediate callback would be dropped
            // (no subscriber yet), leaving the subscriber stuck on the wrong state until the
            // next transition.
            //
            // Delivers the initial state on subscription per OpenFeature Requirement 5.3.3.
            let subject = CurrentValueSubject<ProviderEvent?, Never>(nil)
            let listener = ProviderStateListener(subject: subject)
            flagsClient.state.addListener(listener)
            return subject
                .handleEvents(receiveCancel: {
                    flagsClient.state.removeListener(listener)
                })
        }
        .eraseToAnyPublisher()
    }

    fileprivate static func mapStateToEvent(_ state: FlagsClientState) -> ProviderEvent? {
        switch state {
        case .notReady, .reconciling:
            nil
        case .ready:
            .ready
        case .stale:
            .stale
        case .error:
            .error()
        }
    }
}

internal final class ProviderStateListener: FlagsStateListener {
    private let subject: CurrentValueSubject<ProviderEvent?, Never>

    init(subject: CurrentValueSubject<ProviderEvent?, Never>) {
        self.subject = subject
    }

    func flagsStateDidChange(_ newState: FlagsClientState) {
        if let event = DatadogProvider.mapStateToEvent(newState) {
            subject.send(event)
        }
    }
}
