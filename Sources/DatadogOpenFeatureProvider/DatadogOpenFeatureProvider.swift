import Foundation

import OpenFeature

public struct DatadogOpenFeatureProvider {
    public static func createProvider(client: DatadogFlaggingClientWithDetails) -> FeatureProvider {
        return DatadogProvider(client: client)
    }
}
