import 'dart:io';

// `ExternalLibrary` is not on flutter_rust_bridge's public barrel; the
// generated code reaches for it through this entry point, so this file does the
// same rather than depending on an internal path directly.
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

import 'llama/frb_generated.dart' as llama;
import 'whisper/frb_generated.dart' as whisper;

/// Finds an Airo Mind engine library, whatever shape the platform's build gave
/// it.
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
/// # What each platform produces
///
/// - **Android** gets a `.so` inside the APK, resolved by name.
/// - **macOS** gets dylibs inside `feature_mind.framework`.
/// - **Linux and Windows** get shared libraries beside the executable.
/// - **iOS** has never shipped this runtime: it links a static archive into the
///   app binary, which is the 592-duplicate-symbol case above. It needs dynamic
///   frameworks before it can work at all, so it is not resolved here.
///
/// The generated loader's `ioDirectory` points at each crate's `target/`, while
/// this workspace builds into the cargo *workspace's* `rust/target/`. Rather
/// than patch generated code — the next codegen run reverts it — the fallbacks
/// live here.
Future<ExternalLibrary?> _resolve(String stem) async {
  if (Platform.isMacOS) {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    for (final candidate in [
      '$exeDir/../Frameworks/feature_mind.framework/Resources/lib$stem.dylib',
      '$exeDir/../Frameworks/feature_mind.framework/Versions/A/Resources/lib$stem.dylib',
      '$exeDir/../Frameworks/lib$stem.dylib',
    ]) {
      final file = File(candidate);
      if (file.existsSync()) return ExternalLibrary.open(file.path);
    }
    return null;
  }

  // Returning null hands over to the generated loader, which resolves an
  // Android `.so` by name from the APK.
  if (Platform.isAndroid) return null;

  final name = Platform.isWindows ? '$stem.dll' : 'lib$stem.so';
  final exeDir = File(Platform.resolvedExecutable).parent.path;

  for (final candidate in ['$exeDir/$name', '$exeDir/lib/$name']) {
    final file = File(candidate);
    if (file.existsSync()) return ExternalLibrary.open(file.path);
  }
  // Nothing found: let the generated loader try its own convention rather than
  // failing on a build that wired the library somewhere this file has not
  // heard of.
  return null;
}

/// Initialises the speech bridge — transcription and the meeting library.
///
/// Loaded during startup, because every journey begins with it.
Future<void> initializeWhisperBridge() async {
  await whisper.RustLib.init(
    externalLibrary: await _resolve('airo_mind_whisper'),
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
  await llama.RustLib.init(externalLibrary: await _resolve('airo_mind_llama'));
  _llamaInitialized = true;
}

/// Whether the generation library has been loaded into this process.
///
/// Exposed for the test that asserts a transcribe-only run does not load it.
bool get isLlamaLoaded => _llamaInitialized;
