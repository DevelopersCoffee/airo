import 'package:test/test.dart';
import 'package:core_data/core_data.dart';

void main() {
  group('DioClient', () {
    test('can be instantiated with default values', () {
      final client = DioClient();
      expect(client.dio, isNotNull);
    });

    test('can be instantiated with custom values', () {
      final client = DioClient(
        baseUrl: 'https://api.example.com',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 15),
      );
      expect(client.dio.options.baseUrl, 'https://api.example.com');
      expect(client.dio.options.connectTimeout, const Duration(seconds: 5));
      expect(client.dio.options.receiveTimeout, const Duration(seconds: 15));
    });

    test('setAuthToken adds authorization header', () {
      final client = DioClient();
      client.setAuthToken('test-token');
      expect(client.dio.options.headers['Authorization'], 'Bearer test-token');
    });

    test('clearAuthToken removes authorization header', () {
      final client = DioClient();
      client.setAuthToken('test-token');
      client.clearAuthToken();
      expect(client.dio.options.headers['Authorization'], isNull);
    });

    test('can be instantiated with security config', () {
      final client = DioClient(securityConfig: HttpSecurityConfig.production);
      expect(client.securityConfig.enforceHttps, isTrue);
      expect(client.securityConfig.enableCertificatePinning, isTrue);
    });

    test('development security config is less strict', () {
      const config = HttpSecurityConfig.development;
      expect(config.enforceHttps, isFalse);
      expect(config.enableCertificatePinning, isFalse);
      expect(config.allowSelfSigned, isTrue);
    });

    test('production security config is strict', () {
      const config = HttpSecurityConfig.production;
      expect(config.enforceHttps, isTrue);
      expect(config.enableCertificatePinning, isTrue);
      expect(config.allowSelfSigned, isFalse);
    });
  });

  group('InMemoryCacheRepository', () {
    late InMemoryCacheRepository<String, String> cache;

    setUp(() {
      cache = InMemoryCacheRepository<String, String>();
    });

    test('put and get work correctly', () async {
      await cache.put('key1', 'value1');
      final result = await cache.get('key1');
      expect(result, 'value1');
    });

    test('get returns null for non-existent key', () async {
      final result = await cache.get('non-existent');
      expect(result, isNull);
    });

    test('getAll returns all values', () async {
      await cache.put('key1', 'value1');
      await cache.put('key2', 'value2');
      final all = await cache.getAll();
      expect(all, containsAll(['value1', 'value2']));
    });

    test('delete removes item', () async {
      await cache.put('key1', 'value1');
      await cache.delete('key1');
      final result = await cache.get('key1');
      expect(result, isNull);
    });

    test('clear removes all items', () async {
      await cache.put('key1', 'value1');
      await cache.put('key2', 'value2');
      await cache.clear();
      final all = await cache.getAll();
      expect(all, isEmpty);
    });

    test('exists returns true for existing key', () async {
      await cache.put('key1', 'value1');
      final exists = await cache.exists('key1');
      expect(exists, isTrue);
    });

    test('exists returns false for non-existent key', () async {
      final exists = await cache.exists('non-existent');
      expect(exists, isFalse);
    });
  });

  group('Repository interfaces', () {
    test('Repository interface is defined', () {
      // Just verify the interface exists and can be referenced
      expect(Repository, isNotNull);
    });

    test('CacheRepository interface is defined', () {
      expect(CacheRepository, isNotNull);
    });

    test('PaginatedRepository interface is defined', () {
      expect(PaginatedRepository, isNotNull);
    });

    test('StreamRepository interface is defined', () {
      expect(StreamRepository, isNotNull);
    });
  });

  group('SyncStatus', () {
    test('SyncStatus enum has all expected values', () {
      expect(SyncStatus.values, contains(SyncStatus.synced));
      expect(SyncStatus.values, contains(SyncStatus.pending));
      expect(SyncStatus.values, contains(SyncStatus.syncing));
      expect(SyncStatus.values, contains(SyncStatus.failed));
      expect(SyncStatus.values, contains(SyncStatus.conflict));
    });
  });

  group('SyncMetadata', () {
    test('default values are correct', () {
      const metadata = SyncMetadata();
      expect(metadata.status, SyncStatus.pending);
      expect(metadata.retryCount, 0);
      expect(metadata.version, 1);
      expect(metadata.needsSync, isTrue);
    });

    test('markSyncing updates status', () {
      const metadata = SyncMetadata();
      final syncing = metadata.markSyncing();
      expect(syncing.status, SyncStatus.syncing);
    });

    test('markSynced updates status and timestamp', () {
      const metadata = SyncMetadata();
      final synced = metadata.markSynced(remoteId: 'remote-123');
      expect(synced.status, SyncStatus.synced);
      expect(synced.remoteId, 'remote-123');
      expect(synced.lastSyncedAt, isNotNull);
      expect(synced.retryCount, 0);
    });

    test('markFailed updates status and increments retry', () {
      const metadata = SyncMetadata();
      final failed = metadata.markFailed('Network error');
      expect(failed.status, SyncStatus.failed);
      expect(failed.errorMessage, 'Network error');
      expect(failed.retryCount, 1);
    });

    test('markPending updates status and version', () {
      const metadata = SyncMetadata(status: SyncStatus.synced, version: 1);
      final pending = metadata.markPending();
      expect(pending.status, SyncStatus.pending);
      expect(pending.version, 2);
      expect(pending.lastModifiedAt, isNotNull);
    });

    test('toJson and fromJson roundtrip', () {
      final metadata = SyncMetadata(
        status: SyncStatus.synced,
        lastSyncedAt: DateTime(2024, 1, 1),
        remoteId: 'remote-123',
        version: 5,
      );
      final json = metadata.toJson();
      final restored = SyncMetadata.fromJson(json);
      expect(restored.status, metadata.status);
      expect(restored.remoteId, metadata.remoteId);
      expect(restored.version, metadata.version);
    });

    test('needsSync returns true for pending and failed', () {
      const pending = SyncMetadata(status: SyncStatus.pending);
      const failed = SyncMetadata(status: SyncStatus.failed);
      const synced = SyncMetadata(status: SyncStatus.synced);

      expect(pending.needsSync, isTrue);
      expect(failed.needsSync, isTrue);
      expect(synced.needsSync, isFalse);
    });

    test('hasError returns true when failed with message', () {
      const failed = SyncMetadata(
        status: SyncStatus.failed,
        errorMessage: 'Error',
      );
      const failedNoMessage = SyncMetadata(status: SyncStatus.failed);

      expect(failed.hasError, isTrue);
      expect(failedNoMessage.hasError, isFalse);
    });
  });

  group('SyncResult', () {
    test('default values are correct', () {
      const result = SyncResult();
      expect(result.synced, 0);
      expect(result.failed, 0);
      expect(result.conflicts, 0);
      expect(result.isSuccess, isTrue);
      expect(result.hasErrors, isFalse);
    });

    test('hasErrors returns true when failed or conflicts', () {
      const withFailed = SyncResult(synced: 5, failed: 1);
      const withConflicts = SyncResult(synced: 5, conflicts: 1);
      const success = SyncResult(synced: 5);

      expect(withFailed.hasErrors, isTrue);
      expect(withConflicts.hasErrors, isTrue);
      expect(success.hasErrors, isFalse);
    });
  });

  group('SyncSummary', () {
    test('syncProgress calculates correctly', () {
      const summary = SyncSummary(total: 10, synced: 5);
      expect(summary.syncProgress, 0.5);
    });

    test('syncProgress returns 1.0 when total is 0', () {
      const summary = SyncSummary(total: 0, synced: 0);
      expect(summary.syncProgress, 1.0);
    });

    test('isFullySynced returns true when no pending/failed/conflicts', () {
      const synced = SyncSummary(total: 10, synced: 10);
      const pending = SyncSummary(total: 10, synced: 5, pending: 5);

      expect(synced.isFullySynced, isTrue);
      expect(pending.isFullySynced, isFalse);
    });
  });

  group('SyncConfig', () {
    test('default values are correct', () {
      const config = SyncConfig();
      expect(config.syncInterval, const Duration(minutes: 5));
      expect(config.maxRetries, 3);
      expect(config.autoSync, isTrue);
      expect(config.syncOnStart, isTrue);
      expect(config.batchSize, 50);
    });
  });

  group('Offline interfaces', () {
    test('OfflineRepository interface is defined', () {
      expect(OfflineRepository, isNotNull);
    });

    test('RemoteRepository interface is defined', () {
      expect(RemoteRepository, isNotNull);
    });

    test('SyncableRepository interface is defined', () {
      expect(SyncableRepository, isNotNull);
    });

    test('SyncEngine interface is defined', () {
      expect(SyncEngine, isNotNull);
    });

    test('ConflictResolver interface is defined', () {
      expect(ConflictResolver, isNotNull);
    });

    test('ConnectivityChecker interface is defined', () {
      expect(ConnectivityChecker, isNotNull);
    });
  });

  group('InMemorySecureStorage', () {
    late InMemorySecureStorage storage;

    setUp(() {
      storage = InMemorySecureStorage();
    });

    test('write and read work correctly', () async {
      final writeResult = await storage.write('key1', 'value1');
      expect(writeResult.isOk, isTrue);

      final readResult = await storage.read('key1');
      expect(readResult.isOk, isTrue);
      expect(readResult.getOrNull(), 'value1');
    });

    test('read returns null for non-existent key', () async {
      final result = await storage.read('non-existent');
      expect(result.isOk, isTrue);
      expect(result.getOrNull(), isNull);
    });

    test('delete removes key', () async {
      await storage.write('key1', 'value1');
      await storage.delete('key1');
      final result = await storage.read('key1');
      expect(result.getOrNull(), isNull);
    });

    test('deleteAll clears all keys', () async {
      await storage.write('key1', 'value1');
      await storage.write('key2', 'value2');
      await storage.deleteAll();
      final keys = await storage.getAllKeys();
      expect(keys.getOrNull(), isEmpty);
    });

    test('containsKey returns correct value', () async {
      await storage.write('key1', 'value1');
      final exists = await storage.containsKey('key1');
      final notExists = await storage.containsKey('key2');
      expect(exists.getOrNull(), isTrue);
      expect(notExists.getOrNull(), isFalse);
    });

    test('getAllKeys returns all keys', () async {
      await storage.write('key1', 'value1');
      await storage.write('key2', 'value2');
      final keys = await storage.getAllKeys();
      expect(keys.getOrNull(), containsAll(['key1', 'key2']));
    });
  });

  group('InMemoryEncryptionKeyManager', () {
    late InMemoryEncryptionKeyManager keyManager;

    setUp(() {
      keyManager = InMemoryEncryptionKeyManager();
    });

    test('getDatabaseKey returns 32-byte key', () async {
      final result = await keyManager.getDatabaseKey();
      expect(result.isOk, isTrue);
      expect(result.getOrNull()?.length, 32);
    });

    test('getDatabaseKey returns same key on subsequent calls', () async {
      final key1 = await keyManager.getDatabaseKey();
      final key2 = await keyManager.getDatabaseKey();
      expect(key1.getOrNull(), equals(key2.getOrNull()));
    });

    test('rotateKey generates new key', () async {
      final key1 = await keyManager.getDatabaseKey();
      await keyManager.rotateKey();
      final key2 = await keyManager.getDatabaseKey();
      expect(key1.getOrNull(), isNot(equals(key2.getOrNull())));
    });

    test('isEncryptionAvailable returns true', () async {
      final available = await keyManager.isEncryptionAvailable();
      expect(available, isTrue);
    });

    test('clearKeys clears the key', () async {
      await keyManager.getDatabaseKey();
      await keyManager.clearKeys();
      // After clear, a new key should be generated
      final key1 = await keyManager.getDatabaseKey();
      await keyManager.clearKeys();
      final key2 = await keyManager.getDatabaseKey();
      expect(key1.getOrNull(), isNot(equals(key2.getOrNull())));
    });
  });

  group('InMemoryEncryptedDatabase', () {
    late InMemoryEncryptedDatabase db;

    setUp(() async {
      db = InMemoryEncryptedDatabase();
      await db.initialize(
        const EncryptedDatabaseConfig(databaseName: 'test.db'),
      );
    });

    test('initialize opens database', () async {
      expect(db.isOpen, isTrue);
      expect(db.path, 'test.db');
    });

    test('insert and query work correctly', () async {
      final insertResult = await db.insert('users', {
        'name': 'John',
        'age': 30,
      });
      expect(insertResult.isOk, isTrue);
      expect(insertResult.getOrNull(), greaterThan(0));

      final queryResult = await db.query('users');
      expect(queryResult.isOk, isTrue);
      expect(queryResult.getOrNull()?.length, 1);
      expect(queryResult.getOrNull()?.first['name'], 'John');
    });

    test('delete clears table', () async {
      await db.insert('users', {'name': 'John'});
      await db.insert('users', {'name': 'Jane'});
      final deleteResult = await db.delete('users');
      expect(deleteResult.isOk, isTrue);
      expect(deleteResult.getOrNull(), 2);

      final queryResult = await db.query('users');
      expect(queryResult.getOrNull(), isEmpty);
    });

    test('close closes database', () async {
      await db.close();
      expect(db.isOpen, isFalse);
    });

    test('transaction executes action', () async {
      final result = await db.transaction((txn) async {
        await txn.insert('users', {'name': 'John'});
        return 'done';
      });
      expect(result.isOk, isTrue);
      expect(result.getOrNull(), 'done');
    });
  });
}
