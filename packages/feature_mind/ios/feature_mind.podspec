#
# Cargokit builds `airo_mind_runtime` as part of the Xcode build, so the
# runtime is compiled, linked and signed by the normal Flutter build rather
# than by a script someone has to remember to run.
#
Pod::Spec.new do |s|
  s.name             = 'feature_mind'
  s.version          = '0.1.0'
  s.summary          = 'Airo Mind — on-device meeting intelligence.'
  s.description      = <<-DESC
Records a meeting, transcribes it and writes minutes entirely on the device.
                       DESC
  s.homepage         = 'https://github.com/DevelopersCoffee/airo'
  s.license          = { :type => 'MIT' }
  s.author           = { 'DevelopersCoffee' => 'coffee.devloper@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.swift_version = '5.0'

  # whisper.cpp and llama.cpp both link ggml, which reaches for vDSP (Accelerate)
  # and the Metal compute backend. A Rust STATIC library carries no link
  # instructions of its own -- cargo would have passed these itself for a
  # dylib -- so the pod has to name them or the app fails at link with
  # "_vDSP_vsub, referenced from _ggml_compute_forward_sub".
  s.frameworks = 'Accelerate', 'Metal', 'MetalKit', 'Foundation'
  # ggml is C++, so the C++ runtime has to be named too -- same reason.
  s.libraries = 'c++'

  s.script_phase = {
    :name => 'Build airo_mind_runtime',
    # The runtime lives in the cargo WORKSPACE at <repo>/rust, not inside this
    # package, so the manifest path climbs out of packages/feature_mind.
    :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../../../rust/airo_mind_runtime airo_mind_runtime',
    :execution_position => :before_compile,
    # The phony INPUT keeps Xcode from caching the phase away; cargo does its
    # own up-to-date checking and is fast when nothing changed. The OUTPUT must
    # be the archive itself -- declaring a phony there makes Xcode look for the
    # library before anything has claimed to produce it, and the build fails
    # with "Build input file cannot be found".
    :input_files  => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    :output_files => ['${BUILT_PRODUCTS_DIR}/libairo_mind_runtime.a'],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Force-load: every symbol Dart reaches through dlopen/ffi is unreferenced
    # from Objective-C, and the linker would otherwise strip the whole archive.
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/libairo_mind_runtime.a',
  }
end
