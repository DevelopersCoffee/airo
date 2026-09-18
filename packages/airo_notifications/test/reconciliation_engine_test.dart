import 'package:airo_notifications/airo_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  late LocalAiroNotificationEngine engine;
  late List<MethodCall> methodCalls;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    methodCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
      methodCalls.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'areNotificationsEnabled':
          return true;
        case 'requestNotificationsPermission':
          return true;
        case 'zonedSchedule':
        case 'cancel':
          return null;
        default:
          return null;
      }
    });

    engine = LocalAiroNotificationEngine(
      alertStore: InMemoryAlertStore(),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('suppresses duplicate scheduling calls for identical semantic content', () async {
    final alert1 = AiroAlert(
      id: 'alert-1',
      title: 'Daily Water Intake',
      body: 'Drink a glass of water',
      scheduledAt: DateTime.now().add(const Duration(hours: 2)),
      repeatDaily: true,
      groupId: 'health',
    );

    final alert2 = AiroAlert(
      id: 'alert-2',
      title: 'Daily Water Intake',
      body: 'Drink a glass of water',
      scheduledAt: DateTime.now().add(const Duration(hours: 2)),
      repeatDaily: true,
      groupId: 'health',
    );

    final result1 = await engine.schedule(alert1);
    final result2 = await engine.schedule(alert2);

    expect(result2.id, result1.id);
    final stored = await engine.query(includeDelivered: true);
    expect(stored, hasLength(1));
  });

  test('reschedules existing alert when explicit idempotency ID matches', () async {
    final initial = AiroAlert(
      id: 'task-followup-100',
      title: 'Review PR',
      scheduledAt: DateTime.now().add(const Duration(hours: 1)),
    );

    await engine.schedule(initial);

    final updated = AiroAlert(
      id: 'task-followup-100',
      title: 'Review PR (Updated)',
      scheduledAt: DateTime.now().add(const Duration(hours: 3)),
    );

    final result = await engine.schedule(updated);
    expect(result.id, 'task-followup-100');

    final stored = await engine.query(includeDelivered: true);
    expect(stored, hasLength(1));
    expect(stored.first.title, 'Review PR (Updated)');
  });

  test('rejects past-time non-repeating alerts with ArgumentError', () async {
    final pastAlert = AiroAlert(
      id: 'past-1',
      title: 'Past Event',
      scheduledAt: DateTime.now().subtract(const Duration(minutes: 10)),
      repeatDaily: false,
    );

    expect(
      () => engine.schedule(pastAlert),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('throws NotificationPermissionDeniedException when OS permission is denied', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
      if (call.method == 'requestNotificationsPermission' || call.method == 'areNotificationsEnabled') {
        return false;
      }
      return true;
    });

    final alert = AiroAlert(
      id: 'perm-test',
      title: 'Reminder',
      scheduledAt: DateTime.now().add(const Duration(hours: 1)),
    );

    expect(
      () => engine.schedule(alert),
      throwsA(isA<NotificationPermissionDeniedException>()),
    );
  });

  test(
    'marks completion, cancels daily_until_done follow-ups, and stays idempotent -- '
    'without computing streaks/points itself (that is consumer-owned bookkeeping)',
    () async {
      final alert = AiroAlert(
        id: 'daily-task-1',
        title: 'Daily Exercise',
        scheduledAt: DateTime.now().add(const Duration(hours: 1)),
        repeatDaily: true,
        requiresCompletion: true,
        followUpPolicy: 'daily_until_done',
      );

      await engine.schedule(alert);
      final completed = await engine.markCompleted('daily-task-1');

      expect(completed, isNotNull);
      expect(completed!.status, AiroAlertStatus.completed);
      // The engine is a generic notification runtime: it never derives
      // streaks or points on its own. Those stay 0 unless a consumer
      // explicitly persists its own computed values via `persist()`.
      expect(completed.streakCount, 0);
      expect(completed.points, 0);
      expect(completed.completedDates, isEmpty);

      final cancelCallsAfterFirst = methodCalls
          .where((call) => call.method == 'cancel')
          .toList();
      expect(cancelCallsAfterFirst, hasLength(1));

      // A second markCompleted on an already-completed alert is a no-op: no
      // extra cancel call, same alert returned.
      final repeated = await engine.markCompleted('daily-task-1');
      expect(repeated, isNotNull);
      expect(repeated!.status, AiroAlertStatus.completed);
      final cancelCallsAfterSecond = methodCalls
          .where((call) => call.method == 'cancel')
          .toList();
      expect(cancelCallsAfterSecond, hasLength(1));
    },
  );

  test('persist() upserts a caller-owned alert verbatim (generic bookkeeping hook)', () async {
    final alert = AiroAlert(
      id: 'daily-task-2',
      title: 'Daily Journal',
      scheduledAt: DateTime.now().add(const Duration(hours: 1)),
    );
    await engine.schedule(alert);
    final completed = await engine.markCompleted('daily-task-2');
    expect(completed, isNotNull);

    final withBookkeeping = completed!.copyWith(
      completedDates: const ['2026-09-18'],
      streakCount: 1,
      points: 10,
    );
    final persisted = await engine.persist(withBookkeeping);
    expect(persisted.streakCount, 1);
    expect(persisted.points, 10);

    final queried = await engine.query(includeDelivered: true);
    final reloaded = queried.firstWhere((a) => a.id == 'daily-task-2');
    expect(reloaded.streakCount, 1);
    expect(reloaded.points, 10);
    expect(reloaded.completedDates, ['2026-09-18']);
  });
}
