import Foundation
import OpenFeature
import Combine
import DatadogFlags

public class DatadogProvider: FeatureProvider {
    public let hooks: [any Hook] = []
    public let metadata: ProviderMetadata
    
    private let adapter: DatadogFlagsAdapter
    private let flagsClient: FlagsClientProtocol
    
    public init(flagsClient: FlagsClientProtocol) {
        self.flagsClient = flagsClient
        self.adapter = DatadogFlagsAdapter(flagsClient: flagsClient)
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
        let options = contextToOptions(context)
        return adapter.getBooleanDetails(key: key, defaultValue: defaultValue, options: options)
    }
    
    public func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws -> ProviderEvaluation<String> {
        let options = contextToOptions(context)
        return adapter.getStringDetails(key: key, defaultValue: defaultValue, options: options)
    }
    
    public func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws -> ProviderEvaluation<Int64> {
        let options = contextToOptions(context)
        return adapter.getIntegerDetails(key: key, defaultValue: defaultValue, options: options)
    }
    
    public func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws -> ProviderEvaluation<Double> {
        let options = contextToOptions(context)
        return adapter.getDoubleDetails(key: key, defaultValue: defaultValue, options: options)
    }
    
    public func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws -> ProviderEvaluation<Value> {
        let options = contextToOptions(context)
        return adapter.getObjectDetails(key: key, defaultValue: defaultValue, options: options)
    }
    
    private func contextToOptions(_ context: EvaluationContext?) -> [String: Any]? {
        guard let context = context else { return nil }
        
        var options: [String: Any] = [:]
        
        let targetingKey = context.getTargetingKey()
        options["targetingKey"] = targetingKey
        
        for (key, value) in context.asMap() {
            options[key] = value.toAny()
        }
        
        return options.isEmpty ? nil : options
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

// MARK: - OpenFeature Value Extensions
extension Value {
    /// Converts an OpenFeature Value to Any type for interoperability
    func toAny() -> Any {
        switch self {
        case .boolean(let bool):
            return bool
        case .string(let string):
            return string
        case .integer(let int):
            return int
        case .double(let double):
            return double
        case .date(let date):
            return date
        case .structure(let structure):
            return structure.mapValues { $0.toAny() }
        case .list(let list):
            return list.map { $0.toAny() }
        case .null:
            return NSNull()
        }
    }
    
    /// Converts OpenFeature Value to String representation
    func toString() -> String {
        switch self {
        case .boolean(let bool):
            return bool.description
        case .string(let string):
            return string
        case .integer(let int):
            return int.description
        case .double(let double):
            return double.description
        case .date(let date):
            return date.description
        case .structure(let structure):
            // Convert to JSON string for complex types
            if let data = try? JSONSerialization.data(withJSONObject: structure.mapValues { $0.toAny() }),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            return structure.description
        case .list(let list):
            // Convert to JSON string for complex types
            let arrayDict = list.map { $0.toAny() }
            if let data = try? JSONSerialization.data(withJSONObject: arrayDict),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            return list.description
        case .null:
            return ""
        }
    }
    
    /// Converts OpenFeature Value to dictionary with special handling for non-dictionary types
    func toDictionary() -> [String: Any] {
        switch self {
        case .structure(let structure):
            return structure.mapValues { $0.toAny() }
        case .list(let list):
            return ["_list": list.map { $0.toAny() }]
        default:
            return ["_value": self.toAny()]
        }
    }
}

// MARK: - DatadogFlags Context Extensions
extension FlagsEvaluationContext {
    /// Creates a FlagsEvaluationContext from an OpenFeature EvaluationContext
    init(_ context: EvaluationContext) {
        let targetingKey = context.getTargetingKey()
        
        var attributes: [String: String] = [:]
        for (key, value) in context.asMap() {
            // DatadogFlags only supports String attributes
            attributes[key] = value.toString()
        }
        
        self.init(targetingKey: targetingKey, attributes: attributes)
    }
}
