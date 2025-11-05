/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

import Foundation
import OpenFeature
import DatadogFlags

@objc(DDOpenFeatureProvider)
@objcMembers
@_spi(objc)
public final class objc_DatadogProvider: NSObject {
    
    internal let swiftProvider: DatadogProvider
    
    @objc
    public init(name: String) {
        self.swiftProvider = DatadogProvider(name: name)
        super.init()
    }
    
    @objc
    public convenience override init() {
        self.init(name: FlagsClient.defaultName)
    }
    
    // MARK: - Initialization
    
    @objc
    public func initialize(initialContext: [String: Any]?, completion: @escaping (NSError?) -> Void) {
        performAsync(completion: completion) {
            let context = initialContext?.dd.swiftEvaluationContext
            try await self.swiftProvider.initialize(initialContext: context)
        }
    }
    
    @objc
    public func setContext(oldContext: [String: Any]?, newContext: [String: Any], completion: @escaping (NSError?) -> Void) {
        performAsync(completion: completion) {
            let oldCtx = oldContext?.dd.swiftEvaluationContext
            guard let newCtx = newContext.dd.swiftEvaluationContext else {
                throw OpenFeatureError.invalidContextError
            }
            try await self.swiftProvider.onContextSet(oldContext: oldCtx, newContext: newCtx)
        }
    }
    
    // MARK: - Private Helpers
    
    private func performAsync(completion: @escaping (NSError?) -> Void, operation: @escaping () async throws -> Void) {
        Task {
            do {
                try await operation()
                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(error as NSError)
                }
            }
        }
    }
    
    // MARK: - Flag Evaluation
    
    @objc
    public func getBooleanValue(key: String, defaultValue: Bool, context: [String: Any]?) throws -> objc_BooleanEvaluation {
        let evaluationContext = context?.dd.swiftEvaluationContext
        let result = try swiftProvider.getBooleanEvaluation(key: key, defaultValue: defaultValue, context: evaluationContext)
        return objc_BooleanEvaluation(swiftEvaluation: result)
    }
    
    @objc
    public func getStringValue(key: String, defaultValue: String, context: [String: Any]?) throws -> objc_StringEvaluation {
        let evaluationContext = context?.dd.swiftEvaluationContext
        let result = try swiftProvider.getStringEvaluation(key: key, defaultValue: defaultValue, context: evaluationContext)
        return objc_StringEvaluation(swiftEvaluation: result)
    }
    
    @objc
    public func getIntegerValue(key: String, defaultValue: Int64, context: [String: Any]?) throws -> objc_IntegerEvaluation {
        let evaluationContext = context?.dd.swiftEvaluationContext
        let result = try swiftProvider.getIntegerEvaluation(key: key, defaultValue: defaultValue, context: evaluationContext)
        return objc_IntegerEvaluation(swiftEvaluation: result)
    }
    
    @objc
    public func getDoubleValue(key: String, defaultValue: Double, context: [String: Any]?) throws -> objc_DoubleEvaluation {
        let evaluationContext = context?.dd.swiftEvaluationContext
        let result = try swiftProvider.getDoubleEvaluation(key: key, defaultValue: defaultValue, context: evaluationContext)
        return objc_DoubleEvaluation(swiftEvaluation: result)
    }
    
    @objc
    public func getObjectValue(key: String, defaultValue: [String: Any], context: [String: Any]?) throws -> objc_ObjectEvaluation {
        let evaluationContext = context?.dd.swiftEvaluationContext
        let swiftDefaultValue = defaultValue.dd.swiftValue
        let result = try swiftProvider.getObjectEvaluation(key: key, defaultValue: swiftDefaultValue, context: evaluationContext)
        return objc_ObjectEvaluation(swiftEvaluation: result)
    }
}

// MARK: - Evaluation Result Types

@objc(DDOpenFeatureBooleanEvaluation)
@objcMembers
@_spi(objc)
public final class objc_BooleanEvaluation: NSObject {
    @objc public let value: Bool
    @objc public let variant: String?
    @objc public let reason: String
    @objc public let errorCode: String?
    @objc public let errorMessage: String?
    
    internal init(swiftEvaluation: ProviderEvaluation<Bool>) {
        self.value = swiftEvaluation.value
        self.variant = swiftEvaluation.variant
        self.reason = swiftEvaluation.reason ?? ""
        self.errorCode = swiftEvaluation.errorCode?.rawValue.description
        self.errorMessage = swiftEvaluation.errorMessage
        super.init()
    }
}

@objc(DDOpenFeatureStringEvaluation)
@objcMembers
@_spi(objc)
public final class objc_StringEvaluation: NSObject {
    @objc public let value: String
    @objc public let variant: String?
    @objc public let reason: String
    @objc public let errorCode: String?
    @objc public let errorMessage: String?
    
    internal init(swiftEvaluation: ProviderEvaluation<String>) {
        self.value = swiftEvaluation.value
        self.variant = swiftEvaluation.variant
        self.reason = swiftEvaluation.reason ?? ""
        self.errorCode = swiftEvaluation.errorCode?.rawValue.description
        self.errorMessage = swiftEvaluation.errorMessage
        super.init()
    }
}

@objc(DDOpenFeatureIntegerEvaluation)
@objcMembers
@_spi(objc)
public final class objc_IntegerEvaluation: NSObject {
    @objc public let value: Int64
    @objc public let variant: String?
    @objc public let reason: String
    @objc public let errorCode: String?
    @objc public let errorMessage: String?
    
    internal init(swiftEvaluation: ProviderEvaluation<Int64>) {
        self.value = swiftEvaluation.value
        self.variant = swiftEvaluation.variant
        self.reason = swiftEvaluation.reason ?? ""
        self.errorCode = swiftEvaluation.errorCode?.rawValue.description
        self.errorMessage = swiftEvaluation.errorMessage
        super.init()
    }
}

@objc(DDOpenFeatureDoubleEvaluation)
@objcMembers
@_spi(objc)
public final class objc_DoubleEvaluation: NSObject {
    @objc public let value: Double
    @objc public let variant: String?
    @objc public let reason: String
    @objc public let errorCode: String?
    @objc public let errorMessage: String?
    
    internal init(swiftEvaluation: ProviderEvaluation<Double>) {
        self.value = swiftEvaluation.value
        self.variant = swiftEvaluation.variant
        self.reason = swiftEvaluation.reason ?? ""
        self.errorCode = swiftEvaluation.errorCode?.rawValue.description
        self.errorMessage = swiftEvaluation.errorMessage
        super.init()
    }
}

@objc(DDOpenFeatureObjectEvaluation)
@objcMembers
@_spi(objc)
public final class objc_ObjectEvaluation: NSObject {
    @objc public let value: [String: Any]
    @objc public let variant: String?
    @objc public let reason: String
    @objc public let errorCode: String?
    @objc public let errorMessage: String?
    
    internal init(swiftEvaluation: ProviderEvaluation<Value>) {
        self.value = swiftEvaluation.value.dd.objcValue
        self.variant = swiftEvaluation.variant
        self.reason = swiftEvaluation.reason ?? ""
        self.errorCode = swiftEvaluation.errorCode?.rawValue.description
        self.errorMessage = swiftEvaluation.errorMessage
        super.init()
    }
}