/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

import XCTest
import Foundation
import Network
import Compression
import OpenFeature
import DatadogFlags
import DatadogRUM
@testable import DatadogCore
@testable import DatadogOpenFeatureProvider

/// Uses the actual provider, native client, and URLSession against a loopback HTTP intake.
final class EvaluationTelemetryLocalIntakeTests: XCTestCase {
    @MainActor
    func testOptOutPreservesExposureAndUnrelatedRUM() async throws {
        try await runLocalIntake(enabled: true, value: .boolean(true))
    }

    @MainActor
    func testDisabledControlPreservesTelemetry() async throws {
        try await runLocalIntake(enabled: false, value: .boolean(true))
    }

    @MainActor
    func testOnlyTypedTrueSuppressesTelemetry() async throws {
        for value: Value? in [nil, .boolean(false), .null, .string("true"), .integer(1), .double(1), .list([.boolean(true)]), .structure(["value": .boolean(true)])] {
            try await runLocalIntake(enabled: true, value: value)
        }
    }

    @MainActor
    func testAttributeTargetsAssignmentsThroughOpenFeatureAndPreservesExposureDeduplication() async throws {
        for enabled in [false, true] {
            let ready = expectation(description: "targeting intake ready")
            let server = try ProviderLocalIntake(ready: ready)
            server.start()
            await fulfillment(of: [ready], timeout: 5)
            defer { server.stop() }
            let instanceName = "provider-targeting-\(UUID().uuidString)"
            let core = Datadog.initialize(with: .init(clientToken: "local-intake-token", env: "local-test"), trackingConsent: .granted, instanceName: instanceName)
            defer { Datadog.internalFlushAndDeinitialize(instanceName: instanceName) }
            Flags.enable(
                with: .init(customFlagsEndpoint: try server.url("assignments"), customExposureEndpoint: try server.url("exposures"), customEvaluationEndpoint: try server.url("evaluations")),
                in: core
            )
            let provider = DatadogProvider(enableEvaluationTelemetryOptOutParameter: enabled, core: core)
            let api = OpenFeatureAPI()
            defer { api.clearProvider() }
            await api.setProviderAndWait(provider: provider, initialContext: context(.boolean(false)))
            let client = api.getClient()
            let hook = CustomerHook()
            client.addHooks(hook)
            for (index, optOut) in [false, true, false].enumerated() {
                if index > 0 {
                    await api.setEvaluationContextAndWait(evaluationContext: context(.boolean(optOut)))
                }
                let details = client.getBooleanDetails(key: "targeting-flag", defaultValue: !optOut)
                XCTAssertEqual(details.value, optOut)
                XCTAssertEqual(details.variant, String(optOut))
                XCTAssertEqual(details.reason, "TARGETING_MATCH")
                XCTAssertEqual(details.flagMetadata["allocationKey"], .string("targeted-allocation"))
                XCTAssertEqual(client.getBooleanValue(key: "targeting-flag", defaultValue: !optOut), optOut)
            }
            XCTAssertEqual(hook.calls, 6)
            Datadog.internalFlushAndDeinitialize(instanceName: instanceName)
            let exposedValues = try server.events(at: "exposures").map { exposure in
                let subject = try XCTUnwrap(exposure["subject"] as? [String: Any])
                let attributes = try XCTUnwrap(subject["attributes"] as? [String: Any])
                return try XCTUnwrap(attributes["dd_evaluation_telemetry_opt_out"] as? Bool)
            }
            XCTAssertEqual(exposedValues, [false, true, false])
            let evaluationCount = try server.evaluations().reduce(0) { $0 + ($1["evaluation_count"] as? Int ?? 0) }
            XCTAssertEqual(evaluationCount, enabled ? 4 : 6)
            XCTAssertEqual(server.assignmentCount, 3)
            print("Provider targeting: enabled=\(enabled), assignments=3, exposures=3, evaluations=\(evaluationCount), hooks=6")
        }
    }

