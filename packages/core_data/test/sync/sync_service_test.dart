import 'dart:async';

import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryOutboxRepository outboxRepository;
  late _FakeConnectivityService connectivityService;
  late List<SyncOperation> processed;
  late SyncService syncService;

  setUp(() {
    outboxRepository = InMemoryOutboxRepository();
    connectivityService = _FakeConnectivityService();
    processed = <SyncOperation>[];
    syncService = SyncService(
      outboxRepository: outboxRepository,
      connectivityService: connectivityService,
      onSyncOperation: (operation) async {
        processed.add(operation);
        return true;
      },
    );
  });

  tearDown(() {
    syncService.dispose();
    connectivityService.dispose();
  });

  test(
    'queueOperation triggers immediate sync for high-priority work when online',
    () async {
      final result = await syncService.queueOperation(
        entityType: 'transaction',
        entityId: '1',
        operationType: SyncOperationType.create,
        payload: '{"amount":42}',
        priority: SyncPriority.high,
      );

      await Future<void>.delayed(Duration.zero);

      expect(result.isSuccess, isTrue);
      expect(processed.map((operation) => operation.id), [result.value.id]);
      expect(await syncService.getPendingCount(), 0);
      expect(syncService.status, isA<SyncCompleted>());
    },
  );

  test('processOutbox is a no-op while offline', () async {
    connectivityService.connected = false;
    await outboxRepository.add(_operation(id: 'offline-op'));

    await syncService.processOutbox();

    expect(processed, isEmpty);
    expect(await syncService.getPendingCount(), 1);
    expect(syncService.status, isA<SyncIdle>());
  });

  test(
    'processOutbox records failures when sync callback returns false',
    () async {
      syncService = SyncService(
        outboxRepository: outboxRepository,
        connectivityService: connectivityService,
        onSyncOperation: (_) async => false,
      );

      await outboxRepository.add(_operation(id: 'failing-op'));
      await syncService.processOutbox();

      expect(syncService.status, isA<SyncCompleted>());
      final status = syncService.status as SyncCompleted;
      expect(status.synced, 0);
      expect(status.failed, 1);

      final pending = await outboxRepository.getPending();
      expect(pending.value.single.retryCount, 1);
      expect(pending.value.single.lastError, 'Sync failed');
    },
  );

  test('connectivity change to online triggers processing', () async {
    await outboxRepository.add(_operation(id: 'connectivity-op'));
    syncService.start(interval: const Duration(hours: 1));

    connectivityService.emit(false);
    await Future<void>.delayed(Duration.zero);
    expect(processed, isEmpty);

    connectivityService.emit(true);
    await Future<void>.delayed(Duration.zero);

    expect(processed.map((operation) => operation.id), ['connectivity-op']);
  });

  test('concurrent processOutbox calls do not duplicate work', () async {
    final gate = Completer<void>();
    final started = Completer<void>();
    syncService = SyncService(
      outboxRepository: outboxRepository,
      connectivityService: connectivityService,
      onSyncOperation: (operation) async {
        processed.add(operation);
        started.complete();
        await gate.future;
        return true;
      },
    );

    await outboxRepository.add(_operation(id: 'concurrent-op'));

    final first = syncService.processOutbox();
    await started.future;
    final second = syncService.processOutbox();
    gate.complete();
    await Future.wait([first, second]);

    expect(processed.map((operation) => operation.id), ['concurrent-op']);
  });

  test('cancel stops periodic registration from continuing', () async {
    syncService.start(interval: const Duration(milliseconds: 10));
    syncService.stop();

    await outboxRepository.add(_operation(id: 'stopped-op'));
    await Future<void>.delayed(const Duration(milliseconds: 25));

    expect(processed, isEmpty);
  });
}

SyncOperation _operation({required String id}) {
  return SyncOperation(
    id: id,
    entityType: 'meeting',
    entityId: id,
    operationType: SyncOperationType.update,
    payload: '{"id":"$id"}',
    createdAt: DateTime.utc(2026, 6, 29),
  );
}

class _FakeConnectivityService extends ConnectivityService {
  _FakeConnectivityService() : super();

  final _controller = StreamController<bool>.broadcast();
  bool connected = true;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  Future<bool> get isConnected async => connected;

  void emit(bool value) {
    connected = value;
    _controller.add(value);
  }

  void dispose() {
    _controller.close();
  }
}
