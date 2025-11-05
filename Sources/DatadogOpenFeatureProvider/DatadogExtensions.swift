/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

import Foundation
import OpenFeature

internal struct DatadogExtension<ExtendedType> {
    let base: ExtendedType
    
    fileprivate init(_ base: ExtendedType) {
        self.base = base
    }
}

internal protocol DatadogExtensionCompatible: AnyObject {}
internal protocol DatadogExtensionCompatibleValue {}

extension DatadogExtensionCompatible {
    internal var dd: DatadogExtension<Self> {
        get { return DatadogExtension(self) }
        set { /* no-op */ }
    }
}

extension DatadogExtensionCompatibleValue {
    internal var dd: DatadogExtension<Self> {
        get { return DatadogExtension(self) }
        set { /* no-op */ }
    }
}

// MARK: - Dictionary Extensions

extension Dictionary: DatadogExtensionCompatibleValue {}

extension DatadogExtension where ExtendedType == [String: Any] {
    internal var swiftEvaluationContext: EvaluationContext? {
        guard !base.isEmpty else { return nil }
        
        let structure = ImmutableStructure(attributes: base.mapValues(convertToValue))
        let context = ImmutableContext(targetingKey: "", structure: structure)
        return context
    }
    
    internal var swiftValue: Value {
        var result: [String: Value] = [:]
        for (key, value) in base {
            result[key] = convertToValue(value)
        }
        return .structure(result)
    }
    
    private func convertToValue(_ value: Any) -> Value {
        switch value {
        case let boolValue as Bool:
            return .boolean(boolValue)
        case let stringValue as String:
            return .string(stringValue)
        case let intValue as Int:
            return .integer(Int64(intValue))
        case let int64Value as Int64:
            return .integer(int64Value)
        case let doubleValue as Double:
            return .double(doubleValue)
        case let floatValue as Float:
            return .double(Double(floatValue))
        case let arrayValue as [Any]:
            return .list(arrayValue.map(convertToValue))
        case let dictValue as [String: Any]:
            var result: [String: Value] = [:]
            for (key, val) in dictValue {
                result[key] = convertToValue(val)
            }
            return .structure(result)
        default:
            return .null
        }
    }
}

// MARK: - Value Extensions

extension Value: DatadogExtensionCompatibleValue {}

extension DatadogExtension where ExtendedType == Value {
    internal var objcValue: [String: Any] {
        return convertToObjcValue(base) as? [String: Any] ?? [:]
    }
    
    private func convertToObjcValue(_ value: Value) -> Any {
        switch value {
        case .null:
            return NSNull()
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
        case .list(let array):
            return array.map(convertToObjcValue)
        case .structure(let dict):
            var result: [String: Any] = [:]
            for (key, val) in dict {
                result[key] = convertToObjcValue(val)
            }
            return result
        }
    }
}
