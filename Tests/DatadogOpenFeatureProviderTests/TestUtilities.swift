import Foundation
import DatadogFlags
@testable import DatadogOpenFeatureProvider

// MARK: - Shared Test Utilities

/// Mock DatadogFlags Client for Testing
class DatadogFlagsClientMock: FlagsClientProtocol {
    private var flags: [String: (value: AnyValue, variant: String?, reason: String?)] = [:]
    var lastSetContext: FlagsEvaluationContext?
    
    func setupFlag(key: String, value: AnyValue, variant: String? = nil, reason: String? = nil) {
        flags[key] = (value: value, variant: variant, reason: reason)
    }
    
    func setEvaluationContext(_ context: FlagsEvaluationContext, completion: @escaping (Result<Void, FlagsError>) -> Void) {
        lastSetContext = context
        completion(.success(()))
    }
    
    func getDetails<T>(key: String, defaultValue: T) -> FlagDetails<T> where T: Equatable, T: FlagValue {
        if let flag = flags[key] {
            if let value = convertAnyValueToType(flag.value, as: T.self) {
                return FlagDetails(
                    key: key,
                    value: value,
                    variant: flag.variant,
                    reason: flag.reason,
                    error: nil
                )
            }
        }
        return FlagDetails(
            key: key,
            value: defaultValue,
            variant: nil,
            reason: "default",
            error: nil
        )
    }
    
    private func convertAnyValueToType<T>(_ anyValue: AnyValue, as type: T.Type) -> T? {
        switch anyValue {
        case .bool(let bool) where T.self == Bool.self:
            return bool as? T
        case .string(let string) where T.self == String.self:
            return string as? T
        case .int(let int) where T.self == Int.self:
            return int as? T
        case .double(let double) where T.self == Double.self:
            return double as? T
        case _ where T.self == AnyValue.self:
            return anyValue as? T
        default:
            return nil
        }
    }
}
