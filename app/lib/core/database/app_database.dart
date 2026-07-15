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
export 'app_database_native.dart'
    if (dart.library.html) 'app_database_web.dart';
