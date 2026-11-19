/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

import Foundation
import DatadogFlags
import OpenFeature

// MARK: - ProviderEvaluation Extensions

extension ProviderEvaluation where T == Bool {
    /// Creates ProviderEvaluation<Bool> from DatadogFlags FlagDetails<Bool>
    init(_ details: FlagDetails<Bool>) {
        let error = details.openFeatureError
        self.init(
            value: details.value,
            flagMetadata: details.allocationKey.map { ["allocationKey": FlagMetadataValue.string($0)] } ?? [:],
            variant: details.variant,
            reason: error == nil ? details.reason : Reason.error.rawValue,
            errorCode: error?.errorCode(),
            errorMessage: error?.description
        )
    }
}

extension ProviderEvaluation where T == String {
    /// Creates ProviderEvaluation<String> from DatadogFlags FlagDetails<String>
    init(_ details: FlagDetails<String>) {
        let error = details.openFeatureError
        self.init(
            value: details.value,
            flagMetadata: details.allocationKey.map { ["allocationKey": FlagMetadataValue.string($0)] } ?? [:],
            variant: details.variant,
            reason: error == nil ? details.reason : Reason.error.rawValue,
            errorCode: error?.errorCode(),
            errorMessage: error?.description
        )
    }
}

extension ProviderEvaluation where T == Double {
    /// Creates ProviderEvaluation<Double> from DatadogFlags FlagDetails<Double>
    init(_ details: FlagDetails<Double>) {
        let error = details.openFeatureError
        self.init(
            value: details.value,
            flagMetadata: details.allocationKey.map { ["allocationKey": FlagMetadataValue.string($0)] } ?? [:],
            variant: details.variant,
            reason: error == nil ? details.reason : Reason.error.rawValue,
            errorCode: error?.errorCode(),
            errorMessage: error?.description
        )
    }
}

extension ProviderEvaluation where T == Int64 {
    /// Specialized initializer for Int64 evaluations that handles Int->Int64 conversion
    /// from DatadogFlags FlagDetails<Int> to ProviderEvaluation<Int64>
    init(_ details: FlagDetails<Int>) {
        let error = details.openFeatureError
        self.init(
            value: Int64(details.value),
            flagMetadata: details.allocationKey.map { ["allocationKey": FlagMetadataValue.string($0)] } ?? [:],
            variant: details.variant,
            reason: error == nil ? details.reason : Reason.error.rawValue,
            errorCode: error?.errorCode(),
            errorMessage: error?.description
        )
    }
}

extension ProviderEvaluation where T == Value {
    /// Specialized initializer for Value evaluations that handles AnyValue->Value conversion
    /// from DatadogFlags FlagDetails<AnyValue> to ProviderEvaluation<Value>
    init(_ details: FlagDetails<AnyValue>) {
        let error = details.openFeatureError
        self.init(
            value: Value(details.value),
            flagMetadata: details.allocationKey.map { ["allocationKey": FlagMetadataValue.string($0)] } ?? [:],
            variant: details.variant,
            reason: error == nil ? details.reason : Reason.error.rawValue,
            errorCode: error?.errorCode(),
            errorMessage: error?.description
        )
    }
}

private extension FlagDetails {
    var openFeatureError: OpenFeatureError? {
        guard let error else {
            return nil
        }
        // Preserve this provider's existing evaluation details for errors from older SDKs.
        if case .providerNotReady = error {
            return nil
        }
        if case .flagNotFound = error {
            return nil
        }
        if case .typeMismatch = error {
            return nil
        }
        // Newer native SDKs can add errors, including subject-authorization failures.
        // Keep compatibility with the supported SDK range by classifying them as GENERAL
        // without referencing cases absent from the minimum supported SDK.
        return .generalError(message: "Flag evaluation failed.")
    }
}
