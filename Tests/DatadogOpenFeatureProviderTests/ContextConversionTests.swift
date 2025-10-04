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
    #expect(flagsContext.attributes["email"] == "test@example.com")
    #expect(flagsContext.attributes["age"] == "25") // Should be converted to string
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
    #expect(flagsContext.attributes["region"] == "us-west-2")
    #expect(flagsContext.attributes["plan"] == "premium")
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
    
    // All values should be converted to strings
    #expect(flagsContext.attributes["string"] == "text")
    #expect(flagsContext.attributes["integer"] == "42")
    #expect(flagsContext.attributes["double"] == "3.14")
    #expect(flagsContext.attributes["boolean"] == "true")
    #expect(flagsContext.attributes["null"] == "")
    
    // Date should be converted to string representation
    let dateString = flagsContext.attributes["date"]
    #expect(dateString != nil)
    #expect(dateString!.contains("2021"))
    
    // Complex types should be JSON serialized
    let structureString = flagsContext.attributes["structure"]
    #expect(structureString != nil)
    #expect(structureString!.contains("nested"))
    #expect(structureString!.contains("value"))
    #expect(structureString!.contains("count"))
    #expect(structureString!.contains("10"))
    
    let listString = flagsContext.attributes["list"]
    #expect(listString != nil)
    #expect(listString!.contains("item1"))
    #expect(listString!.contains("item2"))
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
    #expect(flagsContext.attributes["email"] == "user+test@example.com")
    #expect(flagsContext.attributes["name"] == "José María")
    #expect(flagsContext.attributes["description"] == "Line 1\nLine 2\tTabbed")
    #expect(flagsContext.attributes["json"] == "{\"key\": \"value\"}")
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
    #expect(flagsContext.attributes["maxInt64"] == String(Int64.max))
    #expect(flagsContext.attributes["minInt64"] == String(Int64.min))
    #expect(flagsContext.attributes["zero"] == "0")
    
    // Check that large/small doubles are converted
    #expect(flagsContext.attributes["largeDouble"] != nil)
    #expect(flagsContext.attributes["smallDouble"] != nil)
    #expect(flagsContext.attributes["negativeDouble"] == "-999.999")
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
    #expect(flagsContext.attributes["empty_string"] == "")
    #expect(flagsContext.attributes["whitespace"] == "   ")
    #expect(flagsContext.attributes["newlines"] == "\n\n\n")
    #expect(flagsContext.attributes["unicode"] == "🎉 Hello 世界 🌍")
    #expect(flagsContext.attributes["very_long"]?.count == 1000)
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
    
    // Complex nested structure should be serialized to JSON string
    let profileString = flagsContext.attributes["profile"]
    #expect(profileString != nil)
    #expect(profileString!.contains("John"))
    #expect(profileString!.contains("Doe"))
    #expect(profileString!.contains("30"))
    #expect(profileString!.contains("dark"))
    #expect(profileString!.contains("email"))
    #expect(profileString!.contains("push"))
    #expect(profileString!.contains("sms"))
}