Pod::Spec.new do |spec|
  spec.name             = 'platform_calendar'
  spec.version          = '0.1.0'
  spec.summary          = 'Native OS calendar access for Airo.'
  spec.description      = <<-DESC
Reads calendars and events through EventKit without exposing platform types to Dart.
                       DESC
  spec.homepage         = 'https://github.com/DevelopersCoffee/airo'
  spec.license          = { :file => '../LICENSE' }
  spec.author           = { 'DevelopersCoffee' => 'hello@developerscoffee.com' }
  spec.source           = { :path => '.' }
  spec.source_files     = 'Classes/**/*'
  spec.dependency 'Flutter'
  spec.platform         = :ios, '15.5'
  spec.frameworks       = 'EventKit', 'EventKitUI'
  spec.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  spec.swift_version = '5.0'
end
