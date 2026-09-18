Pod::Spec.new do |s|
  s.name             = 'airo_haptics'
  s.version          = '1.0.0'
  s.summary          = 'A cross-platform Flutter haptics engine for macOS.'
  s.description      = <<-DESC
macOS native Force Touch haptics implementation for airo_haptics.
                       DESC
  s.homepage         = 'https://developerscoffee.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Developers Coffee' => 'support@developerscoffee.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'
  s.swift_version = '5.0'
end
