/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

import XCTest
import Network
import OpenFeature
import DatadogFlags
@testable import DatadogCore
@testable import DatadogOpenFeatureProvider

/// Runs the actual OpenFeature provider and native HTTP client against a loopback endpoint.
final class ExperimentationOptOutHTTPTests: XCTestCase {
    @MainActor
    func testImmediateModeRequestsAndReturnsOrdinaryAssignment() async throws {
        try await withProvider(mode: .immediate) { provider, api, endpoint in
            for timestamp in ["2026-10-21T10:00:00Z", "2099-01-01T12:00:00.123+03:00"] {
                await api.setProviderAndWait(provider: provider, initialContext: self.context(.string(timestamp)))
                let result = api.getClient().getBooleanDetails(key: "feature", defaultValue: false)

                XCTAssertEqual(api.getProviderStatus(), .ready)
                XCTAssertFalse(result.value)
                XCTAssertEqual(result.variant, "ordinary")
                XCTAssertNil(result.errorCode)
                let attributes = try self.attributes(in: XCTUnwrap(endpoint.requests.last))
                XCTAssertEqual((attributes["evaluation_options"] as? [String: Any])?["experimentation_opt_out"] as? Bool, true)
                let subject = try XCTUnwrap(attributes["subject"] as? [String: Any])
                XCTAssertEqual(subject["targeting_key"] as? String, "subject")
                XCTAssertEqual((subject["targeting_attributes"] as? [String: Any])?["dd_experimentation_opt_out_at"] as? String, timestamp)
            }
        }
    }

    @MainActor
    func testDisabledAndAbsentAttributeKeepOrdinaryEvaluation() async throws {
        for mode: FlagsClient.ExperimentationOptOutMode? in [nil, .disabled, .immediate] {
            try await withProvider(mode: mode) { provider, api, endpoint in
                let value: Value? = mode == .immediate ? nil : .boolean(true)
                await api.setProviderAndWait(provider: provider, initialContext: self.context(value))
                let result = api.getClient().getBooleanDetails(key: "feature", defaultValue: false)
                XCTAssertTrue(result.value)
                XCTAssertEqual(result.variant, "treatment")
                XCTAssertNil(result.errorCode)
                let attributes = try self.attributes(in: XCTUnwrap(endpoint.requests.last))
                XCTAssertNotEqual((attributes["evaluation_options"] as? [String: Any])?["experimentation_opt_out"] as? Bool, true)
            }
        }
    }

    @MainActor
    func testInvalidValuesClearPriorAssignmentsWithoutHTTP() async throws {
        try await withProvider(mode: .immediate) { provider, api, endpoint in
            await api.setProviderAndWait(provider: provider, initialContext: self.context(nil))
            XCTAssertTrue(api.getClient().getBooleanValue(key: "feature", defaultValue: false))
            let invalidValues: [Value] = [.null, .boolean(true), .integer(1), .string(""), .string("invalid"), .date(Date())]
            for value in invalidValues {
                let count = endpoint.requests.count
                do {
                    try await provider.onContextSet(oldContext: nil, newContext: self.context(value))
                    XCTFail("Invalid opt-out value must fail the context update")
                } catch {
                    XCTAssertEqual(error as? OpenFeatureError, .invalidContextError)
                }
                XCTAssertEqual(endpoint.requests.count, count)
                let evaluations: [() throws -> Void] = [
                    { _ = try provider.getBooleanEvaluation(key: "feature", defaultValue: false, context: nil) },
                    { _ = try provider.getStringEvaluation(key: "feature", defaultValue: "default", context: nil) },
                    { _ = try provider.getIntegerEvaluation(key: "feature", defaultValue: 0, context: nil) },
                    { _ = try provider.getDoubleEvaluation(key: "feature", defaultValue: 0, context: nil) },
                    { _ = try provider.getObjectEvaluation(key: "feature", defaultValue: .null, context: nil) },
                ]
                for evaluate in evaluations {
                    XCTAssertThrowsError(try evaluate()) { XCTAssertEqual($0 as? OpenFeatureError, .invalidContextError) }
                }
                // OpenFeature 0.3.1 reports GENERAL for an ERROR provider before calling a getter.
                XCTAssertFalse(api.getClient().getBooleanValue(key: "feature", defaultValue: false))
            }
            try await provider.onContextSet(oldContext: nil, newContext: self.context(nil))
            XCTAssertTrue(try provider.getBooleanEvaluation(key: "feature", defaultValue: false, context: nil).value)
        }
    }

