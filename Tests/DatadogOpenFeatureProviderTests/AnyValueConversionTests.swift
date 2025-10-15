/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

import Testing
import Foundation
import OpenFeature
import DatadogFlags
@testable import DatadogOpenFeatureProvider

// MARK: - AnyValue Conversion Tests (DatadogFlags → OpenFeature)

@Suite("AnyValue to Value Conversion")
struct AnyValueToValueTests {
    
    @Test("Primitive type conversions")
    func primitiveConversions() async throws {
        // Given
        let boolAnyValue = AnyValue.bool(true)
        let stringAnyValue = AnyValue.string("test")
        let intAnyValue = AnyValue.int(42)
        let doubleAnyValue = AnyValue.double(3.14)
        let nullAnyValue = AnyValue.null
        
        // When
        let boolValue = Value(boolAnyValue)
        let stringValue = Value(stringAnyValue)
        let intValue = Value(intAnyValue)
        let doubleValue = Value(doubleAnyValue)
        let nullValue = Value(nullAnyValue)
        
        // Then
        #expect(boolValue == .boolean(true))
        #expect(stringValue == .string("test"))
        #expect(intValue == .integer(42))
        #expect(doubleValue == .double(3.14))
        #expect(nullValue == .null)
    }

    @Test("Complex structure conversions")
    func complexStructureConversions() async throws {
        // Given
        let dictAnyValue = AnyValue.dictionary([
            "name": AnyValue.string("John"),
            "age": AnyValue.int(30),
            "active": AnyValue.bool(true)
        ])
        
        // When
        let dictValue = Value(dictAnyValue)
        
        // Then
        if case .structure(let structure) = dictValue {
            #expect(structure["name"] == .string("John"))
            #expect(structure["age"] == .integer(30))
            #expect(structure["active"] == .boolean(true))
        } else {
            #expect(Bool(false), "Expected structure value")
        }
    }

    @Test("Array conversions")
    func arrayConversions() async throws {
        // Test array conversion
        let arrayAnyValue = AnyValue.array([
            AnyValue.string("item1"),
            AnyValue.int(42),
            AnyValue.bool(false)
        ])
        let arrayValue = Value(arrayAnyValue)
        
        if case .list(let list) = arrayValue {
            #expect(list.count == 3)
            #expect(list[0] == .string("item1"))
            #expect(list[1] == .integer(42))
            #expect(list[2] == .boolean(false))
        } else {
            #expect(Bool(false), "Expected list value")
        }
    }

    @Test("Nested structure conversions")
    func nestedStructureConversions() async throws {
        // Test nested dictionary conversion
        let nestedAnyValue = AnyValue.dictionary([
            "user": AnyValue.dictionary([
                "id": AnyValue.int(123),
                "profile": AnyValue.dictionary([
                    "name": AnyValue.string("Alice"),
                    "verified": AnyValue.bool(true)
                ])
            ]),
            "tags": AnyValue.array([
                AnyValue.string("premium"),
                AnyValue.string("beta")
            ])
        ])
        
        let nestedValue = Value(nestedAnyValue)
        
        if case .structure(let structure) = nestedValue {
            if case .structure(let user) = structure["user"] {
                #expect(user["id"] == .integer(123))
                if case .structure(let profile) = user["profile"] {
                    #expect(profile["name"] == .string("Alice"))
                    #expect(profile["verified"] == .boolean(true))
                } else {
                    #expect(Bool(false), "Expected profile structure")
                }
            } else {
                #expect(Bool(false), "Expected user structure")
            }
            
            if case .list(let tags) = structure["tags"] {
                #expect(tags.count == 2)
                #expect(tags[0] == .string("premium"))
                #expect(tags[1] == .string("beta"))
            } else {
                #expect(Bool(false), "Expected tags list")
            }
        } else {
            #expect(Bool(false), "Expected structure value")
        }
    }
}

@Suite("AnyValue Fallback Behavior")
struct AnyValueFallbackTests {
    
    @Test("Unsupported type fallback to string")
    func fallbackConversion() async throws {
        // Test conversion of unsupported types falls back to string description
        struct CustomType {
            let value: String
        }
        
        let customValue = CustomType(value: "test")
        let anyValue = AnyValue(customValue)
        
        // Should fall back to string description
        if case .string(let description) = anyValue {
            #expect(description.contains("CustomType"))
            #expect(description.contains("test"))
        } else {
            #expect(Bool(false), "Expected string fallback")
        }
    }
}
