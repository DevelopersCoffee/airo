import 'package:drift/drift.dart';

/// Web stub for [canonical_channel_database_io.dart] -- the canonical
/// channel database is a native/mobile-only feature (CV-017); the web
/// target must still compile since `platform_playlist`'s barrel exports
/// this file unconditionally, but never actually opens the database.
QueryExecutor openFileExecutor() {
  throw UnsupportedError(
    'CanonicalChannelDatabase.open() is not supported on web.',
  );
}

QueryExecutor memoryExecutor() {
  throw UnsupportedError(
    'CanonicalChannelDatabase.forTesting() is not supported on web.',
  );
}
