import Foundation

@_exported import OpenFeature

public struct DataDogOpenFeatureProvider {
    public static func createProvider(client: DataDogFlaggingClientWithDetails) -> FeatureProvider {
        return DataDogProvider(client: client)
    }
}
