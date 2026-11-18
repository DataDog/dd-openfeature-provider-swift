/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

import Foundation
import Testing
import OpenFeature
@_spi(Internal)
import DatadogFlags
import DatadogInternal
@testable import DatadogOpenFeatureProvider

/// A native client that returns the exposure decisions queued for each flag, in order.
internal final class ExposureFlagsClientMock: DatadogFlagsClientMock, FlagsClientInternal, @unchecked Sendable {
    private let lock = NSLock()
    private var queued: [String: [FlagExposureDecision]] = [:]
    var allocationKeys: [String: String] = [:]
    var metadata: [String: [String: AnyValue]] = [:]

    func queue(_ key: String, _ decisions: FlagExposureDecision...) {
        lock.lock()
        defer { lock.unlock() }
        queued[key, default: []].append(contentsOf: decisions)
    }

    func getDetailsWithExposure<T>(key: String, defaultValue: T) -> FlagDetailsWithExposure<T>? where T: Equatable, T: FlagValue {
        var details = getDetails(key: key, defaultValue: defaultValue)
        details.allocationKey = allocationKeys[key]
        details.flagMetadata = metadata[key] ?? [:]
        lock.lock()
        let decision = queued[key]?.isEmpty == false ? queued[key]!.removeFirst() : .none
        lock.unlock()
        return FlagDetailsWithExposure(details: details, exposure: decision)
    }
}

extension FlagExposureDecision {
    static let none = FlagExposureDecision(isExposure: false, isCacheHit: false, targetingKey: nil, features: [:])

    static func exposure(cacheHit: Bool, targetingKey: String? = "user-1", features: [String: AnyValue] = [:]) -> FlagExposureDecision {
        FlagExposureDecision(isExposure: true, isCacheHit: cacheHit, targetingKey: targetingKey, features: features)
    }
}

/// Collects hook evaluations from several threads under a lock.
internal final class EvaluationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [ExposureEvaluation] = []

    func record(_ evaluation: ExposureEvaluation) {
        lock.lock()
        defer { lock.unlock() }
        values.append(evaluation)
    }

    var all: [ExposureEvaluation] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

internal final class RecordingLogger: CoreLogger, @unchecked Sendable {
    private let lock = NSLock()
    private var records: [(CoreLoggerLevel, String)] = []

    func log(_ level: CoreLoggerLevel, message: @autoclosure () -> String, error: Error?) {
        let message = message()
        lock.lock()
        defer { lock.unlock() }
        records.append((level, message))
    }

    func messages(at level: CoreLoggerLevel) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return records.filter { $0.0 == level }.map(\.1)
    }
}

private struct CallbackError: Error {}

private struct OtherProviderMetadata: ProviderMetadata {
    let name: String? = "other"
}

@Suite("ExposureHook end to end", .serialized)
struct ExposureHookEndToEndTests {
    private func makeClient(_ native: DatadogFlagsClientMock, hook: ExposureHook) async -> Client {
        await OpenFeatureAPI.shared.setProviderAndWait(
            provider: DatadogProvider(flagsClient: native),
            initialContext: MutableContext(targetingKey: "user-1", structure: MutableStructure(attributes: ["tier": .string("gold")]))
        )
        let client = OpenFeatureAPI.shared.getClient(name: UUID().uuidString, version: nil)
        client.addHooks(hook)
        return client
    }

    @Test("A first evaluation is a new exposure, and a repeat is a cache hit")
    func firstAndRepeat() async throws {
        let native = ExposureFlagsClientMock()
        native.setupFlag(key: "flag", value: .bool(true), variant: "on", reason: "TARGETING_MATCH")
        native.allocationKeys["flag"] = "allocation"
        native.queue(
            "flag",
            .exposure(cacheHit: false, features: ["holdout.key": .string("h-1"), "holdout.weight": .double(0.5), "holdout.on": .bool(true)]),
            .exposure(cacheHit: true)
        )
        let recorder = EvaluationRecorder()
        let client = await makeClient(native, hook: ExposureHook { recorder.record($0) })

        #expect(client.getBooleanDetails(key: "flag", defaultValue: false).value == true)
        #expect(client.getBooleanDetails(key: "flag", defaultValue: false).value == true)

        let all = recorder.all
        try #require(all.count == 2)
        let first = all[0]
        #expect(first.flagKey == "flag")
        #expect(first.variant == "on")
        #expect(first.allocationKey == "allocation")
        #expect(first.targetingKey == "user-1")
        #expect(first.evaluationContext?.getTargetingKey() == "user-1")
        #expect(first.errorCode == nil)
        #expect(first.features == ["holdout.key": .string("h-1"), "holdout.weight": .double(0.5), "holdout.on": .boolean(true)])
        #expect(first.isExposure && !first.isCacheHit && first.shouldSend)
        #expect(all[1].isExposure && all[1].isCacheHit && !all[1].shouldSend)
    }

