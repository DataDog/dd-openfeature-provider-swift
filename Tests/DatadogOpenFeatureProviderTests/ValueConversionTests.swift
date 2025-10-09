import Testing
import Foundation
import OpenFeature
import DatadogFlags
@testable import DatadogOpenFeatureProvider

// MARK: - Value Conversion Tests (OpenFeature → DatadogFlags)

@Suite("Value to AnyValue Conversion")
struct ValueToAnyValueTests {
    
    @Test("Primitive type conversions")
    func primitiveConversions() async throws {
        // Given
        let boolValue = Value.boolean(true)
        let stringValue = Value.string("test")
        let intValue = Value.integer(42)
        let doubleValue = Value.double(3.14)
        let nullValue = Value.null
        
        // When
        let boolAnyValue = try AnyValue(boolValue)
        let stringAnyValue = try AnyValue(stringValue)
        let intAnyValue = try AnyValue(intValue)
        let doubleAnyValue = try AnyValue(doubleValue)
        let nullAnyValue = try AnyValue(nullValue)
        
        // Then
        #expect(boolAnyValue == .bool(true))
        #expect(stringAnyValue == .string("test"))
        #expect(intAnyValue == .int(42))
        #expect(doubleAnyValue == .double(3.14))
        #expect(nullAnyValue == .null)
    }

    @Test("Complex structure conversions")
    func complexStructureConversions() async throws {
        // Test structure conversion
        let structValue = Value.structure([
            "name": Value.string("Alice"),
            "age": Value.integer(25),
            "active": Value.boolean(true),
            "score": Value.double(95.5)
        ])
        
        let structAnyValue = try AnyValue(structValue)
        
        if case .dictionary(let dict) = structAnyValue {
            #expect(dict["name"] == .string("Alice"))
            #expect(dict["age"] == .int(25))
            #expect(dict["active"] == .bool(true))
            #expect(dict["score"] == .double(95.5))
        } else {
            #expect(Bool(false), "Expected dictionary")
        }
    }

    @Test("Array conversions")
    func arrayConversions() async throws {
        // Test list conversion
        let listValue = Value.list([
            Value.string("first"),
            Value.integer(123),
            Value.boolean(false),
            Value.double(2.718)
        ])
        
        let listAnyValue = try AnyValue(listValue)
        
        if case .array(let array) = listAnyValue {
            #expect(array.count == 4)
            #expect(array[0] == .string("first"))
            #expect(array[1] == .int(123))
            #expect(array[2] == .bool(false))
            #expect(array[3] == .double(2.718))
        } else {
            #expect(Bool(false), "Expected array")
        }
    }

    @Test("Nested structure conversions")
    func nestedStructureConversions() async throws {
        // Test nested structure conversion
        let nestedValue = Value.structure([
            "user": Value.structure([
                "id": Value.integer(999),
                "details": Value.structure([
                    "firstName": Value.string("Bob"),
                    "isAdmin": Value.boolean(true)
                ])
            ]),
            "preferences": Value.list([
                Value.string("notifications"),
                Value.string("darkMode")
            ])
        ])
        
        let nestedAnyValue = try AnyValue(nestedValue)
        
        if case .dictionary(let dict) = nestedAnyValue {
            if case .dictionary(let user) = dict["user"] {
                #expect(user["id"] == .int(999))
                if case .dictionary(let details) = user["details"] {
                    #expect(details["firstName"] == .string("Bob"))
                    #expect(details["isAdmin"] == .bool(true))
                } else {
                    #expect(Bool(false), "Expected details dictionary")
                }
            } else {
                #expect(Bool(false), "Expected user dictionary")
            }
            
            if case .array(let preferences) = dict["preferences"] {
                #expect(preferences.count == 2)
                #expect(preferences[0] == .string("notifications"))
                #expect(preferences[1] == .string("darkMode"))
            } else {
                #expect(Bool(false), "Expected preferences array")
            }
        } else {
            #expect(Bool(false), "Expected dictionary")
        }
    }

    @Test("Date conversion throws error")
    func dateConversionThrowsError() async throws {
        // Given
        let dateValue = Value.date(Date())
        
        // When & Then
        #expect(throws: OpenFeatureError.valueNotConvertableError) {
            _ = try AnyValue(dateValue)
        }
    }
}



@Suite("Round-trip Conversions")
struct RoundTripConversionTests {
    
    @Test("AnyValue to Value and back")
    func roundTripConversions() async throws {
        // Test AnyValue → Value → AnyValue round-trip
        let originalAnyValue = AnyValue.dictionary([
            "string": AnyValue.string("test"),
            "number": AnyValue.int(42),
            "boolean": AnyValue.bool(true),
            "nested": AnyValue.dictionary([
                "inner": AnyValue.string("value")
            ]),
            "array": AnyValue.array([
                AnyValue.string("a"),
                AnyValue.string("b")
            ])
        ])
        
        // Convert to Value and back
        let value = Value(originalAnyValue)
        let roundTripAnyValue = try AnyValue(value)
        
        if case .dictionary(let original) = originalAnyValue,
           case .dictionary(let roundTrip) = roundTripAnyValue {
            #expect(original["string"] == roundTrip["string"])
            #expect(original["number"] == roundTrip["number"])
            #expect(original["boolean"] == roundTrip["boolean"])
            
            // Check nested structure
            if case .dictionary(let originalNested) = original["nested"],
               case .dictionary(let roundTripNested) = roundTrip["nested"] {
                #expect(originalNested["inner"] == roundTripNested["inner"])
            } else {
                #expect(Bool(false), "Nested structure lost in round-trip")
            }
            
            // Check array
            if case .array(let originalArray) = original["array"],
               case .array(let roundTripArray) = roundTrip["array"] {
                #expect(originalArray.count == roundTripArray.count)
                #expect(originalArray[0] == roundTripArray[0])
                #expect(originalArray[1] == roundTripArray[1])
            } else {
                #expect(Bool(false), "Array lost in round-trip")
            }
        } else {
            #expect(Bool(false), "Round-trip conversion failed")
        }
    }
}
