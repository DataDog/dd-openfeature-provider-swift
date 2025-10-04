import Foundation
import DatadogFlags
import OpenFeature

// MARK: - AnyValue Extensions (DatadogFlags → Swift/OpenFeature)

extension AnyValue {
    /// Creates an AnyValue from Swift Any type
    /// Handles all common Swift types and converts them to appropriate AnyValue cases
    init(_ value: Any) {
        switch value {
        case let bool as Bool:
            self = .bool(bool)
        case let string as String:
            self = .string(string)
        case let int as Int:
            self = .int(int)
        case let int64 as Int64:
            self = .int(Int(int64))
        case let double as Double:
            self = .double(double)
        case let dict as [String: Any]:
            var structure: [String: AnyValue] = [:]
            for (key, value) in dict {
                structure[key] = AnyValue(value)
            }
            self = .dictionary(structure)
        case let array as [Any]:
            self = .array(array.map { AnyValue($0) })
        case is NSNull:
            self = .null
        default:
            self = .string(String(describing: value))
        }
    }
    
    /// Creates an AnyValue from OpenFeature Value
    /// Direct conversion without intermediate steps
    init(_ value: Value) throws {
        switch value {
        case .boolean(let bool):
            self = .bool(bool)
        case .string(let string):
            self = .string(string)
        case .integer(let int):
            self = .int(Int(int))
        case .double(let double):
            self = .double(double)
        case .date:
            throw OpenFeatureError.valueNotConvertableError
        case .structure(let structure):
            self = .dictionary(try structure.mapValues { try AnyValue($0) })
        case .list(let list):
            self = .array(try list.map { try AnyValue($0) })
        case .null:
            self = .null
        }
    }
    
    /// Converts AnyValue to Swift Any type
    func toAny() -> Any {
        switch self {
        case .bool(let bool):
            return bool
        case .string(let string):
            return string
        case .int(let int):
            return int
        case .double(let double):
            return double
        case .dictionary(let structure):
            var result: [String: Any] = [:]
            for (key, value) in structure {
                result[key] = value.toAny()
            }
            return result
        case .array(let list):
            return list.map { $0.toAny() }
        case .null:
            return NSNull()
        }
    }
}