    @Test("Split features reach OpenFeature metadata as __dd_feature entries with the allocation key")
    func metadataCarriesHookFeatures() async {
        let native = ExposureFlagsClientMock()
        native.setupFlag(key: "flag", value: .bool(true), variant: "on")
        native.allocationKeys["flag"] = "allocation"
        native.metadata["flag"] = ["__dd_feature.holdout.key": .string("h-1")]
        let client = await makeClient(native, hook: ExposureHook { _ in })

        let details = client.getBooleanDetails(key: "flag", defaultValue: false)

        #expect(details.flagMetadata == ["allocationKey": .string("allocation"), "__dd_feature.holdout.key": .string("h-1")])
    }

    @Test("A throwing callback leaves the evaluation unchanged and logs the first failure as a warning")
    func throwingCallback() async {
        let logger = RecordingLogger()
        let native = ExposureFlagsClientMock()
        native.setupFlag(key: "flag", value: .bool(true), variant: "on")
        let client = await makeClient(native, hook: ExposureHook({ _ in throw CallbackError() }, logger: { logger }))

        for _ in 0..<3 {
            let details = client.getBooleanDetails(key: "flag", defaultValue: false)
            #expect(details.value == true)
            #expect(details.errorCode == nil)
        }

        #expect(logger.messages(at: .warn).filter { $0.contains("callback failed") }.count == 1)
        #expect(logger.messages(at: .debug).filter { $0.contains("callback failed") }.count == 2)
    }

    @Test("A native client without the internal API gives non-exposures")
    func nativeClientWithoutDecisions() async {
        let native = DatadogFlagsClientMock()
        native.setupFlag(key: "plain", value: .bool(true), variant: "on")
        let recorder = EvaluationRecorder()
        let client = await makeClient(native, hook: ExposureHook { recorder.record($0) })

        _ = client.getBooleanDetails(key: "plain", defaultValue: false)

        #expect(recorder.all.map(\.isExposure) == [false])
    }
}

@Suite("ExposureHook decision matching")
struct ExposureHookMatchingTests {
    private func entry(_ key: String, targetingKey: String?, _ decision: FlagExposureDecision, variant: String? = "on", allocationKey: String? = "allocation") -> ExposureDecisionStore.Entry {
        ExposureDecisionStore.Entry(flagKey: key, variant: variant, allocationKey: allocationKey, targetingKey: targetingKey, decision: decision)
    }

    private func handle(_ hook: ExposureHook, _ key: String, targetingKey: String?, errorCode: ErrorCode? = nil, provider: String? = "datadog", variant: String? = "on") {
        hook.handle(
            flagKey: key,
            variant: variant,
            flagMetadata: ["allocationKey": .string("allocation")],
            errorCode: errorCode,
            context: targetingKey.map { MutableContext(targetingKey: $0) },
            providerName: provider
        )
    }

    @Test("Nested evaluations of one flag for different subjects each get their own decision")
    func nestedDifferentSubjects() {
        ExposureDecisionStore.removeAll()
        let recorder = EvaluationRecorder()
        let hook = ExposureHook { recorder.record($0) }
        ExposureDecisionStore.record(entry("flag", targetingKey: "A", .exposure(cacheHit: false, targetingKey: "A")))
        ExposureDecisionStore.record(entry("flag", targetingKey: "B", .exposure(cacheHit: true, targetingKey: "B")))

        handle(hook, "flag", targetingKey: "B")
        handle(hook, "flag", targetingKey: "A")

        #expect(recorder.all.map(\.targetingKey) == ["B", "A"])
        #expect(recorder.all.map(\.isCacheHit) == [true, false])
        #expect(recorder.all.map(\.shouldSend) == [false, true])
    }

    @Test("The decision must match the variant of the evaluation")
    func variantMismatch() {
        ExposureDecisionStore.removeAll()
        let recorder = EvaluationRecorder()
        let hook = ExposureHook { recorder.record($0) }
        ExposureDecisionStore.record(entry("flag", targetingKey: "A", .exposure(cacheHit: false, targetingKey: "A"), variant: "off"))

        handle(hook, "flag", targetingKey: "A", variant: "on")

        #expect(recorder.all.map(\.isExposure) == [false])
    }