    @MainActor
    private func runLocalIntake(enabled: Bool, value: Value?) async throws {
        let ready = expectation(description: "loopback intake ready")
        let server = try ProviderLocalIntake(ready: ready)
        server.start()
        await fulfillment(of: [ready], timeout: 5)
        defer { server.stop() }

        let instanceName = "provider-opt-out-\(UUID().uuidString)"
        let core = Datadog.initialize(
            with: .init(clientToken: "local-intake-token", env: "local-test"),
            trackingConsent: .granted,
            instanceName: instanceName
        )
        defer { Datadog.internalFlushAndDeinitialize(instanceName: instanceName) }
        RUM.enable(with: .init(applicationID: UUID().uuidString, customEndpoint: try server.url("rum")), in: core)
        Flags.enable(
            with: .init(
                customFlagsEndpoint: try server.url("assignments"),
                customExposureEndpoint: try server.url("exposures"),
                customEvaluationEndpoint: try server.url("evaluations")
            ),
            in: core
        )
        let provider = enabled
            ? DatadogProvider(enableEvaluationTelemetryOptOutParameter: true, core: core)
            : DatadogProvider(core: core)
        let api = OpenFeatureAPI()
        defer { api.clearProvider() }
        var attributes: [String: Value] = ["plan": .string("standard")]
        attributes["dd_evaluation_telemetry_opt_out"] = value
        let context = MutableContext(targetingKey: "local-user", structure: MutableStructure(attributes: attributes))
        await api.setProviderAndWait(provider: provider, initialContext: context)
        XCTAssertEqual(api.getProviderStatus(), .ready)
        let client = api.getClient()
        let hook = CustomerHook()
        client.addHooks(hook)
        let monitor = RUMMonitor.shared(in: core)
        monitor.startView(key: "local-view", name: "Local View")
        let result = client.getBooleanDetails(key: "local-flag", defaultValue: false)
        XCTAssertTrue(result.value)
        XCTAssertEqual(result.variant, "enabled")
        XCTAssertEqual(result.reason, "TARGETING_MATCH")
        XCTAssertEqual(result.flagMetadata["allocationKey"], .string("allocation"))
        XCTAssertNil(result.errorCode)
        XCTAssertFalse(client.getBooleanValue(key: "missing", defaultValue: false))
        XCTAssertEqual(client.getStringValue(key: "local-flag", defaultValue: "fallback"), "fallback")
        XCTAssertEqual(hook.calls, 3)
        try XCTUnwrap(core as? DatadogCore).flush()
        monitor.addError(message: "unrelated application error")
        monitor.stopView(key: "local-view")
        Datadog.internalFlushAndDeinitialize(instanceName: instanceName)

        let assignments = server.requests.filter { $0.url?.path == "/assignments" }
        let exposures = try server.events(at: "exposures")
        let evaluations = try server.evaluations()
        let rum = try server.events(at: "rum")
        let optedOut = enabled && value == .boolean(true)
        print("Provider intake: enabled=\(enabled), value=\(String(describing: value)), assignments=\(assignments.count), exposures=\(exposures.count), evaluations=\(evaluations.count), RUM=\(rum.count)")
        XCTAssertEqual(assignments.count, 1)
        XCTAssertEqual(exposures.count, 1)
        XCTAssertEqual(evaluations.count, optedOut ? 0 : 3)
        XCTAssertTrue(rum.contains { $0["type"] as? String == "view" })
        XCTAssertTrue(rum.contains { $0["type"] as? String == "error" })
        XCTAssertEqual(rum.contains { ($0["feature_flags"] as? [String: Any])?["local-flag"] != nil }, !optedOut)
        let requestBody = try JSONSerialization.jsonObject(with: XCTUnwrap(assignments.first?.httpBody)) as? [String: Any]
        let data = try XCTUnwrap(requestBody?["data"] as? [String: Any])
        let requestAttributes = try XCTUnwrap(data["attributes"] as? [String: Any])
        let requestSubject = try XCTUnwrap(requestAttributes["subject"] as? [String: Any])
        let targetingAttributes = try XCTUnwrap(requestSubject["targeting_attributes"] as? NSDictionary)
        let expectedAttributes = try JSONSerialization.jsonObject(with: JSONEncoder().encode(FlagsEvaluationContext(context).attributes)) as? NSDictionary
        XCTAssertEqual(targetingAttributes, expectedAttributes)
        let exposureSubject = try XCTUnwrap(exposures.first?["subject"] as? [String: Any])
        XCTAssertEqual(exposureSubject["attributes"] as? NSDictionary, expectedAttributes)
    }

