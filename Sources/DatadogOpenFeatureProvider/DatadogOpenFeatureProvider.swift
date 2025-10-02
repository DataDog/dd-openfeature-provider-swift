import Foundation
import DatadogFlags
import OpenFeature

public struct DatadogOpenFeatureProvider {
    public static func createProvider(flagsClient: FlagsClientProtocol) -> FeatureProvider {
        return DatadogProvider(flagsClient: flagsClient)
    }
}
