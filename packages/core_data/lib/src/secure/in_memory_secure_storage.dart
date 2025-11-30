import 'dart:math';
import 'package:core_domain/core_domain.dart';
import 'secure_storage.dart';

/// In-memory implementation of SecureStorage for testing.
class InMemorySecureStorage implements SecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<Result<String?>> read(String key) async {
    return Ok(_storage[key]);
  }

  @override
  Future<Result<void>> write(String key, String value) async {
    _storage[key] = value;
    return Ok(null);
  }

  @override
  Future<Result<void>> delete(String key) async {
    _storage.remove(key);
    return Ok(null);
  }

  @override
  Future<Result<void>> deleteAll() async {
    _storage.clear();
    return Ok(null);
  }

  @override
  Future<Result<bool>> containsKey(String key) async {
    return Ok(_storage.containsKey(key));
  }

  @override
  Future<Result<List<String>>> getAllKeys() async {
    return Ok(_storage.keys.toList());
  }
}

/// In-memory implementation of EncryptionKeyManager for testing.
class InMemoryEncryptionKeyManager implements EncryptionKeyManager {
  List<int>? _key;
  final Random _random = Random.secure();

  @override
  Future<Result<List<int>>> getDatabaseKey() async {
    _key ??= List.generate(32, (_) => _random.nextInt(256));
    return Ok(_key!);
  }

  @override
  Future<Result<void>> rotateKey() async {
    _key = List.generate(32, (_) => _random.nextInt(256));
    return Ok(null);
  }

  @override
  Future<bool> isEncryptionAvailable() async => true;

  @override
  Future<Result<void>> clearKeys() async {
    _key = null;
    return Ok(null);
  }
}

/// In-memory implementation of EncryptedDatabase for testing.
class InMemoryEncryptedDatabase implements EncryptedDatabase {
  final Map<String, List<Map<String, dynamic>>> _tables = {};
  bool _isOpen = false;
  String _path = ':memory:';
  int _autoIncrementId = 1;

  @override
  Future<Result<void>> initialize(EncryptedDatabaseConfig config) async {
    _path = config.databaseName;
    _isOpen = true;
    return Ok(null);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    // Simplified - just return empty for raw queries in test
    return Ok([]);
  }

  @override
  Future<Result<int>> rawExecute(String sql, [List<Object?>? arguments]) async {
    return Ok(0);
  }

  @override
  Future<Result<int>> insert(String table, Map<String, dynamic> values) async {
    _tables.putIfAbsent(table, () => []);
    final id = _autoIncrementId++;
    final row = Map<String, dynamic>.from(values);
    row['id'] = id;
    _tables[table]!.add(row);
    return Ok(id);
  }

  @override
  Future<Result<int>> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final rows = _tables[table] ?? [];
    int count = 0;
    for (final row in rows) {
      // Simplified matching - in real impl would parse where clause
      row.addAll(values);
      count++;
    }
    return Ok(count);
  }

  @override
  Future<Result<int>> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final rows = _tables[table] ?? [];
    final count = rows.length;
    rows.clear();
    return Ok(count);
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
    var rows = List<Map<String, dynamic>>.from(_tables[table] ?? []);
    if (offset != null) rows = rows.skip(offset).toList();
    if (limit != null) rows = rows.take(limit).toList();
    return Ok(rows);
  }

  @override
  Future<Result<T>> transaction<T>(
    Future<T> Function(EncryptedDatabase txn) action,
  ) async {
    try {
      final result = await action(this);
      return Ok(result);
    } catch (e, st) {
      return Err(StorageError('Transaction failed: $e'), st);
    }
  }

  @override
  Future<Result<void>> close() async {
    _isOpen = false;
    return Ok(null);
  }

  @override
  bool get isOpen => _isOpen;

  @override
  String get path => _path;
}