    @MainActor
    func testContextRefreshesPreserveClientsAndCurrentTelemetryAfterFailure() async throws {
        let ready = expectation(description: "loopback intake ready")
        let server = try ProviderLocalIntake(ready: ready)
        server.start()
        await fulfillment(of: [ready], timeout: 5)
        defer { server.stop() }
        let instanceName = "provider-transitions-\(UUID().uuidString)"
        let core = Datadog.initialize(with: .init(clientToken: "local-intake-token", env: "local-test"), trackingConsent: .granted, instanceName: instanceName)
        defer { Datadog.internalFlushAndDeinitialize(instanceName: instanceName) }
        RUM.enable(with: .init(applicationID: UUID().uuidString, customEndpoint: try server.url("rum")), in: core)
        Flags.enable(
            with: .init(customFlagsEndpoint: try server.url("assignments"), customExposureEndpoint: try server.url("exposures"), customEvaluationEndpoint: try server.url("evaluations")),
            in: core
        )
        let provider = DatadogProvider(enableEvaluationTelemetryOptOutParameter: true, name: "controlled", core: core)
        let normal = DatadogProvider(enableEvaluationTelemetryOptOutParameter: false, name: "normal", core: core)
        let api = OpenFeatureAPI()
        defer { api.clearProvider() }
        await api.setProviderAndWait(provider: provider, initialContext: context(.boolean(false)))
        try await normal.initialize(initialContext: context(.boolean(true)))
        let client = api.getClient()
        let monitor = RUMMonitor.shared(in: core)
        monitor.startView(key: "transitions", name: "Transitions")
        XCTAssertTrue(client.getBooleanValue(key: "initial-flag", defaultValue: false))
        XCTAssertTrue(try normal.getBooleanEvaluation(key: "normal-flag", defaultValue: false, context: nil).value)

        await api.setEvaluationContextAndWait(evaluationContext: context(.boolean(true)))
        XCTAssertTrue(client.getBooleanValue(key: "hidden-flag", defaultValue: false))
        XCTAssertFalse(client.getBooleanValue(key: "missing", defaultValue: false))
        let reused = DatadogProvider(enableEvaluationTelemetryOptOutParameter: false, name: "controlled", core: core)
        XCTAssertTrue(try reused.getBooleanEvaluation(key: "hidden-flag", defaultValue: false, context: nil).value)
        await api.setEvaluationContextAndWait(evaluationContext: context(.string("true")))
        XCTAssertTrue(client.getBooleanValue(key: "string-flag", defaultValue: false))
        await api.setEvaluationContextAndWait(evaluationContext: context(.boolean(true)))
        XCTAssertEqual(server.assignmentCount, 5)

        // Repeating a complete context preserves explicit refresh behavior.
        let held = expectation(description: "assignment refresh held")
        server.holdAssignments { held.fulfill() }
        let refresh = Task { try await provider.onContextSet(oldContext: context(.boolean(true)), newContext: context(.boolean(true))) }
        await fulfillment(of: [held], timeout: 5)
        let nativeClient = FlagsClient.shared(named: "controlled", in: core)
        XCTAssertEqual(nativeClient.state.currentState, .reconciling)
        XCTAssertEqual(server.assignmentCount, 6)
        server.releaseAssignments(status: 500)
        try await refresh.value
        XCTAssertEqual(nativeClient.state.currentState, .stale)

        let changedHeld = expectation(description: "changed context refresh held")
        server.holdAssignments { changedHeld.fulfill() }
        let changedRefresh = Task { await api.setEvaluationContextAndWait(evaluationContext: context(.boolean(false))) }
        await fulfillment(of: [changedHeld], timeout: 5)
        XCTAssertEqual(nativeClient.state.currentState, .reconciling)
        let cached = client.getBooleanDetails(key: "cached-visible-flag", defaultValue: false)
        XCTAssertTrue(cached.value)
        // In-memory assignments retain their original reason while a refresh is pending.
        XCTAssertEqual(cached.reason, "TARGETING_MATCH")
        XCTAssertEqual(cached.variant, "enabled")
        server.releaseAssignments(status: 500)
        await changedRefresh.value
        XCTAssertEqual(nativeClient.state.currentState, .error)
        XCTAssertFalse(try provider.getBooleanEvaluation(key: "failed-default", defaultValue: false, context: nil).value)
        await api.setEvaluationContextAndWait(evaluationContext: context(.boolean(true)))
        XCTAssertTrue(client.getBooleanValue(key: "cached-hidden-flag", defaultValue: false))
        XCTAssertEqual(nativeClient.state.currentState, .ready)
        XCTAssertEqual(server.assignmentCount, 8)
        try XCTUnwrap(core as? DatadogCore).flush()
        monitor.addError(message: "unrelated transition error")
        monitor.stopView(key: "transitions")
        Datadog.internalFlushAndDeinitialize(instanceName: instanceName)

        let evaluations = try server.evaluations()
        let keys = evaluations.compactMap { $0["flag"] as? [String: Any] }.compactMap { $0["key"] as? String }
        let exposures = try server.events(at: "exposures")
        let rum = try server.events(at: "rum")
        print("Provider transitions: assignments=\(server.assignmentCount), exposures=\(exposures.count), evaluation keys=\(keys.sorted())")
        XCTAssertEqual(Set(keys), ["initial-flag", "normal-flag", "string-flag", "cached-visible-flag", "failed-default"])
        XCTAssertEqual(evaluations.count, 5)
        XCTAssertEqual(exposures.count, 6)
        XCTAssertFalse(rum.contains { ($0["feature_flags"] as? [String: Any])?["hidden-flag"] != nil })
        XCTAssertFalse(rum.contains { ($0["feature_flags"] as? [String: Any])?["cached-hidden-flag"] != nil })
        XCTAssertTrue(rum.contains { ($0["feature_flags"] as? [String: Any])?["cached-visible-flag"] != nil })
        XCTAssertTrue(rum.contains { $0["type"] as? String == "error" })
    }

