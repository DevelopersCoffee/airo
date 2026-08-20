Pod::Spec.new do |spec|
  spec.name             = 'platform_calendar'
  spec.version          = '0.1.0'
  spec.summary          = 'Native OS calendar access for Airo on macOS.'
  spec.description      = <<-DESC
Reads calendars and events through EventKit on macOS.
                       DESC
  spec.homepage         = 'https://github.com/DevelopersCoffee/airo'
  spec.license          = { :file => '../LICENSE' }
  spec.author           = { 'DevelopersCoffee' => 'hello@developerscoffee.com' }
  spec.source           = { :path => '.' }
  spec.source_files     = 'Classes/**/*'
  spec.dependency 'FlutterMacOS'
  spec.platform         = :osx, '10.15'
  spec.frameworks       = 'EventKit'
  spec.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  spec.swift_version = '5.0'
end
