import 'package:flutter_test/flutter_test.dart';
import 'package:core_data/core_data.dart';

void main() {
  group('SyncStatus', () {
    test('idle factory creates idle status', () {
      const status = SyncStatus.idle();
      expect(status.isSyncing, isFalse);
      expect(status.hasError, isFalse);
    });

    test('syncing factory creates syncing status', () {
      const status = SyncStatus.syncing(progress: 5, total: 10);
      expect(status.isSyncing, isTrue);
      expect(status.hasError, isFalse);
    });

    test('completed factory creates completed status', () {
      const status = SyncStatus.completed(synced: 10, failed: 0);
      expect(status.isSyncing, isFalse);
      expect(status.hasError, isFalse);
    });

    test('error factory creates error status', () {
      const status = SyncStatus.error('Network error');
      expect(status.isSyncing, isFalse);
      expect(status.hasError, isTrue);
    });

    test('SyncSyncing progressPercent calculates correctly', () {
      const syncing = SyncSyncing(progress: 3, total: 10);
      expect(syncing.progressPercent, 0.3);
    });

    test('SyncCompleted hasFailures returns true when failures exist', () {
      const withFailures = SyncCompleted(synced: 5, failed: 2);
      const noFailures = SyncCompleted(synced: 5, failed: 0);
      expect(withFailures.hasFailures, isTrue);
      expect(noFailures.hasFailures, isFalse);
    });
  });

  group('SyncConfig', () {
    test('default values are correct', () {
      const config = SyncConfig();
      expect(config.syncInterval, const Duration(minutes: 5));
      expect(config.maxRetries, 5);
      expect(config.enableBackgroundSync, isTrue);
      expect(config.syncOnConnectivityChange, isTrue);
      expect(config.batchSize, 10);
      expect(config.defaultConflictResolution, ConflictResolution.keepLocal);
    });

    test('batterySaver config has reduced sync frequency', () {
      const config = SyncConfig.batterySaver;
      expect(config.syncInterval, const Duration(minutes: 15));
      expect(config.enableBackgroundSync, isFalse);
      expect(config.batchSize, 5);
    });
  });

  group('ConflictResolution', () {
    test('all resolution strategies are defined', () {
      expect(ConflictResolution.values, contains(ConflictResolution.keepLocal));
      expect(
        ConflictResolution.values,
        contains(ConflictResolution.keepRemote),
      );
      expect(ConflictResolution.values, contains(ConflictResolution.merge));
      expect(ConflictResolution.values, contains(ConflictResolution.skip));
      expect(ConflictResolution.values, contains(ConflictResolution.retry));
    });
  });

  group('SyncOperation', () {
    test('creates with required fields', () {
      final operation = SyncOperation(
        id: 'op-1',
        entityType: 'transaction',
        entityId: 'txn-123',
        operationType: SyncOperationType.create,
        payload: '{"amount": 100}',
        createdAt: DateTime(2024, 1, 1),
      );
      expect(operation.id, 'op-1');
      expect(operation.entityType, 'transaction');
      expect(operation.retryCount, 0);
      expect(operation.status, SyncOperationStatus.pending);
    });

    test('canRetry returns true when under max retries', () {
      final operation = SyncOperation(
        id: 'op-1',
        entityType: 'transaction',
        entityId: 'txn-123',
        operationType: SyncOperationType.update,
        payload: '{}',
        createdAt: DateTime.now(),
        retryCount: 2,
      );
      expect(operation.canRetry, isTrue);
    });

    test('canRetry returns false when at max retries', () {
      final operation = SyncOperation(
        id: 'op-1',
        entityType: 'transaction',
        entityId: 'txn-123',
        operationType: SyncOperationType.update,
        payload: '{}',
        createdAt: DateTime.now(),
        retryCount: 5,
      );
      expect(operation.canRetry, isFalse);
    });

    test('retryDelay uses exponential backoff', () {
      final op0 = SyncOperation(
        id: 'op',
        entityType: 't',
        entityId: 'e',
        operationType: SyncOperationType.create,
        payload: '{}',
        createdAt: DateTime.now(),
        retryCount: 0,
      );
      final op2 = op0.copyWith(retryCount: 2);
      final op4 = op0.copyWith(retryCount: 4);

      expect(op0.retryDelay, const Duration(seconds: 1));
      expect(op2.retryDelay, const Duration(seconds: 4));
      expect(op4.retryDelay, const Duration(seconds: 16));
    });

    test('copyWith creates modified copy', () {
      final original = SyncOperation(
        id: 'op-1',
        entityType: 'transaction',
        entityId: 'txn-123',
        operationType: SyncOperationType.create,
        payload: '{}',
        createdAt: DateTime.now(),
      );
      final modified = original.copyWith(
        status: SyncOperationStatus.completed,
        retryCount: 3,
      );
      expect(modified.status, SyncOperationStatus.completed);
      expect(modified.retryCount, 3);
      expect(modified.id, original.id);
    });
  });

  group('SyncOperationType', () {
    test('all operation types are defined', () {
      expect(SyncOperationType.values, contains(SyncOperationType.create));
      expect(SyncOperationType.values, contains(SyncOperationType.update));
      expect(SyncOperationType.values, contains(SyncOperationType.delete));
    });
  });

  group('SyncOperationStatus', () {
    test('all statuses are defined', () {
      expect(SyncOperationStatus.values, contains(SyncOperationStatus.pending));
      expect(
        SyncOperationStatus.values,
        contains(SyncOperationStatus.inProgress),
      );
      expect(
        SyncOperationStatus.values,
        contains(SyncOperationStatus.completed),
      );
      expect(SyncOperationStatus.values, contains(SyncOperationStatus.failed));
      expect(
        SyncOperationStatus.values,
        contains(SyncOperationStatus.cancelled),
      );
    });
  });

  group('SyncPriority', () {
    test('all priorities are defined', () {
      expect(SyncPriority.values, contains(SyncPriority.low));
      expect(SyncPriority.values, contains(SyncPriority.normal));
      expect(SyncPriority.values, contains(SyncPriority.high));
      expect(SyncPriority.values, contains(SyncPriority.critical));
    });
  });

  group('InMemorySecureStore', () {
    late InMemorySecureStore store;

    setUp(() {
      store = InMemorySecureStore();
    });

    test('write and read work correctly', () async {
      await store.write(key: 'key1', value: 'value1');
      final result = await store.read(key: 'key1');
      expect(result, 'value1');
    });

    test('read returns null for non-existent key', () async {
      final result = await store.read(key: 'non-existent');
      expect(result, isNull);
    });

    test('delete removes key', () async {
      await store.write(key: 'key1', value: 'value1');
      await store.delete(key: 'key1');
      final result = await store.read(key: 'key1');
      expect(result, isNull);
    });

    test('deleteAll clears all keys', () async {
      await store.write(key: 'key1', value: 'value1');
      await store.write(key: 'key2', value: 'value2');
      await store.deleteAll();
      final key1 = await store.read(key: 'key1');
      final key2 = await store.read(key: 'key2');
      expect(key1, isNull);
      expect(key2, isNull);
    });

    test('containsKey returns correct value', () async {
      await store.write(key: 'key1', value: 'value1');
      final exists = await store.containsKey(key: 'key1');
      final notExists = await store.containsKey(key: 'key2');
      expect(exists, isTrue);
      expect(notExists, isFalse);
    });
  });

  group('KeyDerivation', () {
    test('generateKey creates random key', () {
      final key1 = KeyDerivation.generateKey();
      final key2 = KeyDerivation.generateKey();
      expect(key1, isNotEmpty);
      expect(key2, isNotEmpty);
      expect(key1, isNot(equals(key2)));
    });

    test('generateKey creates key of specified length encoded', () {
      final key = KeyDerivation.generateKey(length: 16);
      expect(key, isNotEmpty);
    });

    test('deriveFromPassphrase creates deterministic key', () {
      final key1 = KeyDerivation.deriveFromPassphrase('password123');
      final key2 = KeyDerivation.deriveFromPassphrase('password123');
      expect(key1, equals(key2));
    });

    test('deriveFromPassphrase with salt creates different key', () {
      final key1 = KeyDerivation.deriveFromPassphrase(
        'password',
        salt: 'salt1',
      );
      final key2 = KeyDerivation.deriveFromPassphrase(
        'password',
        salt: 'salt2',
      );
      expect(key1, isNot(equals(key2)));
    });
  });

  group('EncryptionService', () {
    late EncryptionService service;
    late InMemorySecureStore store;

    setUp(() {
      store = InMemorySecureStore();
      service = EncryptionService(secureStore: store);
    });

    test('getDatabaseKey generates and returns key', () async {
      final key = await service.getDatabaseKey();
      expect(key, isNotEmpty);
    });

    test('getDatabaseKey returns same key on subsequent calls', () async {
      final key1 = await service.getDatabaseKey();
      final key2 = await service.getDatabaseKey();
      expect(key1, equals(key2));
    });

    test('rotateDatabaseKey creates new key', () async {
      final key1 = await service.getDatabaseKey();
      final key2 = await service.rotateDatabaseKey();
      expect(key1, isNot(equals(key2)));
    });

    test('hasDatabaseKey returns false initially', () async {
      final hasKey = await service.hasDatabaseKey();
      expect(hasKey, isFalse);
    });

    test('hasDatabaseKey returns true after key generation', () async {
      await service.getDatabaseKey();
      final hasKey = await service.hasDatabaseKey();
      expect(hasKey, isTrue);
    });

    test('deleteAllKeys removes keys', () async {
      await service.getDatabaseKey();
      await service.deleteAllKeys();
      final hasKey = await service.hasDatabaseKey();
      expect(hasKey, isFalse);
    });
  });

  group('EncryptionConfig', () {
    test('production config enables encryption', () {
      const config = EncryptionConfig.production;
      expect(config.enableDatabaseEncryption, isTrue);
      expect(config.enableAtRestEncryption, isTrue);
      expect(config.keyRotationDays, 90);
    });

    test('development config disables encryption', () {
      const config = EncryptionConfig.development;
      expect(config.enableDatabaseEncryption, isFalse);
      expect(config.enableAtRestEncryption, isFalse);
      expect(config.keyRotationDays, 0);
    });
  });
}