    @MainActor
    func testLateInitialResponseDoesNotRestoreOldPolicy() async throws {
        let ready = expectation(description: "loopback intake ready")
        let server = try ProviderLocalIntake(ready: ready)
        server.start()
        await fulfillment(of: [ready], timeout: 5)
        defer { server.stop() }
        let instanceName = "provider-pending-\(UUID().uuidString)"
        let core = Datadog.initialize(with: .init(clientToken: "local-intake-token", env: "local-test"), trackingConsent: .granted, instanceName: instanceName)
        defer { Datadog.internalFlushAndDeinitialize(instanceName: instanceName) }
        Flags.enable(
            with: .init(customFlagsEndpoint: try server.url("assignments"), customExposureEndpoint: try server.url("exposures"), customEvaluationEndpoint: try server.url("evaluations")),
            in: core
        )
        let provider = DatadogProvider(enableEvaluationTelemetryOptOutParameter: true, core: core)
        let held = expectation(description: "initial assignments held")
        server.holdAssignments { held.fulfill() }
        let initialize = Task { try await provider.initialize(initialContext: context(.boolean(false))) }
        await fulfillment(of: [held], timeout: 5)
        let changedHeld = expectation(description: "opt-out refresh held")
        server.holdAssignments { changedHeld.fulfill() }
        let changeContext = Task { try await provider.onContextSet(oldContext: context(.boolean(false)), newContext: context(.boolean(true))) }
        await fulfillment(of: [changedHeld], timeout: 5)
        XCTAssertFalse(try provider.getBooleanEvaluation(key: "not-ready", defaultValue: false, context: nil).value)
        XCTAssertEqual(server.assignmentCount, 2)
        server.releaseAssignments(status: 200)
        try await initialize.value
        try await changeContext.value
        XCTAssertTrue(try provider.getBooleanEvaluation(key: "hidden-flag", defaultValue: false, context: nil).value)
        try await provider.onContextSet(oldContext: context(.boolean(true)), newContext: context(.boolean(false)))
        XCTAssertTrue(try provider.getBooleanEvaluation(key: "visible-flag", defaultValue: false, context: nil).value)
        XCTAssertEqual(server.assignmentCount, 3)
        Datadog.internalFlushAndDeinitialize(instanceName: instanceName)
        let evaluations = try server.evaluations()
        let keys = evaluations.compactMap { $0["flag"] as? [String: Any] }.compactMap { $0["key"] as? String }
        XCTAssertEqual(keys, ["visible-flag"])
        XCTAssertEqual(try server.events(at: "exposures").count, 2)
        print("Provider pending: assignments=3, exposures=2, evaluation keys=\(keys)")
    }

