import 'package:core_domain/core_domain.dart';
import 'package:sqflite/sqflite.dart';

import '../secure/secure_storage.dart';
import '../secure/sqflite_encrypted_database.dart';
import 'life_track_graph_sql_store.dart';
import 'life_track_sql_schema.dart';

/// Encrypted LifeTrack destination backed by [SqfliteEncryptedDatabase].
class EncryptedLifeTrackDataSource {
  EncryptedLifeTrackDataSource({
    required SqfliteEncryptedDatabase database,
    this.databaseName = 'life_track_secure.db',
  }) : _database = database;

  final SqfliteEncryptedDatabase _database;
  final String databaseName;

  LifeTrackGraphSqlStore? _store;

  bool get isInitialized => _store != null && _database.isOpen;

  LifeTrackGraphSqlStore get store {
    if (_store == null) {
      throw StateError('Encrypted LifeTrack data source is not initialized');
    }
    return _store!;
  }

  Database get database => _database.database;

  Future<Result<void>> initialize() async {
    final initResult = await _database.initialize(
      EncryptedDatabaseConfig(
        databaseName: databaseName,
        schemaVersion: LifeTrackSqlSchema.schemaVersion,
      ),
    );
    if (initResult is Err<void>) {
      return initResult;
    }

    _store = LifeTrackGraphSqlStore(_database.database);
    await _store!.ensureSchema(includeIdempotency: true);
    await _writeMeta(
      LifeTrackSqlSchema.metaKeyEncryptionEnabled,
      _database.encryptionReady ? 'true' : 'false',
    );
    await _writeMeta(
      LifeTrackSqlSchema.metaKeySchemaVersion,
      LifeTrackSqlSchema.schemaVersion.toString(),
    );
    return const Ok(null);
  }

  Future<Result<void>> writeMeta(String key, String value) async {
    try {
      await _writeMeta(key, value);
      return const Ok(null);
    } catch (error, stack) {
      return Err(StorageError('meta write failed: $error'), stack);
    }
  }

  Future<Result<String?>> readMeta(String key) async {
    try {
      return Ok(await _readMeta(key));
    } catch (error, stack) {
      return Err(StorageError('meta read failed: $error'), stack);
    }
  }

  Future<bool> isMigrationComplete() async {
    if (!isInitialized) return false;
    final value = await _readMeta(LifeTrackSqlSchema.metaKeyMigrationComplete);
    return value == 'true';
  }

  Future<void> close() async {
    await _store?.closeChanges();
    _store = null;
    await _database.close();
  }

  Future<void> _writeMeta(String key, String value) async {
    await _database.database.insert(
      LifeTrackSqlSchema.metaTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> _readMeta(String key) async {
    final rows = await _database.database.query(
      LifeTrackSqlSchema.metaTable,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.single['value'] as String?;
  }
}
