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
            let ddContext = convertOpenFeatureContextToDatadogContext(context)
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
        
        let ddContext = convertOpenFeatureContextToDatadogContext(newContext)
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
        let details = adapter.getBooleanDetails(key: key, defaultValue: defaultValue, options: options)
        
        return ProviderEvaluation(
            value: details.value,
            flagMetadata: metadataToFlagMetadata(details.metadata),
            variant: details.variant,
            reason: details.reason
        )
    }
    
    public func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws -> ProviderEvaluation<String> {
        let options = contextToOptions(context)
        let details = adapter.getStringDetails(key: key, defaultValue: defaultValue, options: options)
        
        return ProviderEvaluation(
            value: details.value,
            flagMetadata: metadataToFlagMetadata(details.metadata),
            variant: details.variant,
            reason: details.reason
        )
    }
    
    public func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws -> ProviderEvaluation<Int64> {
        let options = contextToOptions(context)
        let details = adapter.getIntegerDetails(key: key, defaultValue: defaultValue, options: options)
        
        return ProviderEvaluation(
            value: details.value,
            flagMetadata: metadataToFlagMetadata(details.metadata),
            variant: details.variant,
            reason: details.reason
        )
    }
    
    public func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws -> ProviderEvaluation<Double> {
        let options = contextToOptions(context)
        let details = adapter.getDoubleDetails(key: key, defaultValue: defaultValue, options: options)
        
        return ProviderEvaluation(
            value: details.value,
            flagMetadata: metadataToFlagMetadata(details.metadata),
            variant: details.variant,
            reason: details.reason
        )
    }
    
    public func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws -> ProviderEvaluation<Value> {
        let options = contextToOptions(context)
        let defaultDict = valueToDict(defaultValue)
        let details = adapter.getObjectDetails(key: key, defaultValue: defaultDict, options: options)
        
        return ProviderEvaluation(
            value: dictToValue(details.value),
            flagMetadata: metadataToFlagMetadata(details.metadata),
            variant: details.variant,
            reason: details.reason
        )
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
    
    private func convertOpenFeatureContextToDatadogContext(_ context: EvaluationContext) -> FlagsEvaluationContext {
        let targetingKey = context.getTargetingKey()
        
        var attributes: [String: String] = [:]
        for (key, value) in context.asMap() {
            // DatadogFlags only supports String attributes
            attributes[key] = convertValueToString(value)
        }
        
        return FlagsEvaluationContext(targetingKey: targetingKey, attributes: attributes)
    }
    
    private func convertValueToString(_ value: Value) -> String {
        switch value {
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
            if let data = try? JSONSerialization.data(withJSONObject: convertStructureToDict(structure)),
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
    
    private func convertStructureToDict(_ structure: [String: Value]) -> [String: Any] {
        return structure.mapValues { $0.toAny() }
    }
    
    private func valueToDict(_ value: Value) -> [String: Any] {
        switch value {
        case .structure(let structure):
            return structure.mapValues { $0.toAny() }
        case .list(let list):
            return ["_list": list.map { $0.toAny() }]
        default:
            return ["_value": value.toAny()]
        }
    }
    
    private func dictToValue(_ dict: [String: Any]) -> Value {
        if let list = dict["_list"] as? [Any] {
            return .list(list.map { anyToValue($0) })
        } else if let value = dict["_value"] {
            return anyToValue(value)
        } else {
            var structure: [String: Value] = [:]
            for (key, value) in dict {
                structure[key] = anyToValue(value)
            }
            return .structure(structure)
        }
    }
    
    
    private func anyToValue(_ any: Any) -> Value {
        switch any {
        case let bool as Bool:
            return .boolean(bool)
        case let string as String:
            return .string(string)
        case let int as Int:
            return .integer(Int64(int))
        case let int64 as Int64:
            return .integer(int64)
        case let double as Double:
            return .double(double)
        case let date as Date:
            return .date(date)
        case let dict as [String: Any]:
            var structure: [String: Value] = [:]
            for (key, value) in dict {
                structure[key] = anyToValue(value)
            }
            return .structure(structure)
        case let array as [Any]:
            return .list(array.map { anyToValue($0) })
        case is NSNull:
            return .null
        default:
            return .string(String(describing: any))
        }
    }
    
    private func metadataToFlagMetadata(_ metadata: [String: Any]) -> [String: FlagMetadataValue] {
        return metadata.compactMapValues { value in
            switch value {
            case let bool as Bool:
                return .boolean(bool)
            case let string as String:
                return .string(string)
            case let int as Int:
                return .integer(Int64(int))
            case let int64 as Int64:
                return .integer(int64)
            case let double as Double:
                return .double(double)
            default:
                return nil
            }
        }
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
}