    private func context(_ value: Value) -> MutableContext {
        MutableContext(targetingKey: "local-user", structure: MutableStructure(attributes: ["dd_evaluation_telemetry_opt_out": value]))
    }
}

private final class CustomerHook: Hook {
    typealias HookValue = Bool
    var calls = 0

    func supportsFlagValueType(flagValueType: FlagValueType) -> Bool { true }

    func finally<HookValue>(ctx: HookContext<HookValue>, details: FlagEvaluationDetails<HookValue>, hints: [String: Any]) {
        calls += 1
    }
}

private final class ProviderLocalIntake {
    private let listener: NWListener
    private let ready: XCTestExpectation
    private let queue = DispatchQueue(label: "provider-local-intake")
    private var connections: [NWConnection] = []
    private var received: [URLRequest] = []
    private var onHeldAssignment: (() -> Void)?
    private var heldAssignments: [(NWConnection, URLRequest)] = []

    var requests: [URLRequest] { queue.sync { received } }
    var assignmentCount: Int { requests.filter { $0.url?.path == "/assignments" }.count }

    init(ready: XCTestExpectation) throws {
        self.ready = ready
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        listener = try NWListener(using: parameters)
    }

    func start() {
        listener.stateUpdateHandler = { [weak self] state in
            if case .ready = state { self?.ready.fulfill() }
            if case .failed(let error) = state { XCTFail("Local intake failed: \(error)") }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else {
                connection.cancel()
                return
            }
            connections.append(connection)
            connection.start(queue: queue)
            receive(connection, buffered: Data())
        }
        listener.start(queue: queue)
    }

    func stop() {
        queue.sync {
            connections.forEach { $0.cancel() }
            connections.removeAll()
            listener.cancel()
        }
    }

    func url(_ path: String) throws -> URL {
        let port = try XCTUnwrap(listener.port)
        return try XCTUnwrap(URL(string: "http://127.0.0.1:\(port.rawValue)/\(path)"))
    }

    func evaluations() throws -> [[String: Any]] {
        try events(at: "evaluations").flatMap { $0["flagEvaluations"] as? [[String: Any]] ?? [] }
    }

