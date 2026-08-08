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
library;

import 'package:flutter/foundation.dart';

import 'library_loader_stub.dart'
    if (dart.library.io) 'library_loader_io.dart'
    as platform;
import 'llama/frb_generated.dart' as llama;
import 'whisper/frb_generated.dart' as whisper;

/// Runs `init` at most once per process, no matter how many callers ask.
///
/// `RustLib.init` throws `Bad state: Should not initialize flutter_rust_bridge
/// twice` on a second call, and both bridges have callers that legitimately
/// ask more than once: generation asks before every generation, and speech
/// asks again whenever startup is re-run — which the models-missing screen now
/// does as soon as a download finishes (#1554). Without this the app came back
/// from a successful download claiming Airo Mind was not available on this
/// platform.
///
/// The in-flight future is what is remembered, not just a flag, so two
/// overlapping callers await one initialisation instead of racing past a bool
/// that neither has set yet. A failure is not remembered: a load that failed
/// has initialised nothing, so the next caller is allowed to try again.
Future<void> _once(
  Future<void>? Function() read,
  void Function(Future<void>?) write,
  Future<void> Function() init,
) {
  final started = read();
  if (started != null) return started;
  final future = init()..onError((Object _, StackTrace _) => write(null));
  write(future);
  return future;
}

/// The raw `RustLib.init` calls, behind a seam.
///
/// A test cannot exercise the guard through the real ones: they load a native
/// library that a `flutter_test` host does not have, so the property under
/// test — *the second call does not throw* — would be hidden behind a load
/// failure. These are the only mutable state here, and only tests write them.
@visibleForTesting
Future<void> Function() whisperRustInit = () async => whisper.RustLib.init(
  externalLibrary: await platform.resolveEngineLibrary('airo_mind_whisper'),
);

@visibleForTesting
Future<void> Function() llamaRustInit = () async => llama.RustLib.init(
  externalLibrary: await platform.resolveEngineLibrary('airo_mind_llama'),
);

/// Forgets what has been loaded. Tests only — a process cannot actually
/// unload a native library.
@visibleForTesting
void resetBridgeLoadersForTest() {
  _whisperInit = null;
  _whisperInitialized = false;
  _llamaInit = null;
  _llamaInitialized = false;
}

Future<void>? _whisperInit;
bool _whisperInitialized = false;

/// Initialises the speech bridge — transcription and the meeting library.
///
/// Loaded during startup, because every journey begins with it. Idempotent:
/// startup runs again after a model download, and a second `RustLib.init`
/// throws.
Future<void> initializeWhisperBridge() =>
    _once(() => _whisperInit, (f) => _whisperInit = f, () async {
      await whisperRustInit();
      _whisperInitialized = true;
    });

/// Whether the speech library has been loaded into this process.
bool get isWhisperLoaded => _whisperInitialized;

Future<void>? _llamaInit;
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
Future<void> initializeLlamaBridge() =>
    _once(() => _llamaInit, (f) => _llamaInit = f, () async {
      await llamaRustInit();
      _llamaInitialized = true;
    });

/// Whether the generation library has been loaded into this process.
///
/// Exposed for the test that asserts a transcribe-only run does not load it.
bool get isLlamaLoaded => _llamaInitialized;
