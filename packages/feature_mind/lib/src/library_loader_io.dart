import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

/// Finds an Airo Mind engine library, whatever shape the platform's native
/// build gave it. Native platforms only — see `library_loader.dart` for why
/// this is behind a conditional import.
///
/// # What each platform produces
///
/// - **Android** gets a `.so` inside the APK, resolved by name.
/// - **macOS** gets dylibs inside `feature_mind.framework`.
/// - **Linux and Windows** get shared libraries beside the executable.
/// - **iOS** has never shipped this runtime: it links a static archive into the
///   app binary, which is the 592-duplicate-symbol case described in
///   `library_loader.dart`. It needs dynamic frameworks before it can work at
///   all, so it is not resolved here.
///
/// The generated loader's `ioDirectory` points at each crate's `target/`, while
/// this workspace builds into the cargo *workspace's* `rust/target/`. Rather
/// than patch generated code — the next codegen run reverts it — the fallbacks
/// live here.
Future<ExternalLibrary?> resolveEngineLibrary(String stem) async {
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

/// Cmd-Q is AppKit terminate; `flutter run` stop and kill are SIGINT/SIGTERM.
void listenForQuitSignals(void Function() onQuit) {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return;
  if (!(Platform.isMacOS || Platform.isLinux || Platform.isWindows)) return;
  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    try {
      signal.watch().listen((_) => onQuit());
    } on Object {
      // A second listener in the isolate, or a platform that rejects the
      // signal, must not prevent the AppLifecycle path from running.
    }
  }
}

/// Drops the whisper Supervisor while Metal is still valid.
void unloadWhisperSpeech() {
  final fn = DynamicLibrary.process()
      .lookup<NativeFunction<Void Function()>>(
        'airo_mind_whisper_unload_speech',
      )
      .asFunction<void Function()>();
  fn();
}
