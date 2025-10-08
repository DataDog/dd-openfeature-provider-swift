import Testing
import Foundation
import OpenFeature
import DatadogFlags
@testable import DatadogOpenFeatureProvider

// MARK: - Context Conversion Tests (OpenFeature → DatadogFlags)

@Test func testBasicContextConversion() async throws {
    // Given
    let context = ImmutableContext(
        targetingKey: "user123",
        structure: ImmutableStructure(attributes: [
            "email": Value.string("test@example.com"),
            "age": Value.integer(25)
        ])
    )
    
    // When
    let flagsContext = FlagsEvaluationContext(context)
    
    // Then
    #expect(flagsContext.targetingKey == "user123")
    #expect(flagsContext.attributes["email"] == AnyValue.string("test@example.com"))
    #expect(flagsContext.attributes["age"] == AnyValue.int(25)) // Preserved as integer
}

@Test func testContextWithNoTargetingKey() async throws {
    let context = ImmutableContext(
        structure: ImmutableStructure(attributes: [
            "region": Value.string("us-west-2"),
            "plan": Value.string("premium")
        ])
    )
    
    let flagsContext = FlagsEvaluationContext(context)
    
    #expect(flagsContext.targetingKey == "")
    #expect(flagsContext.attributes["region"] == AnyValue.string("us-west-2"))
    #expect(flagsContext.attributes["plan"] == AnyValue.string("premium"))
}

@Test func testContextWithEmptyAttributes() async throws {
    let context = ImmutableContext(
        targetingKey: "user456",
        structure: ImmutableStructure(attributes: [:])
    )
    
    let flagsContext = FlagsEvaluationContext(context)
    
    #expect(flagsContext.targetingKey == "user456")
    #expect(flagsContext.attributes.isEmpty)
}

@Test func testContextWithComplexAttributeTypes() async throws {
    let context = ImmutableContext(
        targetingKey: "user789",
        structure: ImmutableStructure(attributes: [
            "string": Value.string("text"),
            "integer": Value.integer(42),
            "double": Value.double(3.14),
            "boolean": Value.boolean(true),
            "date": Value.date(Date(timeIntervalSince1970: 1609459200)), // 2021-01-01
            "null": Value.null,
            "structure": Value.structure([
                "nested": Value.string("value"),
                "count": Value.integer(10)
            ]),
            "list": Value.list([
                Value.string("item1"),
                Value.string("item2")
            ])
        ])
    )
    
    let flagsContext = FlagsEvaluationContext(context)
    
    #expect(flagsContext.targetingKey == "user789")
    
    // All values should be preserved with their original types
    #expect(flagsContext.attributes["string"] == AnyValue.string("text"))
    #expect(flagsContext.attributes["integer"] == AnyValue.int(42))
    #expect(flagsContext.attributes["double"] == AnyValue.double(3.14))
    #expect(flagsContext.attributes["boolean"] == AnyValue.bool(true))
    #expect(flagsContext.attributes["null"] == AnyValue.null)
    
    // Date should be converted to string representation (fallback)
    let dateValue = flagsContext.attributes["date"]
    #expect(dateValue != nil)
    if case .string(let dateString) = dateValue! {
        #expect(dateString.contains("2021"))
    }
    
    // Complex types should be preserved as dictionaries
    let structureValue = flagsContext.attributes["structure"]
    #expect(structureValue != nil)
    if case .dictionary(let dict) = structureValue! {
        #expect(dict["nested"] == AnyValue.string("value"))
        #expect(dict["count"] == AnyValue.int(10))
    }
    
    // Arrays should be preserved as arrays
    let listValue = flagsContext.attributes["list"]
    #expect(listValue != nil)
    if case .array(let array) = listValue! {
        #expect(array.count == 2)
        #expect(array[0] == AnyValue.string("item1"))
        #expect(array[1] == AnyValue.string("item2"))
    }
}

@Test func testContextWithSpecialCharacters() async throws {
    let context = ImmutableContext(
        targetingKey: "user-special_123",
        structure: ImmutableStructure(attributes: [
            "email": Value.string("user+test@example.com"),
            "name": Value.string("José María"),
            "description": Value.string("Line 1\nLine 2\tTabbed"),
            "json": Value.string("{\"key\": \"value\"}")
        ])
    )
    
    let flagsContext = FlagsEvaluationContext(context)
    
    #expect(flagsContext.targetingKey == "user-special_123")
    #expect(flagsContext.attributes["email"] == AnyValue.string("user+test@example.com"))
    #expect(flagsContext.attributes["name"] == AnyValue.string("José María"))
    #expect(flagsContext.attributes["description"] == AnyValue.string("Line 1\nLine 2\tTabbed"))
    #expect(flagsContext.attributes["json"] == AnyValue.string("{\"key\": \"value\"}"))
}

