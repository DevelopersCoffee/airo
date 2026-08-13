/// Platform-aware database layer for Airo app.
///
/// This file uses conditional imports to provide:
/// - Native platforms (Android, iOS, Windows, Linux, macOS): SQLite/Drift
/// - Web platform: lightweight in-memory facade until a Drift/IndexedDB
///   adapter is selected explicitly
///
/// Usage:
/// ```dart
/// import 'package:airo/core/database/app_database.dart';
///
/// final db = AppDatabase();
/// await db.close();
/// ```
library;

// Conditional export: use native SQLite by default and the web storage facade
// on web.
//
// Stub-by-default: dart.library.html is false under dart2wasm, so keying the
// web facade off html would link the real (dart:io/ffi-backed) SQLite
// implementation into a wasm web build. Keying the NATIVE file off
// dart.library.io makes every non-native target -- js web and wasm web
// alike -- fall back to the web facade.
export 'app_database_web.dart' if (dart.library.io) 'app_database_native.dart';
