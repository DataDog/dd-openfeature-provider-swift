import Foundation
import DatadogFlags
import OpenFeature

// MARK: - Value Extensions (OpenFeature → Swift/DatadogFlags)

extension Value {
    /// Creates OpenFeature Value from DatadogFlags AnyValue
    /// Direct conversion without intermediate steps
    init(_ anyValue: AnyValue) {
        switch anyValue {
        case .bool(let bool):
            self = .boolean(bool)
        case .string(let string):
            self = .string(string)
        case .int(let int):
            self = .integer(Int64(int))
        case .double(let double):
            self = .double(double)
        case .dictionary(let structure):
            self = .structure(structure.mapValues { Value($0) })
        case .array(let list):
            self = .list(list.map { Value($0) })
        case .null:
            self = .null
        }
    }
    
    /// Converts OpenFeature Value to Swift Any type
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
}