    @Test("A failed evaluation is a non-exposure")
    func failedEvaluation() {
        ExposureDecisionStore.removeAll()
        let recorder = EvaluationRecorder()
        let hook = ExposureHook { recorder.record($0) }
        ExposureDecisionStore.record(entry("flag", targetingKey: "A", .exposure(cacheHit: false, targetingKey: "A")))

        handle(hook, "flag", targetingKey: "A", errorCode: .general)

        #expect(recorder.all.map(\.isExposure) == [false])
        #expect(recorder.all.first?.errorCode == .general)
        #expect(recorder.all.first?.features.isEmpty == true)
    }

    @Test("An evaluation before any context has no targeting key")
    func noContext() {
        ExposureDecisionStore.removeAll()
        let recorder = EvaluationRecorder()
        let hook = ExposureHook { recorder.record($0) }
        ExposureDecisionStore.record(entry("flag", targetingKey: nil, .exposure(cacheHit: false, targetingKey: nil)))

        handle(hook, "flag", targetingKey: nil)

        #expect(recorder.all.first?.targetingKey == nil)
        #expect(recorder.all.first?.isExposure == true)
    }

    @Test("Evaluations of other providers are skipped with one warning")
    func otherProvider() {
        let logger = RecordingLogger()
        let recorder = EvaluationRecorder()
        let hook = ExposureHook({ recorder.record($0) }, logger: { logger })

        handle(hook, "flag", targetingKey: "A", provider: "other")
        handle(hook, "flag", targetingKey: "A", provider: nil)

        #expect(recorder.all.isEmpty)
        #expect(logger.messages(at: .warn).filter { $0.contains("DatadogProvider") }.count == 1)
    }

    @Test("The evaluation context is a copy")
    func contextCopy() {
        let recorder = EvaluationRecorder()
        let hook = ExposureHook { recorder.record($0) }
        let context = MutableContext(targetingKey: "A")

        hook.handle(flagKey: "flag", variant: "on", flagMetadata: [:], errorCode: nil, context: context, providerName: "datadog")
        context.setTargetingKey(targetingKey: "changed")

        #expect(recorder.all.first?.evaluationContext?.getTargetingKey() == "A")
    }

    @Test("Each thread keeps at most the newest entries")
    func capacity() {
        ExposureDecisionStore.removeAll()
        for index in 0..<(ExposureDecisionStore.capacity + 4) {
            ExposureDecisionStore.record(entry("flag-\(index)", targetingKey: "A", .none))
        }

        #expect(ExposureDecisionStore.count == ExposureDecisionStore.capacity)
        #expect(ExposureDecisionStore.find(flagKey: "flag-0", variant: "on", allocationKey: "allocation", targetingKey: "A") == nil)
        #expect(ExposureDecisionStore.find(flagKey: "flag-19", variant: "on", allocationKey: "allocation", targetingKey: "A") != nil)
    }

    @Test("Concurrent evaluations keep the decision of their own thread")
    func concurrentThreads() {
        let native = ExposureFlagsClientMock()
        let keys = (0..<8).map { "flag-\($0)" }
        for key in keys {
            native.setupFlag(key: key, value: .bool(true), variant: "on")
            native.allocationKeys[key] = "allocation"
        }
        for _ in 0..<50 {
            for (index, key) in keys.enumerated() {
                native.queue(key, .exposure(cacheHit: index.isMultiple(of: 2), targetingKey: "A"))
            }
        }
        let provider = DatadogProvider(flagsClient: native)
        let recorder = EvaluationRecorder()
        let hook = ExposureHook { recorder.record($0) }

        DispatchQueue.concurrentPerform(iterations: keys.count * 50) { index in
            let key = keys[index % keys.count]
            let evaluation = try? provider.getBooleanEvaluation(key: key, defaultValue: false, context: nil)
            hook.handle(
                flagKey: key,
                variant: evaluation?.variant,
                flagMetadata: evaluation?.flagMetadata ?? [:],
                errorCode: nil,
                context: MutableContext(targetingKey: "A"),
                providerName: "datadog"
            )
        }

        let all = recorder.all
        #expect(all.count == keys.count * 50)
        for (index, key) in keys.enumerated() {
            #expect(all.filter { $0.flagKey == key }.allSatisfy { $0.isExposure && $0.isCacheHit == index.isMultiple(of: 2) })
        }
    }
}
