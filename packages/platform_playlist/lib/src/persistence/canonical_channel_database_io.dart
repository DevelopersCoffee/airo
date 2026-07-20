import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Real on-device executor for [CanonicalChannelDatabase.open] -- isolated
/// behind a conditional import (see canonical_channel_database.dart) since
/// `package:drift/native.dart` pulls in `dart:ffi` via sqlite3, which is not
/// available on the web target.
QueryExecutor openFileExecutor() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'canonical_channels.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// In-memory executor for [CanonicalChannelDatabase.forTesting].
QueryExecutor memoryExecutor() => NativeDatabase.memory();
