/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

import Foundation
import DatadogFlags
@testable import DatadogOpenFeatureProvider

// MARK: - Shared Test Utilities

/// Mock DatadogFlags Client for Testing
internal class DatadogFlagsClientMock: FlagsClientProtocol {
    private struct FlagData {
        let value: AnyValue
        let variant: String?
        let reason: String?
    }

    private var flags: [String: FlagData] = [:]
    var lastSetContext: FlagsEvaluationContext?
    let mockStateManager = MockFlagsStateObservable()
    var setEvaluationContextResult: Result<Void, FlagsError> = .success(())

    var state: FlagsStateObservable { mockStateManager }

    func setupFlag(key: String, value: AnyValue, variant: String? = nil, reason: String? = nil) {
        flags[key] = FlagData(value: value, variant: variant, reason: reason)
    }

    func setEvaluationContext(_ context: FlagsEvaluationContext, completion: @escaping (Result<Void, FlagsError>) -> Void) {
        lastSetContext = context
        completion(setEvaluationContextResult)
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

// MARK: - Mock State Observable

/// Mirrors production `FlagsStateManager`: listeners are held weakly and unchanged state
/// transitions are deduplicated, so tests exercise the same lifecycle and notification
/// semantics as the SDK rather than diverging behavior that could mask a production regression.
internal class MockFlagsStateObservable: FlagsStateObservable {
    /// Weak wrapper mirroring production's `WeakListener`, so a listener retained only by its
    /// subscription is released once that subscription goes away.
    private struct WeakListener {
        weak var value: FlagsStateListener?

        init(_ value: FlagsStateListener) {
            self.value = value
        }
    }

    private(set) var _currentState: FlagsClientState = .notReady
    private var listeners: [WeakListener] = []

    var currentState: FlagsClientState { _currentState }

    /// Number of live (non-deallocated) listeners. Used by tests to assert cleanup on cancel.
    var listenerCount: Int {
        listeners.filter { $0.value != nil }.count
    }

    func simulateStateChange(_ newState: FlagsClientState) {
        // Mirror production `FlagsStateManager.updateState`, which early-returns when the
        // state is unchanged.
        guard newState != _currentState else {
            return
        }
        _currentState = newState
        for weakListener in listeners {
            weakListener.value?.flagsStateDidChange(newState)
        }
    }

    func addListener(_ listener: FlagsStateListener) {
        listeners.removeAll { $0.value == nil }
        listeners.append(WeakListener(listener))
        listener.flagsStateDidChange(_currentState)
    }

    func removeListener(_ listener: FlagsStateListener) {
        listeners.removeAll { $0.value === listener || $0.value == nil }
    }
}
