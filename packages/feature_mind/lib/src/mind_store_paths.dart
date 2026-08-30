import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The directory Rust calls `STORE_PARENT_DIR`.
///
/// Rust derives it once, in `airo_mind_whisper::api::meetings::initialize`, as
/// `dirname(config.store_path)` — and Dart passes
/// `{applicationSupport}/airo_mind/meetings.log` as that store path
/// (`MindService.modelsDirectory` + `storePath:`). So the shared root both
/// sides must agree on is `{applicationSupport}/airo_mind`, **not**
/// `{applicationSupport}`.
///
/// Getting this wrong is silent in both directions: Rust writes the live
/// fan-out WAV somewhere Dart never looks, and reads a settings sidecar Dart
/// never wrote. Neither throws. Every Dart path that has to line up with a
/// Rust-side path resolves through here so the two cannot drift apart again.
///
/// Paths that are Dart's alone — the `.m4a` the recorder writes and reads
/// back, and the processing queue — deliberately do not use this. Moving
/// those would relocate files that already exist on users' machines, which is
/// a migration rather than a fix.
Future<Directory> mindStoreParentDirectory() async {
  final base = await getApplicationSupportDirectory();
  final dir = Directory(p.join(base.path, mindStoreDirectoryName));
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir;
}

/// The one segment that separates `STORE_PARENT_DIR` from application support.
const String mindStoreDirectoryName = 'airo_mind';
