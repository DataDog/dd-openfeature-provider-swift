/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

import Foundation
import OpenFeature
@_spi(Internal)
import DatadogFlags
import DatadogInternal

/// An OpenFeature hook that passes each completed evaluation of a `DatadogProvider` to a callback, with the
/// exposure decision that the Datadog SDK uses for Datadog.
///
/// Use it to record exposures in your own data store:
///
/// ```swift
/// OpenFeatureAPI.shared.addHooks(hooks: ExposureHook { evaluation in
///     guard evaluation.shouldSend else { return }
///     warehouse.enqueue(evaluation.flagKey, evaluation.variant, evaluation.features)
/// })
/// ```
///
/// The callback runs synchronously in the hook's `finally` stage, on the thread that evaluated the flag,
/// including the main thread. Several threads can call it at the same time, so it must be thread-safe.
/// An evaluation inside the callback calls the hook again, so avoid unbounded recursion. Keep it short and move
/// I/O to another queue. The hook catches and logs an error thrown by the callback; OpenFeature Swift hooks are
/// non-throwing, so the evaluation result stays the same. The hook observes evaluations; the SDK records exposures.
public final class ExposureHook: Hook, @unchecked Sendable {
    public typealias HookValue = Bool

    // The callback is immutable and the flags are lock-protected, so the hook is safe to share across threads.
    private let callback: @Sendable (ExposureEvaluation) throws -> Void
    private let logger: @Sendable () -> CoreLogger
    private let lock = NSLock()
    private var hasLoggedError = false
    private var hasWarnedAboutProvider = false

    /// Creates a hook that calls `callback` after each evaluation of a `DatadogProvider`.
    public convenience init(_ callback: @escaping @Sendable (ExposureEvaluation) throws -> Void) {
        self.init(callback, logger: { DD.logger })
    }

    internal init(_ callback: @escaping @Sendable (ExposureEvaluation) throws -> Void, logger: @escaping @Sendable () -> CoreLogger) {
        self.callback = callback
        self.logger = logger
    }

    public func supportsFlagValueType(flagValueType: FlagValueType) -> Bool {
        true
    }

    public func finally<HookValue>(ctx: HookContext<HookValue>, details: FlagEvaluationDetails<HookValue>, hints: [String: Any]) {
        handle(
            flagKey: ctx.flagKey,
            variant: details.variant,
            flagMetadata: details.flagMetadata,
            errorCode: details.errorCode,
            context: ctx.ctx,
            providerName: ctx.providerMetadata?.name
        )
    }

    internal func handle(
        flagKey: String,
        variant: String?,
        flagMetadata: [String: FlagMetadataValue],
        errorCode: ErrorCode?,
        context: EvaluationContext?,
        providerName: String?
    ) {
        guard providerName == DatadogProviderMetadata.providerName else {
            warnOnceAboutProvider(providerName)
            return
        }
        let allocationKey = flagMetadata[DatadogProviderMetadata.allocationKey]?.asString()
        let targetingKey = context.map { $0.getTargetingKey() }
        let decision = errorCode == nil
            ? ExposureDecisionStore.find(flagKey: flagKey, variant: variant, allocationKey: allocationKey, targetingKey: targetingKey)?.decision
            : nil
        let evaluation = ExposureEvaluation(
            flagKey: flagKey,
            variant: variant,
            allocationKey: allocationKey,
            targetingKey: targetingKey,
            evaluationContext: context?.deepCopy(),
            errorCode: errorCode,
            features: decision?.features.compactMapValues(FlagMetadataValue.init(splitFeature:)) ?? [:],
            isExposure: decision?.isExposure ?? false,
            isCacheHit: decision?.isCacheHit ?? false
        )
        do {
            try callback(evaluation)
        } catch {
            logCallbackFailure(error)
        }
    }

    private func logCallbackFailure(_ error: Error) {
        lock.lock()
        let isFirstError = !hasLoggedError
        hasLoggedError = true
        lock.unlock()
        if isFirstError {
            logger().warn("`ExposureHook` callback failed. Later failures are logged at debug level.", error: error)
        } else {
            logger().debug("`ExposureHook` callback failed.", error: error)
        }
    }

    private func warnOnceAboutProvider(_ providerName: String?) {
        lock.lock()
        let isFirstWarning = !hasWarnedAboutProvider
        hasWarnedAboutProvider = true
        lock.unlock()
        if isFirstWarning {
            logger().warn("`ExposureHook` received an evaluation from provider '\(providerName ?? "unknown")'. It reports evaluations of `DatadogProvider` only.")
        }
    }
}

/// A completed evaluation of a `DatadogProvider`, as seen by ``ExposureHook``.
///
/// The SDK creates every value; the initializer stays internal, as in the other Datadog client SDKs.
public struct ExposureEvaluation {
    /// The evaluated flag key.
    public let flagKey: String

    /// The served variant, or `nil` when evaluation failed.
    public let variant: String?

    /// The allocation that served the value, or `nil` when evaluation failed.
    public let allocationKey: String?

    /// The targeting key of ``evaluationContext``, or `nil` for an evaluation made before any context was set.
    public let targetingKey: String?

    /// A copy of the evaluation context used for the evaluation.
    public let evaluationContext: EvaluationContext?

    /// The OpenFeature error code, or `nil` for a successful evaluation.
    public let errorCode: ErrorCode?

    /// Features that the split sends to customer code, keyed by feature key (for example `holdout.key`).
    public let features: [String: FlagMetadataValue]

    /// `true` for a successful evaluation of an allocation that logs exposures, with a non-blank allocation key
    /// and variant, repeats included.
    public let isExposure: Bool

    /// For an exposure (`isExposure`), `true` when the client's exposure cache holds the same allocation, variant
    /// and split for the subject and flag. After an exposure of another assignment, or after the cache evicts the
    /// entry, the next exposure is new.
    public let isCacheHit: Bool

    /// `true` for a new exposure (`isExposure` and a cache miss). The Datadog write depends on
    /// `Flags.Configuration.trackExposures` and the tracking consent.
    public var shouldSend: Bool { isExposure && !isCacheHit }
}

extension FlagMetadataValue {
    /// Split feature values are strings, numbers or booleans; any other value has no metadata form.
    init?(splitFeature value: AnyValue) {
        switch value {
        case .bool(let value): self = .boolean(value)
        case .int(let value): self = .integer(Int64(value))
        case .double(let value): self = .double(value)
        case .string(let value): self = .string(value)
        case .dictionary, .array, .null: return nil
        }
    }
}
