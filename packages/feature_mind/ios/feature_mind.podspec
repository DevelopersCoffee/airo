#
# iOS DOES NOT BUILD YET, and has never built. Tracked by #1546 phase 4.
#
# This pod links a STATIC archive into the app binary. whisper.cpp and llama.cpp
# each statically vendor their own copy of ggml with the same symbol names, so
# the app link fails with 592 duplicate symbols -- measured, not predicted.
# Static linking cannot express the one-library-per-engine split that Android,
# macOS, Linux and Windows now use; iOS needs two dynamic frameworks and a
# `library_loader.dart` path that does not assume in-process symbols.
#
# The phases below are left pointing at the two engine crates so the pod refers
# to code that exists, but building for iOS will not produce a working app until
# that work lands. There is no iOS CI, and the Apple Rust targets are not part
# of any documented setup here, so this breaks nothing that worked.
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
    :name => 'Build airo_mind_whisper',
    # The runtime lives in the cargo WORKSPACE at <repo>/rust, not inside this
    # package, so the manifest path climbs out of packages/feature_mind.
    # Wraps cargokit's build_pod.sh so the model downloader can be removed from
    # the archive afterwards -- see the script for why that is a contract and
    # not a workaround.
    :script => 'sh "$PODS_TARGET_SRCROOT/../tool/build_runtime_pod.sh" ../../../rust/airo_mind_whisper airo_mind_whisper',
    :execution_position => :before_compile,
    # The phony INPUT keeps Xcode from caching the phase away; cargo does its
    # own up-to-date checking and is fast when nothing changed. The OUTPUT must
    # be the archive itself -- declaring a phony there makes Xcode look for the
    # library before anything has claimed to produce it, and the build fails
    # with "Build input file cannot be found".
    :input_files  => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    :output_files => ['${BUILT_PRODUCTS_DIR}/libairo_mind_whisper.a'],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # NOT `-force_load`.
    #
    # Every symbol Dart reaches is unreferenced from Objective-C, so something
    # must stop the linker dead-stripping the bridge. force_load does that by
    # pulling EVERY object in the archive -- including llama.cpp's `common`,
    # which Airo Mind does not use and which does not even link (its download
    # objects need an httplib translation unit llama-cpp-sys-2 does not ship).
    #
    # `-Wl,-u,` names only the entry points. It has to go through -Wl: clang's
    # own `-u` is a different flag, and a bare `-u _frb_x` makes clang treat
    # the symbol as a FILE ("no such file or directory: '_frb_x'"). The linker keeps those and whatever
    # they reference, and never touches `common`. The model downloader is
    # therefore absent from the binary because NOTHING REFERENCES IT, which is
    # a stronger statement than deleting it after the fact -- and it is exactly
    # what `ADR-0018 §1` asks for.
    #
    # These fourteen come from the flutter_rust_bridge crate, not from codegen,
    # so they do not change when the API does. tool/build_runtime_pod.sh
    # asserts the archive still exports exactly this set.
    # force_load used to be what linked the archive at all; with it gone the
    # library has to be named explicitly.
    'LIBRARY_SEARCH_PATHS' => '$(inherited) "${BUILT_PRODUCTS_DIR}"',
    'OTHER_LDFLAGS' => '$(inherited) -lairo_mind_whisper -Wl,-u,_frb_create_shutdown_callback -Wl,-u,_frb_dart_fn_deliver_output -Wl,-u,_frb_dart_opaque_dart2rust_encode -Wl,-u,_frb_dart_opaque_drop_thread_box_persistent_handle -Wl,-u,_frb_dart_opaque_rust2dart_decode -Wl,-u,_frb_free_wire_sync_rust2dart_dco -Wl,-u,_frb_free_wire_sync_rust2dart_sse -Wl,-u,_frb_get_rust_content_hash -Wl,-u,_frb_init_frb_dart_api_dl -Wl,-u,_frb_pde_ffi_dispatcher_primary -Wl,-u,_frb_pde_ffi_dispatcher_sync -Wl,-u,_frb_rust_vec_u8_free -Wl,-u,_frb_rust_vec_u8_new -Wl,-u,_frb_rust_vec_u8_resize',
  }
end
