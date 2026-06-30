import 'package:platform_core/platform_core.dart';
import '../contracts/storage_service.dart';
import '../contracts/database_health_checker.dart';
import '../drift/app_database.dart';
import 'package:drift/drift.dart';

class DriftStorageService implements StorageService {
  final AppDatabase _db;

  DriftStorageService(this._db);

  @override
  String get serviceName => 'PlatformStorage';

  @override
  Future<void> initialize() async {
    // Force open database to trigger migrations before returning
    await _db.customSelect('SELECT 1').get();
  }

  @override
  Future<void> close() async {
    await _db.close();
  }

  @override
  DatabaseHealthChecker get healthChecker => _DriftHealthChecker(_db);
}

class _DriftHealthChecker implements DatabaseHealthChecker {
  final AppDatabase _db;
  _DriftHealthChecker(this._db);

  @override
  Future<DatabaseDiagnostics> checkHealth() async {
    final integrity = await _db.customSelect('PRAGMA integrity_check').getSingle();
    final isOk = integrity.data.values.first == 'ok';
    
    return DatabaseDiagnostics(
      schemaVersion: _db.schemaVersion,
      databaseSizeBytes: 0, // Requires direct file access, skipped for simplicity
      integrityOk: isOk,
      needsVacuum: false, // Could analyze freelist count
    );
  }

  @override
  Future<void> optimize() async {
    await _db.customStatement('PRAGMA optimize');
  }
}
