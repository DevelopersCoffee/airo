import 'package:core_domain/core_domain.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'secure_storage.dart';

/// Sqflite-backed [EncryptedDatabase] gated by [EncryptionKeyManager].
///
/// This increment uses a separate secure database file and key availability as
/// the encryption boundary. SQLCipher binding is a follow-on platform concern.
class SqfliteEncryptedDatabase implements EncryptedDatabase {
  SqfliteEncryptedDatabase({
    required EncryptionKeyManager keyManager,
    DatabaseFactory? databaseFactory,
    String? databasePath,
  }) : _keyManager = keyManager,
       _databaseFactory = databaseFactory ?? databaseFactorySqflitePlugin,
       _databasePath = databasePath;

  final EncryptionKeyManager _keyManager;
  final DatabaseFactory _databaseFactory;
  final String? _databasePath;

  Database? _database;
  EncryptedDatabaseConfig? _config;
  bool _encryptionReady = false;

  @override
  bool get isOpen => _database != null && _database!.isOpen;

  @override
  String get path => _database?.path ?? _databasePath ?? '';

  @override
  Future<Result<void>> initialize(EncryptedDatabaseConfig config) async {
    if (_database != null && _database!.isOpen) return const Ok(null);

    _config = config;
    if (config.enableEncryption) {
      final available = await _keyManager.isEncryptionAvailable();
      if (!available) {
        return Err(
          SecureDestinationUnavailableError(
            'Encryption is not available on this device',
          ),
          StackTrace.current,
        );
      }
      final keyResult = await _keyManager.getDatabaseKey();
      if (keyResult is Err<List<int>>) {
        return Err(
          SecureDestinationUnavailableError(
            'Database encryption key is unavailable',
            originalError: keyResult.error,
            originalStack: keyResult.stack,
          ),
          keyResult.stack,
        );
      }
      _encryptionReady = true;
    }

    final resolvedPath =
        _databasePath ??
        p.join(await getDatabasesPath(), config.databaseName);

    _database = await _databaseFactory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: config.schemaVersion,
        singleInstance: false,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          if (config.enableWalMode) {
            await db.execute('PRAGMA journal_mode = WAL');
          }
        },
      ),
    );

    return const Ok(null);
  }

  bool get encryptionReady => _encryptionReady;

  Database get database {
    if (_database == null || !_database!.isOpen) {
      throw StateError('Encrypted database is not open');
    }
    return _database!;
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    try {
      final rows = await database.rawQuery(sql, arguments);
      return Ok(rows);
    } catch (error, stack) {
      return Err(StorageError('rawQuery failed: $error'), stack);
    }
  }

  @override
  Future<Result<int>> rawExecute(String sql, [List<Object?>? arguments]) async {
    try {
      return Ok(await database.rawUpdate(sql, arguments));
    } catch (error, stack) {
      return Err(StorageError('rawExecute failed: $error'), stack);
    }
  }

  @override
  Future<Result<int>> insert(String table, Map<String, dynamic> values) async {
    try {
      return Ok(await database.insert(table, values));
    } catch (error, stack) {
      return Err(StorageError('insert failed: $error'), stack);
    }
  }

  @override
  Future<Result<int>> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    try {
      return Ok(
        await database.update(table, values, where: where, whereArgs: whereArgs),
      );
    } catch (error, stack) {
      return Err(StorageError('update failed: $error'), stack);
    }
  }

  @override
  Future<Result<int>> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    try {
      return Ok(
        await database.delete(table, where: where, whereArgs: whereArgs),
      );
    } catch (error, stack) {
      return Err(StorageError('delete failed: $error'), stack);
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final rows = await database.query(
        table,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
      return Ok(rows);
    } catch (error, stack) {
      return Err(StorageError('query failed: $error'), stack);
    }
  }

  @override
  Future<Result<T>> transaction<T>(
    Future<T> Function(EncryptedDatabase txn) action,
  ) async {
    try {
      final result = await database.transaction((txn) async {
        final txnDb = _TransactionDatabase(this, txn);
        return await action(txnDb);
      });
      return Ok(result);
    } catch (error, stack) {
      return Err(StorageError('transaction failed: $error'), stack);
    }
  }

  @override
  Future<Result<void>> close() async {
    try {
      await _database?.close();
      _database = null;
      return const Ok(null);
    } catch (error, stack) {
      return Err(StorageError('close failed: $error'), stack);
    }
  }
}

class _TransactionDatabase implements EncryptedDatabase {
  _TransactionDatabase(this._parent, this._txn);

  final SqfliteEncryptedDatabase _parent;
  final DatabaseExecutor _txn;

  @override
  bool get isOpen => _parent.isOpen;

  @override
  String get path => _parent.path;

  @override
  Future<Result<void>> initialize(EncryptedDatabaseConfig config) async =>
      const Ok(null);

  @override
  Future<Result<List<Map<String, dynamic>>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    try {
      return Ok(await _txn.rawQuery(sql, arguments));
    } catch (error, stack) {
      return Err(StorageError('txn rawQuery failed: $error'), stack);
    }
  }

  @override
  Future<Result<int>> rawExecute(String sql, [List<Object?>? arguments]) async {
    try {
      return Ok(await _txn.rawUpdate(sql, arguments));
    } catch (error, stack) {
      return Err(StorageError('txn rawExecute failed: $error'), stack);
    }
  }

  @override
  Future<Result<int>> insert(String table, Map<String, dynamic> values) async {
    try {
      return Ok(await _txn.insert(table, values));
    } catch (error, stack) {
      return Err(StorageError('txn insert failed: $error'), stack);
    }
  }

  @override
  Future<Result<int>> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    try {
      return Ok(
        await _txn.update(table, values, where: where, whereArgs: whereArgs),
      );
    } catch (error, stack) {
      return Err(StorageError('txn update failed: $error'), stack);
    }
  }

  @override
  Future<Result<int>> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    try {
      return Ok(
        await _txn.delete(table, where: where, whereArgs: whereArgs),
      );
    } catch (error, stack) {
      return Err(StorageError('txn delete failed: $error'), stack);
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final rows = await _txn.query(
        table,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
      return Ok(rows);
    } catch (error, stack) {
      return Err(StorageError('txn query failed: $error'), stack);
    }
  }

  @override
  Future<Result<T>> transaction<T>(
    Future<T> Function(EncryptedDatabase txn) action,
  ) async {
    return Ok(await action(this));
  }

  @override
  Future<Result<void>> close() async => const Ok(null);
}