    @MainActor
    func testUnacknowledgedResponseCannotReuseEligibleAssignments() async throws {
        try await withProvider(mode: .immediate) { provider, api, endpoint in
            await api.setProviderAndWait(provider: provider, initialContext: self.context(nil))
            XCTAssertTrue(api.getClient().getBooleanValue(key: "feature", defaultValue: false))
            endpoint.acknowledgesOptOut = false
            await api.setEvaluationContextAndWait(evaluationContext: self.context(.string("2026-10-21T10:00:00Z")))
            let result = api.getClient().getBooleanDetails(key: "feature", defaultValue: false)
            XCTAssertFalse(result.value)
            XCTAssertNil(result.variant)
            XCTAssertNotNil(result.errorCode)
            XCTAssertFalse(try provider.getBooleanEvaluation(key: "feature", defaultValue: false, context: nil).value)
        }
    }

    private func context(_ value: Value?) -> EvaluationContext {
        var attributes: [String: Value] = [:]
        attributes["dd_experimentation_opt_out_at"] = value
        return MutableContext(targetingKey: "subject", structure: MutableStructure(attributes: attributes))
    }

    private func attributes(in request: [String: Any]) throws -> [String: Any] {
        try XCTUnwrap((request["data"] as? [String: Any])?["attributes"] as? [String: Any])
    }

    @MainActor
    private func withProvider(
        mode: FlagsClient.ExperimentationOptOutMode?,
        body: (DatadogProvider, OpenFeatureAPI, OptOutEndpoint) async throws -> Void
    ) async throws {
        let ready = expectation(description: "assignment endpoint ready")
        let endpoint = try OptOutEndpoint(ready: ready)
        endpoint.start()
        await fulfillment(of: [ready], timeout: 5)
        defer { endpoint.stop() }
        let instanceName = "opt-out-\(UUID().uuidString)"
        let core = Datadog.initialize(
            with: .init(clientToken: "local-token", env: "test"),
            trackingConsent: .notGranted,
            instanceName: instanceName
        )
        defer { Datadog.internalFlushAndDeinitialize(instanceName: instanceName) }
        Flags.enable(with: .init(customFlagsEndpoint: try endpoint.url()), in: core)
        let provider = mode.map { DatadogProvider(experimentationOptOutMode: $0, core: core) } ?? DatadogProvider(core: core)
        let api = OpenFeatureAPI()
        defer { api.clearProvider() }
        try await body(provider, api, endpoint)
    }
}

private final class OptOutEndpoint {
    private let listener: NWListener
    private let ready: XCTestExpectation
    private let queue = DispatchQueue(label: "experimentation-opt-out-http")
    private var connections: [NWConnection] = []
    private var received: [[String: Any]] = []
    private var acknowledgement = true

    var requests: [[String: Any]] { queue.sync { received } }
    var acknowledgesOptOut: Bool {
        get { queue.sync { acknowledgement } }
        set { queue.sync { acknowledgement = newValue } }
    }

    init(ready: XCTestExpectation) throws {
        self.ready = ready
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        listener = try NWListener(using: parameters)
    }

    func url() throws -> URL {
        let port = try XCTUnwrap(listener.port)
        return try XCTUnwrap(URL(string: "http://127.0.0.1:\(port.rawValue)/assignments"))
    }

    func start() {
        listener.stateUpdateHandler = { [weak self] state in
            if case .ready = state { self?.ready.fulfill() }
            if case .failed(let error) = state { XCTFail("Endpoint failed: \(error)") }
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
            listener.cancel()
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
                let body = bytes.subdata(in: separator.upperBound..<(separator.upperBound + length))
                let request = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                received.append(request)
                let attributes = (request["data"] as? [String: Any])?["attributes"] as? [String: Any]
                let optedOut = acknowledgement && (attributes?["evaluation_options"] as? [String: Any])?["experimentation_opt_out"] as? Bool == true
                let assignment: [String: Any] = [
                    "allocationKey": optedOut ? "ordinary" : "experiment",
                    "variationKey": optedOut ? "ordinary" : "treatment",
                    "variationType": "boolean", "variationValue": !optedOut,
                    "reason": "TARGETING_MATCH", "doLog": !optedOut,
                ]
                let responseBody = try JSONSerialization.data(withJSONObject: [
                    "data": [
                        "attributes": [
                            "flags": ["feature": assignment],
                            "evaluation_options": ["experimentation_opt_out": optedOut],
                        ],
                    ],
                ])
                let response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(responseBody.count)\r\nConnection: close\r\n\r\n"
                connection.send(content: Data(response.utf8) + responseBody, completion: .contentProcessed { _ in connection.cancel() })
            } catch {
                XCTFail("Endpoint could not process request: \(error)")
                connection.cancel()
            }
        }
    }
}