    func events(at path: String) throws -> [[String: Any]] {
        try requests.filter { $0.url?.path == "/\(path)" }.flatMap { request in
            var body = try XCTUnwrap(request.httpBody)
            if request.value(forHTTPHeaderField: "Content-Encoding") == "deflate" {
                guard body.count > 6 else { throw IntakeError.invalidCompression }
                let compressed = body.subdata(in: 2..<(body.count - 4))
                body = try compressed.withUnsafeBytes { source in
                    let pointer = try XCTUnwrap(source.bindMemory(to: UInt8.self).baseAddress)
                    let capacity = 1_048_576
                    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
                    defer { buffer.deallocate() }
                    let count = compression_decode_buffer(buffer, capacity, pointer, compressed.count, nil, COMPRESSION_ZLIB)
                    guard count > 0, count < capacity else { throw IntakeError.invalidCompression }
                    return Data(bytes: buffer, count: count)
                }
            }
            return try body.split(separator: 0x0A).map { line in
                try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line)) as? [String: Any])
            }
        }
    }

    func holdAssignments(onRequest: @escaping () -> Void) {
        queue.sync { onHeldAssignment = onRequest }
    }

    func releaseAssignments(status: Int) {
        queue.sync {
            onHeldAssignment = nil
            for (connection, request) in heldAssignments { respond(connection, request: request, status: status) }
            heldAssignments.removeAll()
        }
    }

    private func respond(_ connection: NWConnection, request: URLRequest, status: Int = 200) {
        let assignment: [String: Any] = [
            "allocationKey": "allocation", "variationKey": "enabled", "variationType": "boolean",
            "variationValue": true, "reason": "TARGETING_MATCH", "doLog": true,
        ]
        do {
            let keys = ["local-flag", "initial-flag", "normal-flag", "hidden-flag", "visible-flag", "string-flag", "cached-visible-flag", "cached-hidden-flag"]
            var flags = Dictionary(uniqueKeysWithValues: keys.map { ($0, assignment) })
            let body: Data
            if request.url?.path == "/assignments" {
                let requestJSON = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
                let data = requestJSON?["data"] as? [String: Any]
                let attributes = data?["attributes"] as? [String: Any]
                let subject = attributes?["subject"] as? [String: Any]
                let targetingAttributes = subject?["targeting_attributes"] as? [String: Any]
                let target = targetingAttributes?["dd_evaluation_telemetry_opt_out"] as? Bool ?? false
                flags["targeting-flag"] = [
                    "allocationKey": "targeted-allocation", "variationKey": String(target), "variationType": "boolean",
                    "variationValue": target, "reason": "TARGETING_MATCH", "doLog": true,
                ]
                body = try JSONSerialization.data(withJSONObject: ["data": ["attributes": ["flags": flags]]])
            } else {
                body = Data("{}".utf8)
            }
            let response = "HTTP/1.1 \(status) Response\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
            connection.send(content: Data(response.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
        } catch {
            XCTFail("Local intake could not encode assignments: \(error)")
            connection.cancel()
        }
    }

    private func receive(_ connection: NWConnection, buffered: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, complete, error in
            guard let self else {
                return
            }
            let bytes = buffered + (data ?? Data())
            guard let separator = bytes.range(of: Data("\r\n\r\n".utf8)) else {
                if !complete && error == nil { receive(connection, buffered: bytes) }
                return
            }
            let headers = String(decoding: bytes[..<separator.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
            let length = headers.first { $0.lowercased().hasPrefix("content-length:") }
                .flatMap { Int($0.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)) } ?? 0
            guard bytes.count >= separator.upperBound + length else {
                if !complete && error == nil { receive(connection, buffered: bytes) }
                return
            }
            do {
                let path = try XCTUnwrap(headers.first?.split(separator: " ").dropFirst().first)
                var request = URLRequest(url: try url(String(path.dropFirst())))
                request.httpBody = bytes.subdata(in: separator.upperBound..<(separator.upperBound + length))
                for header in headers.dropFirst() {
                    let pieces = header.split(separator: ":", maxSplits: 1).map(String.init)
                    if pieces.count == 2 { request.setValue(pieces[1].trimmingCharacters(in: .whitespaces), forHTTPHeaderField: pieces[0]) }
                }
                received.append(request)
                let isAssignment = request.url?.path == "/assignments"
                if isAssignment, let onHeldAssignment {
                    heldAssignments.append((connection, request))
                    onHeldAssignment()
                } else {
                    respond(connection, request: request)
                }
            } catch {
                XCTFail("Local intake could not process request: \(error)")
                connection.cancel()
            }
        }
    }

    private enum IntakeError: Error { case invalidCompression }
}