@Test func testContextWithLargeNumbers() async throws {
    let context = ImmutableContext(
        targetingKey: "user_numbers",
        structure: ImmutableStructure(attributes: [
            "maxInt64": Value.integer(Int64.max),
            "minInt64": Value.integer(Int64.min),
            "largeDouble": Value.double(Double.greatestFiniteMagnitude),
            "smallDouble": Value.double(Double.leastNonzeroMagnitude),
            "negativeDouble": Value.double(-999.999),
            "zero": Value.integer(0)
        ])
    )
    
    let flagsContext = FlagsEvaluationContext(context)
    
    #expect(flagsContext.targetingKey == "user_numbers")
    #expect(flagsContext.attributes["maxInt64"] == AnyValue.int(Int(Int64.max)))
    #expect(flagsContext.attributes["minInt64"] == AnyValue.int(Int(Int64.min)))
    #expect(flagsContext.attributes["zero"] == AnyValue.int(0))
    
    // Check that large/small doubles are preserved as doubles
    #expect(flagsContext.attributes["largeDouble"] == AnyValue.double(Double.greatestFiniteMagnitude))
    #expect(flagsContext.attributes["smallDouble"] == AnyValue.double(Double.leastNonzeroMagnitude))
    #expect(flagsContext.attributes["negativeDouble"] == AnyValue.double(-999.999))
}

@Test func testContextAttributeEdgeCases() async throws {
    let context = ImmutableContext(
        targetingKey: "edge_cases",
        structure: ImmutableStructure(attributes: [
            "empty_string": Value.string(""),
            "whitespace": Value.string("   "),
            "newlines": Value.string("\n\n\n"),
            "unicode": Value.string("🎉 Hello 世界 🌍"),
            "very_long": Value.string(String(repeating: "x", count: 1000))
        ])
    )
    
    let flagsContext = FlagsEvaluationContext(context)
    
    #expect(flagsContext.targetingKey == "edge_cases")
    #expect(flagsContext.attributes["empty_string"] == AnyValue.string(""))
    #expect(flagsContext.attributes["whitespace"] == AnyValue.string("   "))
    #expect(flagsContext.attributes["newlines"] == AnyValue.string("\n\n\n"))
    #expect(flagsContext.attributes["unicode"] == AnyValue.string("🎉 Hello 世界 🌍"))
    if case .string(let longString) = flagsContext.attributes["very_long"]! {
        #expect(longString.count == 1000)
    }
}

@Test func testContextWithNestedStructures() async throws {
    // Test deeply nested structure conversion
    let context = ImmutableContext(
        targetingKey: "nested_user",
        structure: ImmutableStructure(attributes: [
            "profile": Value.structure([
                "personal": Value.structure([
                    "name": Value.structure([
                        "first": Value.string("John"),
                        "last": Value.string("Doe")
                    ]),
                    "age": Value.integer(30)
                ]),
                "settings": Value.structure([
                    "theme": Value.string("dark"),
                    "notifications": Value.list([
                        Value.string("email"),
                        Value.string("push"),
                        Value.string("sms")
                    ])
                ])
            ])
        ])
    )
    
    let flagsContext = FlagsEvaluationContext(context)
    
    #expect(flagsContext.targetingKey == "nested_user")
    
    // Complex nested structure should be preserved as nested dictionaries
    let profileValue = flagsContext.attributes["profile"]
    #expect(profileValue != nil)
    if case .dictionary(let profile) = profileValue! {
        if case .dictionary(let personal) = profile["personal"]! {
            if case .dictionary(let name) = personal["name"]! {
                #expect(name["first"] == AnyValue.string("John"))
                #expect(name["last"] == AnyValue.string("Doe"))
            }
            #expect(personal["age"] == AnyValue.int(30))
        }
        if case .dictionary(let settings) = profile["settings"]! {
            #expect(settings["theme"] == AnyValue.string("dark"))
            if case .array(let notifications) = settings["notifications"]! {
                #expect(notifications.contains(AnyValue.string("email")))
                #expect(notifications.contains(AnyValue.string("push")))
                #expect(notifications.contains(AnyValue.string("sms")))
            }
        }
    }
}
