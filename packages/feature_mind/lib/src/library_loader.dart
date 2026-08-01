import 'dart:io';

// `ExternalLibrary` is not on flutter_rust_bridge's public barrel; the
// generated code reaches for it through this entry point, so this file does the
// same rather than depending on an internal path directly.
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:path/path.dart' as p;

import 'frb_generated.dart';

/// Finds `libairo_mind_runtime`.
///
/// The generated loader assumes a path relative to the process working
/// directory, which holds for `flutter_rust_bridge`'s own example layout and
/// not for this workspace: `flutter run` sets the working directory to `app/`,
/// and the crate is two levels away in the other direction.
///
/// Rather than patch generated code — the next codegen run would revert it —
/// the candidates are listed here, most-specific first.
Future<ExternalLibrary?> resolveMindLibrary() async {
  // iOS and Android link the runtime into the process: there is no separate
  // file to open, and asking for one fails on a build that is working.
  if (Platform.isIOS || Platform.isAndroid) {
    return ExternalLibrary.process(iKnowHowToUseIt: true);
  }

  final name = Platform.isWindows
      ? 'airo_mind_runtime.dll'
      : Platform.isMacOS
          ? 'libairo_mind_runtime.dylib'
          : 'libairo_mind_runtime.so';

  final exeDir = p.dirname(Platform.resolvedExecutable);
  final candidates = <String>[
    // A bundled desktop app: macOS puts dylibs in Frameworks, Linux and
    // Windows beside the executable.
    p.join(exeDir, '..', 'Frameworks', name),
    p.join(exeDir, name),
    p.join(exeDir, 'lib', name),
    // Developer machine. `flutter run` leaves the working directory at the
    // Flutter project, so walk up to the workspace root. The target directory
    // is the CARGO WORKSPACE's (`rust/target`), not the crate's -- a detail
    // that costs an afternoon when it is guessed wrong.
    for (final root in [
      p.join(Directory.current.path, '..', 'rust', 'target'),
      p.join(Directory.current.path, 'rust', 'target'),
    ])
      for (final profile in ['release', 'debug']) p.join(root, profile, name),
  ];

  for (final candidate in candidates) {
    final file = File(p.normalize(candidate));
    if (file.existsSync()) return ExternalLibrary.open(file.path);
  }
  return null;
}

/// Initialises the bridge, resolving the library first.
///
/// Falls back to the generated loader so that a build which *has* wired the
/// library in the conventional place keeps working without this file knowing
/// about it.
Future<void> initializeMindBridge() async {
  final library = await resolveMindLibrary();
  await RustLib.init(externalLibrary: library);
}
