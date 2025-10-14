import Testing
import Foundation
import OpenFeature
import DatadogFlags
@testable import DatadogOpenFeatureProvider

// MARK: - ProviderEvaluation Creation Tests

@Suite("Basic ProviderEvaluation Creation")
struct BasicProviderEvaluationTests {
    @Test("Boolean evaluation creation")
    func booleanProviderEvaluationCreation() async throws {
        // Given
        let flagDetails = FlagDetails<Bool>(
            key: "test-bool",
            value: true,
            variant: "enabled",
            reason: "targeting_match",
            error: nil
        )

        // When
        let evaluation = ProviderEvaluation(flagDetails)

        // Then
        #expect(evaluation.value == true)
        #expect(evaluation.variant == "enabled")
        #expect(evaluation.reason == "targeting_match")
        #expect(evaluation.flagMetadata.isEmpty)
    }

    @Test("String evaluation creation")
    func stringProviderEvaluationCreation() async throws {
        let flagDetails = FlagDetails<String>(
            key: "test-string",
            value: "feature-enabled",
            variant: "variation-a",
            reason: "rule_match",
            error: nil
        )

        let evaluation = ProviderEvaluation(flagDetails)

        #expect(evaluation.value == "feature-enabled")
        #expect(evaluation.variant == "variation-a")
        #expect(evaluation.reason == "rule_match")
        #expect(evaluation.flagMetadata.isEmpty)
    }

    @Test("Double evaluation creation")
    func doubleProviderEvaluationCreation() async throws {
        let flagDetails = FlagDetails<Double>(
            key: "test-double",
            value: 42.5,
            variant: "high",
            reason: "percentage_rollout",
            error: nil
        )

        let evaluation = ProviderEvaluation(flagDetails)

        #expect(evaluation.value == 42.5)
        #expect(evaluation.variant == "high")
        #expect(evaluation.reason == "percentage_rollout")
        #expect(evaluation.flagMetadata.isEmpty)
    }

    @Test("Integer evaluation creation")
    func int64ProviderEvaluationCreation() async throws {
        let flagDetails = FlagDetails<Int>(
            key: "test-int",
            value: 1000,
            variant: "large",
            reason: "default",
            error: nil
        )

        let evaluation: ProviderEvaluation<Int64> = ProviderEvaluation(flagDetails)

        #expect(evaluation.value == Int64(1000))
        #expect(evaluation.variant == "large")
        #expect(evaluation.reason == "default")
        #expect(evaluation.flagMetadata.isEmpty)
    }

    @Test("Large integer conversion")
    func providerEvaluationLargeIntConversion() async throws {
        let flagDetails = FlagDetails<Int>(
            key: "large-number",
            value: Int.max,
            variant: "maximum",
            reason: "boundary_test",
            error: nil
        )

        let evaluation: ProviderEvaluation<Int64> = ProviderEvaluation(flagDetails)

        #expect(evaluation.value == Int64(Int.max))
        #expect(evaluation.variant == "maximum")
        #expect(evaluation.reason == "boundary_test")
        #expect(evaluation.flagMetadata.isEmpty)
    }
}

@Suite("Complex Value ProviderEvaluation")
struct ComplexValueEvaluationTests {
    @Test("Simple object evaluation creation")
    func valueProviderEvaluationCreation() async throws {
        let anyValue = AnyValue.dictionary([
            "feature": AnyValue.string("advanced"),
            "level": AnyValue.int(3),
            "enabled": AnyValue.bool(true),
        ])

        let flagDetails = FlagDetails<AnyValue>(
            key: "test-object",
            value: anyValue,
            variant: "complex-config",
            reason: "experiment",
            error: nil
        )

        let evaluation: ProviderEvaluation<Value> = ProviderEvaluation(flagDetails)

        if case .structure(let structure) = evaluation.value {
            #expect(structure["feature"] == Value.string("advanced"))
            #expect(structure["level"] == Value.integer(3))
            #expect(structure["enabled"] == Value.boolean(true))
        } else {
            #expect(Bool(false), "Expected structure value")
        }

        #expect(evaluation.variant == "complex-config")
        #expect(evaluation.reason == "experiment")
        #expect(evaluation.flagMetadata.isEmpty)
    }

