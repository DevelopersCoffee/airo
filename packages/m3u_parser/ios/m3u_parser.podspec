#
# Cargokit builds m3u_parser as part of the Xcode build, so it's compiled
# by the normal Flutter build rather than by a script someone has to
# remember to run. Mirrors packages/core_native's pattern (#1677).
#
Pod::Spec.new do |s|
  s.name             = 'm3u_parser'
  s.version          = '0.1.0'
  s.summary          = 'M3U/M3U8 playlist parser — Rust core with a pure-Dart fallback.'
  s.description      = <<-DESC
Parses M3U/M3U8 playlists into structured channel entries. Rust-accelerated
on native platforms, falls back to an identical pure-Dart implementation
when the native bridge is unavailable (including web).
                       DESC
  s.homepage         = 'https://github.com/DevelopersCoffee/airo'
  s.license          = { :type => 'MIT' }
  s.author           = { 'DevelopersCoffee' => 'coffee.devloper@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  s.script_phase = {
    :name => 'Build m3u_parser',
    :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../rust m3u_parser',
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    :output_files => ["${BUILT_PRODUCTS_DIR}/libm3u_parser.a"],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Flutter.framework does not contain an i386 slice.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/libm3u_parser.a',
  }
  s.swift_version = '5.0'
end
