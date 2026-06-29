import 'dart:async';

import 'package:airo_app/core/sync/background_sync_service.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.airo.superapp/background_sync');

  late _FakeConnectivityService connectivity;
  late InMemoryOutboxRepository outboxRepository;
  late List<SyncOperation> syncedOperations;
  late SyncService syncService;
  late BackgroundSyncService backgroundSyncService;
  late TestDefaultBinaryMessenger messenger;

  setUp(() {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    connectivity = _FakeConnectivityService();
    outboxRepository = InMemoryOutboxRepository();
    syncedOperations = <SyncOperation>[];
    syncService = SyncService(
      outboxRepository: outboxRepository,
      connectivityService: connectivity,
      onSyncOperation: (operation) async {
        syncedOperations.add(operation);
        return true;
      },
    );
    backgroundSyncService = BackgroundSyncService(syncService: syncService);
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    syncService.dispose();
    connectivity.dispose();
  });

  test(
    'register sends clamped platform arguments and ignores duplicates',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });

      final first = await backgroundSyncService.register(
        interval: const Duration(minutes: 5),
        requiresNetwork: false,
        requiresCharging: true,
      );
      final second = await backgroundSyncService.register();

      expect(first, isTrue);
      expect(second, isTrue);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'register');
      expect(calls.single.arguments, {
        'intervalMinutes': 15,
        'requiresNetwork': false,
        'requiresCharging': true,
        'taskName': 'airo_sync',
      });
    },
  );

  test(
    'cancel is a no-op until registered and clears registration state',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });

      await backgroundSyncService.cancel();
      expect(calls, isEmpty);

      await backgroundSyncService.register();
      await backgroundSyncService.cancel();
      await backgroundSyncService.register();

      expect(calls.map((call) => call.method), [
        'register',
        'cancel',
        'register',
      ]);
    },
  );

  test('register returns false when the platform throws', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unsupported', message: 'No scheduler');
    });

    final result = await backgroundSyncService.register();

    expect(result, isFalse);
  });

  test('syncNow delegates to SyncService.processOutbox', () async {
    await outboxRepository.add(
      SyncOperation(
        id: 'txn-1',
        entityType: 'transaction',
        entityId: '1',
        operationType: SyncOperationType.create,
        payload: '{"amount": 10}',
        createdAt: DateTime.utc(2026, 6, 29),
      ),
    );

    await backgroundSyncService.syncNow();

    expect(syncedOperations.map((operation) => operation.id), ['txn-1']);
    expect(backgroundSyncService.status, isA<SyncCompleted>());
    final status = backgroundSyncService.status as SyncCompleted;
    expect(status.synced, 1);
    expect(status.failed, 0);
  });

  test('statusStream mirrors the sync service stream', () async {
    final observed = <SyncStatus>[];
    final subscription = backgroundSyncService.statusStream.listen(
      observed.add,
    );

    await outboxRepository.add(
      SyncOperation(
        id: 'txn-2',
        entityType: 'transaction',
        entityId: '2',
        operationType: SyncOperationType.update,
        payload: '{"amount": 25}',
        createdAt: DateTime.utc(2026, 6, 29),
      ),
    );

    await backgroundSyncService.syncNow();
    await Future<void>.delayed(Duration.zero);

    expect(observed.first, isA<SyncSyncing>());
    expect(observed.last, isA<SyncCompleted>());
    final status = observed.last as SyncCompleted;
    expect(status.synced, 1);
    expect(status.failed, 0);
    await subscription.cancel();
  });

  test('getPendingCount proxies through the sync service', () async {
    await outboxRepository.add(
      SyncOperation(
        id: 'txn-3',
        entityType: 'transaction',
        entityId: '3',
        operationType: SyncOperationType.delete,
        payload: '{}',
        createdAt: DateTime.utc(2026, 6, 29),
      ),
    );

    final pending = await backgroundSyncService.getPendingCount();

    expect(pending, 1);
  });

  test('background sync config battery saver favors charging and slower cadence', () {
    expect(BackgroundSyncConfig.batterySaver.intervalMinutes, 60);
    expect(BackgroundSyncConfig.batterySaver.requiresCharging, isTrue);
    expect(BackgroundSyncConfig.batterySaver.requiresNetwork, isTrue);
  });
}

class _FakeConnectivityService extends ConnectivityService {
  _FakeConnectivityService() : super();

  final _controller = StreamController<bool>.broadcast();
  bool _connected = true;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  Future<bool> get isConnected async => _connected;

  void emit(bool connected) {
    _connected = connected;
    _controller.add(connected);
  }

  void dispose() {
    _controller.close();
  }
}