    @Test("Complex nested object evaluation")
    func providerEvaluationWithComplexAnyValue() async throws {
        let complexAnyValue = AnyValue.dictionary([
            "config": AnyValue.dictionary([
                "timeout": AnyValue.int(30),
                "retries": AnyValue.int(3),
                "endpoint": AnyValue.string("https://api.example.com"),
            ]),
            "features": AnyValue.array([
                AnyValue.string("feature-a"),
                AnyValue.string("feature-b"),
                AnyValue.string("feature-c"),
            ]),
            "metadata": AnyValue.dictionary([
                "version": AnyValue.string("2.1.0"),
                "beta": AnyValue.bool(false),
            ]),
        ])

        let flagDetails = FlagDetails<AnyValue>(
            key: "app-config",
            value: complexAnyValue,
            variant: "full-config",
            reason: "admin_override",
            error: nil
        )

        let evaluation: ProviderEvaluation<Value> = ProviderEvaluation(flagDetails)

        if case .structure(let structure) = evaluation.value {
            // Check config section
            if case .structure(let config) = structure["config"] {
                #expect(config["timeout"] == Value.integer(30))
                #expect(config["retries"] == Value.integer(3))
                #expect(config["endpoint"] == Value.string("https://api.example.com"))
            } else {
                #expect(Bool(false), "Expected config structure")
            }

            // Check features array
            if case .list(let features) = structure["features"] {
                #expect(features.count == 3)
                #expect(features[0] == Value.string("feature-a"))
                #expect(features[1] == Value.string("feature-b"))
                #expect(features[2] == Value.string("feature-c"))
            } else {
                #expect(Bool(false), "Expected features list")
            }

            // Check metadata section
            if case .structure(let metadata) = structure["metadata"] {
                #expect(metadata["version"] == Value.string("2.1.0"))
                #expect(metadata["beta"] == Value.boolean(false))
            } else {
                #expect(Bool(false), "Expected metadata structure")
            }
        } else {
            #expect(Bool(false), "Expected structure value")
        }

        #expect(evaluation.variant == "full-config")
        #expect(evaluation.reason == "admin_override")
        #expect(evaluation.flagMetadata.isEmpty)
    }
}

@Suite("ProviderEvaluation Edge Cases")
struct ProviderEvaluationEdgeCaseTests {
    @Test("Evaluation with nil variant and reason")
    func providerEvaluationWithNilVariantAndReason() async throws {
        let flagDetails = FlagDetails<Bool>(
            key: "simple-flag",
            value: false,
            variant: nil,
            reason: nil,
            error: nil
        )

        let evaluation = ProviderEvaluation(flagDetails)

        #expect(evaluation.value == false)
        #expect(evaluation.variant == nil)
        #expect(evaluation.reason == nil)
        #expect(evaluation.flagMetadata.isEmpty)
    }

    @Test("Evaluation with context")
    func providerEvaluationWithContext() async throws {
        // Note: Context is created but not passed to ProviderEvaluation since
        // it's handled at a higher level in the OpenFeature architecture
        _ = ImmutableContext(
            targetingKey: "user123",
            structure: ImmutableStructure(attributes: [
                "plan": Value.string("premium"),
                "region": Value.string("us-east"),
            ])
        )

        let flagDetails = FlagDetails<String>(
            key: "premium-feature",
            value: "enabled",
            variant: "premium-variant",
            reason: "user_segment",
            error: nil
        )

        let evaluation = ProviderEvaluation(flagDetails)

        #expect(evaluation.value == "enabled")
        #expect(evaluation.variant == "premium-variant")
        #expect(evaluation.reason == "user_segment")
        #expect(evaluation.flagMetadata.isEmpty)
    }
}
