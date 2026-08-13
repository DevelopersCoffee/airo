#
# Cargokit builds airo_core as part of the Xcode build, so it's compiled by
# the normal Flutter build rather than by a script someone has to remember
# to run. Wired for #1677 — mirrors feature_mind's proven pattern, minus
# the dual-engine complexity (this is a single crate, so the standard
# force-load-the-static-archive shape applies unmodified).
#
Pod::Spec.new do |s|
  s.name             = 'core_native'
  s.version          = '0.1.0'
  s.summary          = 'Flutter bindings for the airo_core Rust crate.'
  s.description      = <<-DESC
High-performance native engines for playlist, EPG, search, and dedup —
falls back to pure Dart when the bridge is unavailable.
                       DESC
  s.homepage         = 'https://github.com/DevelopersCoffee/airo'
  s.license          = { :type => 'MIT' }
  s.author           = { 'DevelopersCoffee' => 'coffee.devloper@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  s.script_phase = {
    :name => 'Build airo_core',
    # The crate lives in the cargo workspace at <repo>/rust, not inside this
    # package, so the manifest path climbs out of packages/core_native.
    :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../../../rust/airo_core airo_core',
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    :output_files => ["${BUILT_PRODUCTS_DIR}/libairo_core.a"],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Flutter.framework does not contain an i386 slice.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/libairo_core.a',
  }
  s.swift_version = '5.0'
end
