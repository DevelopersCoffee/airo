import 'package:flutter/foundation.dart' show kIsWeb;

import 'api/relational_store.dart' as native_store;
import 'native_bridge.dart';

class AiroRelationalStoreStatus {
  const AiroRelationalStoreStatus({
    required this.schemaVersion,
    required this.foreignKeysEnabled,
  });

  final int schemaVersion;
  final bool foreignKeysEnabled;
}

/// Applies the bundled relational schema using the Rust storage boundary.
///
/// Returns `null` on web or when the native library cannot initialize. Once
/// initialized, migration and SQLite failures are deliberately propagated.
Future<AiroRelationalStoreStatus?> initializeAiroRelationalStore(
  String path,
) async {
  if (path.trim().isEmpty) {
    throw ArgumentError.value(path, 'path', 'must not be empty');
  }
  if (kIsWeb || !await initializeCoreNativeBridge()) return null;

  final status = await native_store.initializeRelationalStore(path: path);
  return AiroRelationalStoreStatus(
    schemaVersion: status.schemaVersion,
    foreignKeysEnabled: status.foreignKeysEnabled,
  );
}
