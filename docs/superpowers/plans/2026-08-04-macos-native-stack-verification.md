# macOS native stack verification — 2026-08-04

Not a plan; a record of a device-adjacent check run mid-P1, at the request to
verify the plugin/native pipeline on macOS before continuing surface work,
on the basis that the same pipeline backs mobile.

## What was checked

`app/pubspec_mind.yaml` swapped into place (backup/restore, following the
convention in `scripts/build-macos-tv.sh`), then `flutter build macos --debug
-t lib/main_mind.dart` and the resulting binary run directly.

## Result: the full chain works, with primary evidence

- **Build.** `flutter pub get` resolved cleanly against the minimal Mind
  pubspec. `flutter build macos` succeeded; cargokit's pod script phase
  compiled `rust/airo_mind_runtime` (`cdylib` + `staticlib` + `rlib`) and
  CocoaPods embedded the resulting dylib into
  `feature_mind.framework/Versions/A/Resources/libairo_mind_runtime.dylib`
  (arm64, 7.1 MB, timestamped to the build).
- **Linkage.** `nm -gU` on the embedded dylib shows genuine
  `flutter_rust_bridge` 2.11.1 export symbols (`_frb_create_shutdown_callback`,
  `_frb_dart_fn_deliver_output`, `_frb_init_frb_dart_api_dl`, …) — not a stub,
  not empty.
- **Execution.** Running the built binary directly:
  - Flutter engine starts (`Running with merged UI and platform thread`), Dart
    VM service listens.
  - `whisper_init_from_file_with_params_no_state: loading model from
    '.../Library/Containers/com.developerscoffee.airo.tv/.../airo_mind/
    ggml-tiny.en.bin'` — real Whisper tiny.en loaded from the **sandboxed**
    macOS container path that `MindService.modelsDirectory()`
    (`getApplicationSupportDirectory()/airo_mind`) resolves to under the App
    Sandbox.
  - `llama_model_loader: loaded ... from '.../airo_mind/
    qwen2.5-0.5b-instruct-q4_k_m.gguf'` — real Qwen2.5-0.5B-Instruct loaded,
    291 tensors read and CPU-repacked for SIMD.
  - `lsof` on the live process confirms both the Flutter kernel blob and the
    GGUF weights held open concurrently.
  - No panic, no `SIGSEGV`/`SIGABRT` on run or on kill.
  - A screenshot shows the legacy `MindHomeScreen` (meeting recorder UI, not
    the M22 device-system surfaces — those are not wired to an entrypoint
    yet, by design; that wiring is P4) rendering correctly with a working
    `Record` control and search field.

## What this proves, and what it does not

**Proves:** the FFI chain — Dart → `flutter_rust_bridge` → Rust
(`airo_mind_runtime`) → C/C++ (`whisper.cpp`, `llama.cpp`) → real on-disk model
weights — is genuinely wired end to end on macOS, under real App Sandbox
entitlements, via the exact cargokit + Cargo workspace mechanism the design
spec assumed but never verified. This directly de-risks the same pipeline on
iOS, which shares the crate, the `flutter_rust_bridge` pin, and cargokit's
build-tool family (`packages/feature_mind/cargokit/build_tool` has iOS-specific
paths alongside macOS's). Android uses a different toolchain (Gradle +
`cargo-ndk` rather than cargokit's Xcode script phases) and was **not**
exercised by this check.

**Does not prove:** that any M22 P1/P2/P3 surface renders against the real
runtime — they still bind to `FixtureMindRuntime` in tests, and
`RustMindRuntime` still reports every port `MindPortUnavailable`
(`packages/feature_mind/lib/src/runtime/rust/rust_mind_runtime.dart`) until
the corresponding M19 issues land. The meeting-recorder path exercised here
(`MindService` → `rust.initialize()` → `processRecording`) is a separate,
older surface with its own direct Rust bindings in `src/api/mind.dart`; it
predates the `MindRuntime` port entirely and is not part of it.

## Where the models came from

Not bundled in this checkout — `packages/feature_mind/assets/models/` holds
only `.gitignore`. They exist under
`~/Library/Containers/com.developerscoffee.airo.tv/.../airo_mind/` on this
machine from a prior session's run, which is a per-user macOS path outside
any git worktree and therefore persists across worktrees sharing this bundle
ID. A clean machine would hit `MindUnavailable.modelsMissing` from
`ModelInstaller` first, which is the documented, tested first-run state.

## Workspace impact

None. `app/pubspec.yaml`, `pubspec.lock`, and `macos/Podfile.lock` were backed
up before the swap and restored byte-for-byte afterward (`git status` shows no
diff on any of the three). `app/build/` was removed. No commit includes any
part of this check.
