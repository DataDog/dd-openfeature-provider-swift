Pod::Spec.new do |s|
  s.name         = "DatadogOpenFeatureProvider"
  s.version      = "0.1.0"
  s.summary      = "Datadog Provider for OpenFeature Swift SDK."

  s.homepage     = "https://www.datadoghq.com"
  s.social_media_url   = "https://twitter.com/datadoghq"

  s.license            = { :type => "Apache", :file => 'LICENSE' }
  s.authors            = { 
    "Sameeran Kunche" => "sameeran.kunche@datadoghq.com",
  }

  s.swift_version = '5.9'
  s.ios.deployment_target = '14.0'
  s.tvos.deployment_target = '14.0'
  s.watchos.deployment_target = '7.0'
  s.osx.deployment_target = '12.0'

  s.source = { :git => "https://github.com/DataDog/dd-openfeature-provider-swift.git", :tag => s.version.to_s }

  s.source_files = "Sources/DatadogOpenFeatureProvider/**/*.swift"

  s.dependency 'OpenFeature', '~> 0.3.0'
  s.dependency 'DatadogFlags', '>= 3.2.0'

end
