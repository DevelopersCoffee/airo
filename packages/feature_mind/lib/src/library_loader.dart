import 'library_loader_stub.dart' if (dart.library.io) 'library_loader_io.dart'
    as platform;
import 'llama/frb_generated.dart' as llama;
import 'whisper/frb_generated.dart' as whisper;

/// Loads the Airo Mind engine libraries.
///
/// # Why there are two
///
/// whisper.cpp and llama.cpp each statically vendor their own copy of ggml,
/// with the same symbol names and 348 files of difference between the trees.
/// One library holding both is a one-definition-rule conflict between two
/// upstream projects: Android's lld refuses it, a merged static archive fails
/// with 592 duplicate symbols, and Apple's linker links it anyway while warning
/// about 339 of them and choosing an implementation per symbol by link order.
///
/// Two libraries, loaded separately, is the fix. Neither exports its ggml
/// (rustc's version script exports only the bridge), so the copies stay private
/// to their own image even with both loaded into this process.
///
/// # Why the resolver is behind a conditional import
///
/// Locating the library on disk (`library_loader_io.dart`) uses `dart:io` and
/// `ExternalLibrary.open`, which needs `dart:ffi` — neither exists on web.
/// This package now also carries the assistant hub, which a shared surface
/// like the super app's web build does compile
/// (`docs/superpowers/plans/2026-08-07-airo-mind-ssot-plan.md`, Phase 2), so
/// this file itself must compile there even though the engines never load.
/// `library_loader_stub.dart` is what dart2js picks up instead.
Future<void> initializeWhisperBridge() async {
  await whisper.RustLib.init(
    externalLibrary: await platform.resolveEngineLibrary('airo_mind_whisper'),
  );
}

bool _llamaInitialized = false;

/// Initialises the generation bridge, once.
///
/// **Deliberately not called at startup.** This library is roughly 48 MB and
/// only minutes need it, so recording and transcription do not pay for it. The
/// first generation does, which is why the caller shows a state for it rather
/// than letting the UI sit still.
///
/// Idempotent: `MindService` calls it before every generation and only the
/// first one loads anything.
Future<void> initializeLlamaBridge() async {
  if (_llamaInitialized) return;
  await llama.RustLib.init(
    externalLibrary: await platform.resolveEngineLibrary('airo_mind_llama'),
  );
  _llamaInitialized = true;
}

/// Whether the generation library has been loaded into this process.
///
/// Exposed for the test that asserts a transcribe-only run does not load it.
bool get isLlamaLoaded => _llamaInitialized;
