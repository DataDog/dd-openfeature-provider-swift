import Testing
import Foundation
import OpenFeature
import DatadogFlags
@testable import DatadogOpenFeatureProvider

// MARK: - Value Conversion Tests (OpenFeature → DatadogFlags)

@Test func testValueToAnyValuePrimitives() async throws {
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

@Test func testValueToAnyValueComplexStructures() async throws {
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

@Test func testValueToAnyValueArrays() async throws {
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

@Test func testValueToAnyValueNestedStructures() async throws {
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

@Test func testValueDateConversionThrowsError() async throws {
    // Given
    let dateValue = Value.date(Date())
    
    // When & Then
    #expect(throws: OpenFeatureError.valueNotConvertableError) {
        _ = try AnyValue(dateValue)
    }
}

@Test func testValueToAnyConversion() async throws {
    // Test all types converting to Swift Any
    let boolValue = Value.boolean(true)
    let boolAny = boolValue.toAny()
    #expect(boolAny as? Bool == true)
    
    let stringValue = Value.string("test")
    let stringAny = stringValue.toAny()
    #expect(stringAny as? String == "test")
    
    let intValue = Value.integer(42)
    let intAny = intValue.toAny()
    #expect(intAny as? Int64 == 42)
    
    let doubleValue = Value.double(3.14159)
    let doubleAny = doubleValue.toAny()
    #expect(doubleAny as? Double == 3.14159)
    
    let dateValue = Value.date(Date(timeIntervalSince1970: 1609459200)) // 2021-01-01
    let dateAny = dateValue.toAny()
    #expect(dateAny is Date)
    
    let nullValue = Value.null
    let nullAny = nullValue.toAny()
    #expect(nullAny is NSNull)
    
    // Test structure conversion
    let structValue = Value.structure([
        "key": Value.string("value"),
        "num": Value.integer(123)
    ])
    let structAny = structValue.toAny()
    let dict = structAny as? [String: Any]
    #expect(dict?["key"] as? String == "value")
    #expect(dict?["num"] as? Int64 == 123)
    
    // Test list conversion
    let listValue = Value.list([
        Value.string("item"),
        Value.integer(456)
    ])
    let listAny = listValue.toAny()
    let array = listAny as? [Any]
    #expect(array?.count == 2)
    #expect(array?[0] as? String == "item")
    #expect(array?[1] as? Int64 == 456)
}

@Test func testValueToStringConversion() async throws {
    // Test string representation of all types
    let boolValue = Value.boolean(true)
    #expect(boolValue.toString() == "true")
    
    let stringValue = Value.string("hello world")
    #expect(stringValue.toString() == "hello world")
    
    let intValue = Value.integer(42)
    #expect(intValue.toString() == "42")
    
    let doubleValue = Value.double(3.14159)
    #expect(doubleValue.toString() == "3.14159")
    
    let nullValue = Value.null
    #expect(nullValue.toString() == "")
    
    let dateValue = Value.date(Date(timeIntervalSince1970: 1609459200))
    let dateString = dateValue.toString()
    #expect(dateString.contains("2021")) // Should contain year
    
    // Test structure to JSON string conversion
    let structValue = Value.structure([
        "name": Value.string("test"),
        "count": Value.integer(5)
    ])
    let structString = structValue.toString()
    #expect(structString.contains("name"))
    #expect(structString.contains("test"))
    #expect(structString.contains("count"))
    #expect(structString.contains("5"))
    
    // Test list to JSON string conversion
    let listValue = Value.list([
        Value.string("item1"),
        Value.string("item2")
    ])
    let listString = listValue.toString()
    #expect(listString.contains("item1"))
    #expect(listString.contains("item2"))
}

@Test func testRoundTripConversions() async throws {
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