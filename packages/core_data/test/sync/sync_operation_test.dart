import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncOperation', () {
    test('creates with required fields', () {
      final now = DateTime.now();
      final operation = SyncOperation(
        id: 'op-1',
        entityType: 'transaction',
        entityId: 'tx-123',
        operationType: SyncOperationType.create,
        payload: '{"amount": 100}',
        createdAt: now,
      );

      expect(operation.id, 'op-1');
      expect(operation.entityType, 'transaction');
      expect(operation.entityId, 'tx-123');
      expect(operation.operationType, SyncOperationType.create);
      expect(operation.retryCount, 0);
      expect(operation.status, SyncOperationStatus.pending);
    });

    test('canRetry returns true when under max retries', () {
      const operation = SyncOperation(
        id: 'op-1',
        entityType: 'test',
        entityId: 'e-1',
        operationType: SyncOperationType.create,
        payload: '{}',
        createdAt: null,
        retryCount: 3,
      );

      expect(operation.canRetry, isTrue);
    });

    test('canRetry returns false when at max retries', () {
      const operation = SyncOperation(
        id: 'op-1',
        entityType: 'test',
        entityId: 'e-1',
        operationType: SyncOperationType.create,
        payload: '{}',
        createdAt: null,
        retryCount: 5,
      );

      expect(operation.canRetry, isFalse);
    });

    test('retryDelay increases exponentially', () {
      SyncOperation createWithRetries(int count) => SyncOperation(
            id: 'op-1',
            entityType: 'test',
            entityId: 'e-1',
            operationType: SyncOperationType.create,
            payload: '{}',
            createdAt: DateTime.now(),
            retryCount: count,
          );

      expect(createWithRetries(0).retryDelay, const Duration(seconds: 1));
      expect(createWithRetries(1).retryDelay, const Duration(seconds: 2));
      expect(createWithRetries(2).retryDelay, const Duration(seconds: 4));
      expect(createWithRetries(3).retryDelay, const Duration(seconds: 8));
      expect(createWithRetries(4).retryDelay, const Duration(seconds: 16));
    });

    test('copyWith updates specified fields', () {
      final original = SyncOperation(
        id: 'op-1',
        entityType: 'test',
        entityId: 'e-1',
        operationType: SyncOperationType.create,
        payload: '{}',
        createdAt: DateTime.now(),
      );

      final updated = original.copyWith(
        retryCount: 2,
        status: SyncOperationStatus.failed,
        lastError: 'Network error',
      );

      expect(updated.id, original.id);
      expect(updated.retryCount, 2);
      expect(updated.status, SyncOperationStatus.failed);
      expect(updated.lastError, 'Network error');
    });
  });

  group('InMemoryOutboxRepository', () {
    late InMemoryOutboxRepository repository;

    setUp(() {
      repository = InMemoryOutboxRepository();
    });

    test('add and getPending', () async {
      final operation = SyncOperation(
        id: 'op-1',
        entityType: 'transaction',
        entityId: 'tx-1',
        operationType: SyncOperationType.create,
        payload: '{}',
        createdAt: DateTime.now(),
      );

      await repository.add(operation);
      final result = await repository.getPending();

      expect(result.isSuccess, isTrue);
      expect(result.value, hasLength(1));
      expect(result.value.first.id, 'op-1');
    });

    test('getPending returns sorted by priority', () async {
      final lowPriority = SyncOperation(
        id: 'op-low',
        entityType: 'test',
        entityId: 'e-1',
        operationType: SyncOperationType.create,
        payload: '{}',
        createdAt: DateTime.now(),
        priority: SyncPriority.low,
      );

      final highPriority = SyncOperation(
        id: 'op-high',
        entityType: 'test',
        entityId: 'e-2',
        operationType: SyncOperationType.create,
        payload: '{}',
        createdAt: DateTime.now(),
        priority: SyncPriority.high,
      );

      await repository.add(lowPriority);
      await repository.add(highPriority);

      final result = await repository.getPending();

      expect(result.value.first.id, 'op-high');
      expect(result.value.last.id, 'op-low');
    });

    test('markCompleted changes status', () async {
      final operation = SyncOperation(
        id: 'op-1',
        entityType: 'test',
        entityId: 'e-1',
        operationType: SyncOperationType.create,
        payload: '{}',
        createdAt: DateTime.now(),
      );

      await repository.add(operation);
      await repository.markCompleted('op-1');

      final pending = await repository.getPending();
      expect(pending.value, isEmpty);
    });

    test('recordAttempt increments retry count', () async {
      final operation = SyncOperation(
        id: 'op-1',
        entityType: 'test',
        entityId: 'e-1',
        operationType: SyncOperationType.create,
        payload: '{}',
        createdAt: DateTime.now(),
      );

      await repository.add(operation);
      final result = await repository.recordAttempt('op-1', error: 'Failed');

      expect(result.value.retryCount, 1);
      expect(result.value.lastError, 'Failed');
      expect(result.value.lastAttemptAt, isNotNull);
    });
  });
}

