#
# Cargokit builds the Airo Mind engines as part of the Xcode build, so they are
# is compiled by the normal Flutter build rather than by a script someone has to
# remember to run.
#
# macOS consumes the DYLIB, not the static archive. whisper.cpp and llama.cpp
# each vendor their own copy of ggml, and rustc merges both into the staticlib
# with identical symbol names -- linking it produces 591 duplicate symbols. That
# is a real one-definition-rule conflict between two upstream projects, not a
# flag we are missing. rustc resolves it when it links the cdylib itself, so we
# let it.
#
# A happy consequence: nothing force-loads the archive any more, so llama.cpp's
# `common` -- which carries a HuggingFace downloader and which
# `default-features = false` cannot remove, because llama-cpp-2 depends on
# llama-cpp-sys-2 without disabling ITS defaults -- is simply never linked.
# `ADR-0018 §1` asks that the runtime never acquire models; absent because
# nothing references it is a stronger guarantee than deleted after the fact.
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
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'
  s.swift_version = '5.0'

  # Two engines, two libraries. whisper.cpp and llama.cpp each statically
  # vendor their own ggml; a single library holding both links on macOS only by
  # emitting 339 duplicate-symbol warnings and picking an implementation per
  # symbol by link order (#1546). Building them separately removes that.
  s.script_phases = [
    {
      :name => 'Build airo_mind_whisper',
      # The engines live in the cargo WORKSPACE at <repo>/rust, not inside this
      # package, so the manifest path climbs out of packages/feature_mind.
      :script => 'sh "$PODS_TARGET_SRCROOT/../tool/build_runtime_pod.sh" ../../../rust/airo_mind_whisper airo_mind_whisper',
      :execution_position => :before_compile,
      # A phony input keeps Xcode from caching the phase away; cargo does its
      # own up-to-date checking and is fast when nothing changed.
      :input_files  => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
      :output_files => ['${BUILT_PRODUCTS_DIR}/libairo_mind_whisper.dylib'],
    },
    {
      :name => 'Embed airo_mind_whisper',
      # After the framework exists, so there is somewhere to put it. CocoaPods
      # embeds pod frameworks into the app, which is how the dylib ships.
      :script => 'sh "$PODS_TARGET_SRCROOT/../tool/embed_runtime.sh" airo_mind_whisper',
      :execution_position => :after_compile,
      :input_files  => ['${BUILT_PRODUCTS_DIR}/libairo_mind_whisper.dylib'],
      :output_files => ['${BUILT_PRODUCTS_DIR}/feature_mind.framework/Resources/libairo_mind_whisper.dylib'],
    },
    {
      :name => 'Build airo_mind_llama',
      # The engines live in the cargo WORKSPACE at <repo>/rust, not inside this
      # package, so the manifest path climbs out of packages/feature_mind.
      :script => 'sh "$PODS_TARGET_SRCROOT/../tool/build_runtime_pod.sh" ../../../rust/airo_mind_llama airo_mind_llama',
      :execution_position => :before_compile,
      # A phony input keeps Xcode from caching the phase away; cargo does its
      # own up-to-date checking and is fast when nothing changed.
      :input_files  => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
      :output_files => ['${BUILT_PRODUCTS_DIR}/libairo_mind_llama.dylib'],
    },
    {
      :name => 'Embed airo_mind_llama',
      # After the framework exists, so there is somewhere to put it. CocoaPods
      # embeds pod frameworks into the app, which is how the dylib ships.
      :script => 'sh "$PODS_TARGET_SRCROOT/../tool/embed_runtime.sh" airo_mind_llama',
      :execution_position => :after_compile,
      :input_files  => ['${BUILT_PRODUCTS_DIR}/libairo_mind_llama.dylib'],
      :output_files => ['${BUILT_PRODUCTS_DIR}/feature_mind.framework/Resources/libairo_mind_llama.dylib'],
    },
  ]

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
