import Foundation
import OpenFeature
import Combine
import DatadogFlags

public class DatadogProvider: FeatureProvider {
    public let hooks: [any Hook] = []
    public let metadata: ProviderMetadata
    
    private let flagsClient: FlagsClientProtocol
    
    public init(flagsClient: FlagsClientProtocol) {
        self.flagsClient = flagsClient
        self.metadata = DatadogProviderMetadata()
    }
    
    public func initialize(initialContext: EvaluationContext?) async throws {
        
        if let context = initialContext {
            let ddContext = FlagsEvaluationContext(context)
            // Set the context using completion handler
            return try await withCheckedThrowingContinuation { continuation in
                flagsClient.setEvaluationContext(ddContext) { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    public func onContextSet(oldContext: EvaluationContext?, newContext: EvaluationContext) async throws {
        
        let ddContext = FlagsEvaluationContext(newContext)
        // Set the context using completion handler
        return try await withCheckedThrowingContinuation { continuation in
            flagsClient.setEvaluationContext(ddContext) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws -> ProviderEvaluation<Bool> {
        let details = flagsClient.getBooleanDetails(key: key, defaultValue: defaultValue)
        return ProviderEvaluation(
            value: details.value,
            flagMetadata: FlagMetadataBuilder.create(flagKey: key, context: context),
            variant: details.variant,
            reason: details.reason
        )
    }
    
    public func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws -> ProviderEvaluation<String> {
        let details = flagsClient.getStringDetails(key: key, defaultValue: defaultValue)
        return ProviderEvaluation(
            value: details.value,
            flagMetadata: FlagMetadataBuilder.create(flagKey: key, context: context),
            variant: details.variant,
            reason: details.reason
        )
    }
    
    public func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws -> ProviderEvaluation<Int64> {
        let intValue = Int(defaultValue)
        let details = flagsClient.getIntegerDetails(key: key, defaultValue: intValue)
        return ProviderEvaluation(
            value: Int64(details.value),
            flagMetadata: FlagMetadataBuilder.create(flagKey: key, context: context),
            variant: details.variant,
            reason: details.reason
        )
    }
    
    public func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws -> ProviderEvaluation<Double> {
        let details = flagsClient.getDoubleDetails(key: key, defaultValue: defaultValue)
        return ProviderEvaluation(
            value: details.value,
            flagMetadata: FlagMetadataBuilder.create(flagKey: key, context: context),
            variant: details.variant,
            reason: details.reason
        )
    }
    
    public func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws -> ProviderEvaluation<Value> {
        let defaultAnyValue = AnyValue(defaultValue)
        let details = flagsClient.getObjectDetails(key: key, defaultValue: defaultAnyValue)
        return ProviderEvaluation(
            value: Value(details.value),
            flagMetadata: FlagMetadataBuilder.create(flagKey: key, context: context),
            variant: details.variant,
            reason: details.reason
        )
    }
    
}

struct DatadogProviderMetadata: ProviderMetadata {
    let name: String? = "Datadog OpenFeature Provider"
}

extension DatadogProvider: EventPublisher {
    public func observe() -> AnyPublisher<ProviderEvent?, Never> {
        // For now, return an empty publisher
        // This should be implemented when Datadog client supports events
        return Empty<ProviderEvent?, Never>().eraseToAnyPublisher()
    }
}

