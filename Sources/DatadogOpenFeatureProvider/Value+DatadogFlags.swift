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
}
