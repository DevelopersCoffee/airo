import os

def create_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

base = 'packages/platform_storage/lib/src'

# Contracts
create_file(f'{base}/contracts/storage_service.dart', '''import 'package:platform_core/platform_core.dart';
import 'database_health_checker.dart';

abstract interface class StorageService implements PlatformService {
  Future<void> initialize();
  Future<void> close();
  DatabaseHealthChecker get healthChecker;
}
''')

create_file(f'{base}/contracts/repository_factory.dart', '''abstract interface class RepositoryFactory {
  void register<T>(T Function() builder);
  T get<T>();
}
''')

create_file(f'{base}/contracts/transaction_manager.dart', '''import 'package:platform_core/platform_core.dart';

abstract interface class TransactionManager {
  Future<T> transaction<T>(Future<T> Function() action);
}
''')

create_file(f'{base}/contracts/database_migration.dart', '''abstract interface class DatabaseMigration {
  int get fromVersion;
  int get toVersion;
  Future<void> execute();
}
''')

create_file(f'{base}/contracts/database_health_checker.dart', '''class DatabaseDiagnostics {
  final int schemaVersion;
  final int databaseSizeBytes;
  final bool integrityOk;
  final bool needsVacuum;

  const DatabaseDiagnostics({
    required this.schemaVersion,
    required this.databaseSizeBytes,
    required this.integrityOk,
    required this.needsVacuum,
  });
}

abstract interface class DatabaseHealthChecker {
  Future<DatabaseDiagnostics> checkHealth();
  Future<void> optimize();
}
''')

create_file(f'{base}/contracts/database_backup_provider.dart', '''abstract interface class DatabaseBackupProvider {
  Future<String> createSnapshot();
  Future<void> restoreSnapshot(String path);
}
''')

# Schema/Entities Mixins
create_file(f'{base}/entities/audit_metadata.dart', '''import 'package:drift/drift.dart';

mixin AuditMetadata on Table {
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdBy => text().nullable()();
  TextColumn get updatedBy => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
}

mixin WorkspaceIsolation on Table {
  TextColumn get workspaceId => text()();
}

mixin SoftDelete on Table {
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
''')

# Converters
create_file(f'{base}/converters/central_converters.dart', '''import 'dart:convert';
import 'package:drift/drift.dart';

class DurationConverter extends TypeConverter<Duration, int> {
  const DurationConverter();
  @override
  Duration fromSql(int fromDb) => Duration(milliseconds: fromDb);
  @override
  int toSql(Duration value) => value.inMilliseconds;
}

class UriConverter extends TypeConverter<Uri, String> {
  const UriConverter();
  @override
  Uri fromSql(String fromDb) => Uri.parse(fromDb);
  @override
  String toSql(Uri value) => value.toString();
}

class JsonMapConverter extends TypeConverter<Map<String, dynamic>, String> {
  const JsonMapConverter();
  @override
  Map<String, dynamic> fromSql(String fromDb) => jsonDecode(fromDb) as Map<String, dynamic>;
  @override
  String toSql(Map<String, dynamic> value) => jsonEncode(value);
}
''')

# Drift Base
create_file(f'{base}/drift/app_database.dart', '''import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'app_database.g.dart';

// Empty database for now. Feature packages will not add tables directly here.
// Instead, we will use drift modular generation or register DAOs.
// For the foundation, we just need the schema version and migration hooks.
@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Migration logic handled via registered DatabaseMigration classes
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement('PRAGMA journal_mode=WAL');
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'airo_platform.sqlite'));

    if (Platform.isAndroid) {
      applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    
    // SQLite cache settings
    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}
''')

# Repositories / Transactions Implementation
create_file(f'{base}/repositories/default_repository_factory.dart', '''import '../contracts/repository_factory.dart';

class DefaultRepositoryFactory implements RepositoryFactory {
  final Map<Type, dynamic Function()> _builders = {};
  final Map<Type, dynamic> _instances = {};

  @override
  void register<T>(T Function() builder) {
    if (_builders.containsKey(T)) {
      throw StateError('Repository $T is already registered.');
    }
    _builders[T] = builder;
  }

  @override
  T get<T>() {
    if (_instances.containsKey(T)) {
      return _instances[T] as T;
    }
    final builder = _builders[T];
    if (builder == null) {
      throw StateError('Repository $T not found. Ensure it was registered during bootstrap.');
    }
    final instance = builder();
    _instances[T] = instance;
    return instance as T;
  }
}
''')

create_file(f'{base}/transactions/drift_transaction_manager.dart', '''import '../contracts/transaction_manager.dart';
import '../drift/app_database.dart';

class DriftTransactionManager implements TransactionManager {
  final AppDatabase _db;

  DriftTransactionManager(this._db);

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    return await _db.transaction(() async {
      return await action();
    });
  }
}
''')

create_file(f'{base}/api/drift_storage_service.dart', '''import 'package:platform_core/platform_core.dart';
import '../contracts/storage_service.dart';
import '../contracts/database_health_checker.dart';
import '../drift/app_database.dart';
import 'package:drift/drift.dart';
import 'dart:io';

class DriftStorageService implements StorageService {
  final AppDatabase _db;

  DriftStorageService(this._db);

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
''')

# Bootstrap
create_file(f'{base}/bootstrap/storage_bootstrap_task.dart', '''import 'package:platform_core/platform_core.dart';
import '../contracts/storage_service.dart';

class StorageBootstrapTask implements BootstrapTask {
  final StorageService _storageService;

  StorageBootstrapTask(this._storageService);

  @override
  String get name => 'PlatformStorage';

  @override
  BootstrapPhase get phase => BootstrapPhase.storage;

  @override
  Future<BootstrapResult> execute(BootstrapContext context) async {
    try {
      await _storageService.initialize();
      return const BootstrapResult.success(BootstrapPhase.storage);
    } catch (e, stack) {
      return BootstrapResult.failure(BootstrapPhase.storage, e, stack);
    }
  }
}
''')

# Providers
create_file(f'{base}/providers/storage_providers.dart', '''import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import '../contracts/storage_service.dart';
import '../contracts/repository_factory.dart';
import '../contracts/transaction_manager.dart';
import '../drift/app_database.dart';
import '../api/drift_storage_service.dart';
import '../repositories/default_repository_factory.dart';
import '../transactions/drift_transaction_manager.dart';

// In tests we can override this to use NativeDatabase.memory()
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return DriftStorageService(ref.watch(appDatabaseProvider));
});

final repositoryFactoryProvider = Provider<RepositoryFactory>((ref) {
  return DefaultRepositoryFactory();
});

final transactionProvider = Provider<TransactionManager>((ref) {
  return DriftTransactionManager(ref.watch(appDatabaseProvider));
});
''')

# Export file
create_file('packages/platform_storage/lib/platform_storage.dart', '''library platform_storage;

export 'src/contracts/storage_service.dart';
export 'src/contracts/repository_factory.dart';
export 'src/contracts/transaction_manager.dart';
export 'src/contracts/database_migration.dart';
export 'src/contracts/database_health_checker.dart';
export 'src/contracts/database_backup_provider.dart';
export 'src/entities/audit_metadata.dart';
export 'src/converters/central_converters.dart';
export 'src/providers/storage_providers.dart';
export 'src/bootstrap/storage_bootstrap_task.dart';
''')

print("Created all platform_storage files.")
