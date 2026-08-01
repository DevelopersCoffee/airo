import 'dart:io';

// `ExternalLibrary` is not on flutter_rust_bridge's public barrel; the
// generated code reaches for it through this entry point, so this file does the
// same rather than depending on an internal path directly.
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

import 'frb_generated.dart';

/// Finds `airo_mind_runtime`, whatever shape the platform's build gave it.
///
/// Cargokit compiles the crate during the ordinary Flutter build, but it does
/// not produce the same artefact everywhere:
///
/// - **iOS and macOS** get a static library that the podspec force-loads into
///   the app binary. There is no file to open — the symbols are already in the
///   process, and asking for a dylib fails on a build that is working.
/// - **Android** gets a `.so` inside the APK, resolved by name.
/// - **Linux and Windows** get a shared library beside the executable.
///
/// The generated loader's `ioDirectory` points at the crate's `target/`, while
/// this workspace builds into the cargo *workspace's* `rust/target/`. Rather
/// than patch generated code — the next codegen run reverts it — the fallbacks
/// live here.
Future<ExternalLibrary?> resolveMindLibrary() async {
  // iOS links the runtime into the process. macOS does not: the static
  // archive cannot be linked at all, because whisper.cpp and llama.cpp each
  // vendor their own ggml and the symbol names collide. macOS ships the dylib
  // inside feature_mind.framework instead.
  if (Platform.isIOS) {
    return ExternalLibrary.process(iKnowHowToUseIt: true);
  }

  if (Platform.isMacOS) {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    for (final candidate in [
      '$exeDir/../Frameworks/feature_mind.framework/Resources/libairo_mind_runtime.dylib',
      '$exeDir/../Frameworks/feature_mind.framework/Versions/A/Resources/libairo_mind_runtime.dylib',
      '$exeDir/../Frameworks/libairo_mind_runtime.dylib',
    ]) {
      final file = File(candidate);
      if (file.existsSync()) return ExternalLibrary.open(file.path);
    }
    return null;
  }

  // Returning null hands over to the generated loader, which resolves an
  // Android `.so` by name from the APK.
  if (Platform.isAndroid) return null;

  final name = Platform.isWindows
      ? 'airo_mind_runtime.dll'
      : 'libairo_mind_runtime.so';
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

/// Initialises the bridge, resolving the library first.
Future<void> initializeMindBridge() async {
  await RustLib.init(externalLibrary: await resolveMindLibrary());
}
