/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2026-Present Datadog, Inc.
 */

import Foundation
@_spi(Internal)
import DatadogCore
@_spi(Internal)
import DatadogFlags
import DatadogOpenFeatureProvider
import OpenFeature

// Built by run.py with the actual local SDK and provider packages. No mock FlagsClient.
@main
struct PrivacyWireProbe {
    @MainActor
    static func main() async throws {
        let base = URL(string: ProcessInfo.processInfo.environment["FFL_PII_URL"]!)!
        let instance = "pii-\(UUID().uuidString)"
        let context = FlagsEvaluationContext(targetingKey: "jane.doe@datadoghq.com", attributes: ["private": .string("CONTEXT_CANARY")])
        let ofContext = MutableContext(targetingKey: context.targetingKey, structure: MutableStructure(attributes: ["private": .string("CONTEXT_CANARY")]))
        let api = OpenFeatureAPI()

        func control(_ state: String, offline: Bool = false) async throws {
            var request = URLRequest(url: base.appendingPathComponent("control"))
            request.httpMethod = "POST"
            request.httpBody = try JSONSerialization.data(withJSONObject: ["state": state, "offline": offline])
            let (_, response) = try await URLSession.shared.data(for: request)
            precondition((response as? HTTPURLResponse)?.statusCode == 200)
        }

        func start(tracking: Bool = true) -> FlagsClientProtocol {
            let core = Datadog.initialize(with: .init(clientToken: "local-test", env: "privacy-test"), trackingConsent: .granted, instanceName: instance)
            Flags.enable(with: .init(
                customFlagsEndpoint: base.appendingPathComponent("assignments"),
                trackExposures: false,
                customEvaluationEndpoint: base.appendingPathComponent("evaluations"),
                trackEvaluations: tracking,
                evaluationFlushInterval: 60
            ), in: core)
            return FlagsClient.create(name: "direct", in: core)
        }

        func refresh(_ client: FlagsClientProtocol) async throws {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                client.setEvaluationContext(context) { continuation.resume(with: $0.mapError { $0 as Error }) }
            }
        }

        let direct = start()
        let core = Datadog.sdkInstance(named: instance)
        for state in ["absent", "false", "null", "wrong", "true"] {
            try await control(state)
            try await refresh(direct)
            await api.setProviderAndWait(provider: DatadogProvider(name: "provider-\(state)", core: core), initialContext: ofContext)
            precondition(api.getProviderStatus() == .ready)
            let client = api.getClient()
            let key = "bool-\(state)"
            let expectedConsent = state == "true"
            let native = direct.getBooleanDetails(key: key, defaultValue: false)
            let result = client.getBooleanDetails(key: key, defaultValue: false)
            precondition(native.value && result.value)
            precondition(native.observeFullEvaluationData == expectedConsent)
            precondition(result.flagMetadata["__dd_observe_full_evaluation_data"] == .boolean(expectedConsent))
            precondition(direct.getStringValue(key: "string-\(state)", defaultValue: "") == "ok")
            precondition(client.getStringValue(key: "string-\(state)", defaultValue: "") == "ok")
            precondition(direct.getIntegerValue(key: "int-\(state)", defaultValue: 0) == 42)
            precondition(client.getIntegerValue(key: "int-\(state)", defaultValue: 0) == 42)
            precondition(direct.getDoubleValue(key: "double-\(state)", defaultValue: 0) == 1.5)
            precondition(client.getDoubleValue(key: "double-\(state)", defaultValue: 0) == 1.5)
            precondition(direct.getObjectValue(key: "object-\(state)", defaultValue: .null) == .dictionary(["ok": .bool(true)]))
            precondition(client.getObjectValue(key: "object-\(state)", defaultValue: .null) == .structure(["ok": .boolean(true)]))
            precondition(direct.getBooleanDetails(key: "missing-\(state)", defaultValue: false).error == .flagNotFound)
            let missing = client.getBooleanDetails(key: "missing-\(state)", defaultValue: false)
            precondition(missing.errorCode == .flagNotFound)
            precondition(missing.flagMetadata["__dd_observe_full_evaluation_data"] == .boolean(expectedConsent))
            precondition(direct.getStringDetails(key: key, defaultValue: "fallback").error == .typeMismatch)
            precondition(client.getStringDetails(key: key, defaultValue: "fallback").errorCode == .typeMismatch)

            // Refresh to opposite consent before upload; pending events must retain the old mode.
            try await control(expectedConsent ? "false" : "true")
            try await refresh(direct)
            await api.setEvaluationContextAndWait(evaluationContext: ofContext)
        }
        // The endpoint fails its first upload to exercise the existing persisted retry path.
        Datadog.flush(instanceName: instance)
        Datadog.flush(instanceName: instance)
        Datadog.flushAndDeinitialize(instanceName: instance)

        // Restore the final protected configuration from disk while the endpoint is offline.
        try await control("false", offline: true)
        let restored = start()
        do { try await refresh(restored); preconditionFailure("Expected offline refresh failure") } catch {}
        precondition(restored.state.currentState == .stale)
        let offline = restored.getBooleanDetails(key: "bool-false", defaultValue: false)
        precondition(offline.value && !offline.observeFullEvaluationData && offline.reason == "CACHED")
        let restoredCore = Datadog.sdkInstance(named: instance)
        await api.setProviderAndWait(provider: DatadogProvider(name: "provider-true", core: restoredCore), initialContext: ofContext)
        precondition(api.getProviderStatus() == .stale || api.getProviderStatus() == .ready)
        let offlineOF = api.getClient().getBooleanDetails(key: "bool-false", defaultValue: false)
        precondition(offlineOF.value)
        precondition(offlineOF.flagMetadata["__dd_observe_full_evaluation_data"] == .boolean(false))
        Datadog.flushAndDeinitialize(instanceName: instance)

        // Tracking disable wins, including calls routed through OpenFeature.
        try await control("disabled")
        let disabled = start(tracking: false)
        try await refresh(disabled)
        await api.setProviderAndWait(provider: DatadogProvider(name: "disabled", core: Datadog.sdkInstance(named: instance)), initialContext: ofContext)
        precondition(disabled.getBooleanValue(key: "bool-disabled", defaultValue: false))
        precondition(api.getClient().getBooleanValue(key: "bool-disabled", defaultValue: false))
        Datadog.flushAndDeinitialize(instanceName: instance)
        api.clearProvider()
    }
}
