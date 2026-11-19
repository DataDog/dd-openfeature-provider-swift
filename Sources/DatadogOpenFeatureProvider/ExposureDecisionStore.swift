/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

import Foundation
@_spi(Internal)
import DatadogFlags

/// The exposure decisions of the evaluations that `DatadogProvider` resolved on the current thread.
///
/// OpenFeature runs the provider and every hook of one evaluation synchronously on the calling thread, and its
/// evaluation details are value types, so a per-thread record keyed by the evaluation's fields links the
/// provider's resolve to the hook's `finally`. Each thread keeps at most `capacity` entries.
internal enum ExposureDecisionStore {
    struct Entry {
        let flagKey: String
        let variant: String?
        let allocationKey: String?
        let targetingKey: String?
        let decision: FlagExposureDecision
    }

    static let capacity = 16

    private final class Entries {
        var values: [Entry] = []
    }

    private static let threadKey = "com.datadoghq.openfeature-provider.exposure-decisions"

    private static var entries: Entries {
        let storage = Thread.current.threadDictionary
        if let entries = storage[threadKey] as? Entries {
            return entries
        }
        let entries = Entries()
        storage[threadKey] = entries
        return entries
    }

    static func record(_ entry: Entry) {
        let entries = entries
        entries.values.append(entry)
        if entries.values.count > capacity {
            entries.values.removeFirst(entries.values.count - capacity)
        }
    }

    /// The newest entry of this thread for the evaluation. Nested evaluations add entries above it.
    static func find(flagKey: String, variant: String?, allocationKey: String?, targetingKey: String?) -> Entry? {
        entries.values.last { entry in
            entry.flagKey == flagKey
                && entry.variant == variant
                && entry.allocationKey == allocationKey
                && entry.targetingKey == targetingKey
        }
    }

    static var count: Int { entries.values.count }

    static func removeAll() {
        entries.values.removeAll()
    }
}
