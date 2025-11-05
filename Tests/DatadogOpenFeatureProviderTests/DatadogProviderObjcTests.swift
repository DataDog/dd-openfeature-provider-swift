/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

import XCTest
@_spi(objc)
@testable import DatadogOpenFeatureProvider

final class DatadogProviderObjcTests: XCTestCase {
    
    func testInitialization() {
        let provider = objc_DatadogProvider()
        XCTAssertNotNil(provider)
    }
    
    func testInitializationWithName() {
        let provider = objc_DatadogProvider(name: "test-provider")
        XCTAssertNotNil(provider)
    }
    
    func testBooleanEvaluation() throws {
        let provider = objc_DatadogProvider()
        
        let result = try provider.getBooleanValue(
            key: "test-flag",
            defaultValue: false,
            context: ["userId": "123"]
        )
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result.value, false) // Default value when flag doesn't exist
        XCTAssertEqual(result.reason, "DEFAULT")
    }
    
    func testStringEvaluation() throws {
        let provider = objc_DatadogProvider()
        
        let result = try provider.getStringValue(
            key: "test-flag",
            defaultValue: "default",
            context: ["userId": "123"]
        )
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result.value, "default")
        XCTAssertEqual(result.reason, "DEFAULT")
    }
    
    func testIntegerEvaluation() throws {
        let provider = objc_DatadogProvider()
        
        let result = try provider.getIntegerValue(
            key: "test-flag",
            defaultValue: 42,
            context: ["userId": "123"]
        )
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result.value, 42)
        XCTAssertEqual(result.reason, "DEFAULT")
    }
    
    func testDoubleEvaluation() throws {
        let provider = objc_DatadogProvider()
        
        let result = try provider.getDoubleValue(
            key: "test-flag",
            defaultValue: 3.14,
            context: ["userId": "123"]
        )
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result.value, 3.14)
        XCTAssertEqual(result.reason, "DEFAULT")
    }
    
    func testObjectEvaluation() throws {
        let provider = objc_DatadogProvider()
        
        let defaultValue: [String: Any] = [
            "key1": "value1",
            "key2": 42,
            "key3": true
        ]
        
        let result = try provider.getObjectValue(
            key: "test-flag",
            defaultValue: defaultValue,
            context: ["userId": "123"]
        )
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result.reason, "DEFAULT")
        
        // Verify the object contains expected keys
        XCTAssertNotNil(result.value["key1"])
        XCTAssertNotNil(result.value["key2"])
        XCTAssertNotNil(result.value["key3"])
    }
    
    func testAsyncInitialization() {
        let provider = objc_DatadogProvider()
        let expectation = self.expectation(description: "Initialization completes")
        
        provider.initialize(initialContext: ["userId": "123"]) { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    func testAsyncContextUpdate() {
        let provider = objc_DatadogProvider()
        let expectation = self.expectation(description: "Context update completes")
        
        let oldContext = ["userId": "123"]
        let newContext = ["userId": "456", "sessionId": "abc"]
        
        provider.setContext(oldContext: oldContext, newContext: newContext) { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }
}
