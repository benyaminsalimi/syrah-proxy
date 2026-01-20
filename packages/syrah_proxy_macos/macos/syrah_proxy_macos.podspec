#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint syrah_proxy_macos.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'syrah_proxy_macos'
  s.version          = '1.0.0'
  s.summary          = 'macOS native proxy plugin for Syrah'
  s.description      = <<-DESC
macOS native proxy plugin for Syrah - a network debugging proxy application.
Provides HTTP/HTTPS interception, certificate generation, and traffic capture.
                       DESC
  s.homepage         = 'https://github.com/benyaminsalimi/syrah_app'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Benyamin Salimi' => 'benyaminsalimi@example.com' }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'syrah_proxy_macos_privacy' => ['Resources/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
