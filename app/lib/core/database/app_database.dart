/// Platform-aware database layer for Airo app.
///
/// This file uses conditional imports to provide:
/// - Native platforms (Android, iOS, Windows, Linux, macOS): SQLite/Drift
/// - Web platform: Hive/IndexedDB
///
/// Usage:
/// ```dart
/// import 'package:airo/core/database/app_database.dart';
///
/// final db = AppDatabase();
/// await db.close();
/// ```
library;

// Conditional import: Use native SQLite on native platforms, Hive on web
export 'app_database_web.dart' if (dart.library.io) 'app_database_native.dart';
