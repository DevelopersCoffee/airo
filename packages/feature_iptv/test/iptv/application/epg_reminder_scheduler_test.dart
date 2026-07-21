import 'package:core_data/core_data.dart';
import 'package:feature_iptv/application/epg_reminder_scheduler.dart';
import 'package:feature_iptv/application/epg_reminder_store.dart';
import 'package:feature_iptv/application/providers/epg_reminder_providers.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late EpgReminderStore store;
  late _FakeGateway gateway;
  late EpgReminderScheduler scheduler;

  final now = DateTime.utc(2026, 7, 20, 12);

  const channel = IPTVChannel(
    id: 'channel-1',
    name: 'Example Channel',
    streamUrl: 'https://example.com/stream.m3u8',
  );

  CompactEpgProgram futureProgram([String id = 'p1']) => CompactEpgProgram(
    programId: id,
    title: 'Evening Show',
    startsAt: now.add(const Duration(hours: 3)),
    endsAt: now.add(const Duration(hours: 4)),
  );

  EpgReminder reminder(String programId, DateTime startsAt) => EpgReminder(
    channelId: 'channel-1',
    channelName: 'Example Channel',
    programId: programId,
    programTitle: 'Show $programId',
    startsAt: startsAt,
    endsAt: startsAt.add(const Duration(hours: 1)),
    notificationId: programId.hashCode & 0x7fffffff,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = EpgReminderStore(PreferencesStore(prefs));
    gateway = _FakeGateway();
    scheduler = EpgReminderScheduler(
      store: store,
      gateway: gateway,
      now: () => now,
    );
  });

  test('scheduleReminder persists and schedules via the gateway', () async {
    final program = futureProgram();

    final outcome = await scheduler.scheduleReminder(
      channel: channel,
      program: program,
    );

    expect(outcome, EpgReminderOutcome.scheduled);
    expect(gateway.scheduled, hasLength(1));
    expect(
      gateway.scheduled.single.notificationId,
      program.programId.hashCode & 0x7fffffff,
    );
    expect(gateway.scheduled.single.title, 'Evening Show');
    expect(gateway.scheduled.single.body, 'Starting now on Example Channel');
    expect(gateway.scheduled.single.at, program.startsAt);
    expect(gateway.scheduled.single.payloadChannelId, 'channel-1');
    expect(await store.contains('p1'), isTrue);
  });

  test('saves the reminder before requesting permission', () async {
    var persistedBeforePermission = false;
    gateway.onRequestPermission = () async {
      persistedBeforePermission = await store.contains('p1');
      return false;
    };

    final outcome = await scheduler.scheduleReminder(
      channel: channel,
      program: futureProgram(),
    );

    expect(outcome, EpgReminderOutcome.scheduledInAppOnly);
    expect(persistedBeforePermission, isTrue);
    expect(gateway.scheduled, isEmpty);
  });

  test(
    'permission denied persists the reminder but skips OS scheduling',
    () async {
      gateway.permissionGranted = false;

      final outcome = await scheduler.scheduleReminder(
        channel: channel,
        program: futureProgram(),
      );

      expect(outcome, EpgReminderOutcome.scheduledInAppOnly);
      expect(gateway.scheduled, isEmpty);
      expect(await store.contains('p1'), isTrue);
    },
  );

  test('schedule failure rolls back a new persisted reminder', () async {
    gateway.throwOnSchedule = true;

    await expectLater(
      scheduler.scheduleReminder(channel: channel, program: futureProgram()),
      throwsStateError,
    );

    expect(await store.contains('p1'), isFalse);
  });

  test('schedule failure restores a replaced reminder', () async {
    final previous = EpgReminder(
      channelId: 'channel-1',
      channelName: 'Example Channel',
      programId: 'p1',
      programTitle: 'Previous Show',
      startsAt: now.add(const Duration(hours: 1)),
      endsAt: now.add(const Duration(hours: 2)),
      notificationId: 42,
    );
    await store.save(previous);
    gateway.throwOnSchedule = true;

    await expectLater(
      scheduler.scheduleReminder(channel: channel, program: futureProgram()),
      throwsStateError,
    );

    expect(await store.list(), [previous]);
  });

  test('unavailable gateway does nothing and reports unavailable', () async {
    gateway.isAvailableValue = false;

    final outcome = await scheduler.scheduleReminder(
      channel: channel,
      program: futureProgram(),
    );

    expect(outcome, EpgReminderOutcome.unavailable);
    expect(gateway.permissionRequests, 0);
    expect(gateway.scheduled, isEmpty);
    expect(await store.contains('p1'), isFalse);
  });

  test(
    'cancelReminder cancels the OS notification and removes the record',
    () async {
      await scheduler.scheduleReminder(
        channel: channel,
        program: futureProgram(),
      );
      final notificationId = gateway.scheduled.single.notificationId;

      await scheduler.cancelReminder('p1');

      expect(gateway.canceled, [notificationId]);
      expect(await store.contains('p1'), isFalse);
    },
  );

  test('isReminded reflects the store', () async {
    expect(await scheduler.isReminded('p1'), isFalse);
    await scheduler.scheduleReminder(
      channel: channel,
      program: futureProgram(),
    );
    expect(await scheduler.isReminded('p1'), isTrue);
  });

  test('pruneElapsed cancels OS notifications for elapsed reminders', () async {
    await scheduler.scheduleReminder(
      channel: channel,
      program: futureProgram('past'),
    );
    await store.remove('past');
    await store.save(
      EpgReminder(
        channelId: 'channel-1',
        channelName: 'Example Channel',
        programId: 'past',
        programTitle: 'Past Show',
        startsAt: now.subtract(const Duration(hours: 2)),
        endsAt: now.subtract(const Duration(hours: 1)),
        notificationId: 42,
      ),
    );

    await scheduler.pruneElapsed();

    expect(gateway.canceled, contains(42));
    expect(await store.contains('past'), isFalse);
  });

  test('pruneElapsed keeps the record when OS cancellation fails', () async {
    final elapsed = reminder(
      'cancel-fails',
      now.subtract(const Duration(hours: 2)),
    );
    await store.save(elapsed);
    gateway.throwOnCancel = true;

    await expectLater(scheduler.pruneElapsed(), throwsStateError);

    expect(await store.contains('cancel-fails'), isTrue);
  });

  test('pruneElapsed uses the injected current time', () async {
    var nowWasRead = false;
    final schedulerWithClock = EpgReminderScheduler(
      store: store,
      gateway: gateway,
      now: () {
        nowWasRead = true;
        return now;
      },
    );
    final earlier = DateTime.utc(2026, 7, 20, 10);
    final elapsed = reminder('elapsed-at-injected-now', earlier);
    await store.save(elapsed);

    await schedulerWithClock.pruneElapsed();

    expect(nowWasRead, isTrue);
    expect(gateway.canceled, contains(elapsed.notificationId));
    expect(await store.contains('elapsed-at-injected-now'), isFalse);
  });

  test(
    'scheduleReminder reuses an existing notification id for replacement',
    () async {
      await store.save(
        EpgReminder(
          channelId: 'channel-1',
          channelName: 'Example Channel',
          programId: 'p1',
          programTitle: 'Existing Show',
          startsAt: now.add(const Duration(hours: 1)),
          endsAt: now.add(const Duration(hours: 2)),
          notificationId: 42,
        ),
      );

      await scheduler.scheduleReminder(
        channel: channel,
        program: futureProgram(),
      );

      expect(gateway.scheduled.single.notificationId, 42);
    },
  );

  test('scheduleReminder avoids notification id collisions', () async {
    final program = futureProgram('colliding-program');
    final hashId = program.programId.hashCode & 0x7fffffff;
    await store.save(
      EpgReminder(
        channelId: 'other-channel',
        channelName: 'Other Channel',
        programId: 'other-program',
        programTitle: 'Other Show',
        startsAt: now.add(const Duration(hours: 1)),
        endsAt: now.add(const Duration(hours: 2)),
        notificationId: hashId,
      ),
    );

    await scheduler.scheduleReminder(channel: channel, program: program);

    expect(gateway.scheduled.single.notificationId, isNot(hashId));
  });

  test('UnavailableEpgReminderNotificationGateway is never available', () {
    const gateway = UnavailableEpgReminderNotificationGateway();
    expect(gateway.isAvailable, isFalse);
  });

  test(
    'providers expose the default unavailable scheduler and reminders',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final providerGateway = container.read(
        epgReminderNotificationGatewayProvider,
      );
      final providerScheduler = container.read(epgReminderSchedulerProvider);
      final outcome = await providerScheduler.scheduleReminder(
        channel: channel,
        program: futureProgram(),
      );

      expect(providerGateway.isAvailable, isFalse);
      expect(outcome, EpgReminderOutcome.unavailable);
      expect(await container.read(epgRemindersProvider.future), isEmpty);
    },
  );
}

class _ScheduledCall {
  _ScheduledCall({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.at,
    required this.payloadChannelId,
  });

  final int notificationId;
  final String title;
  final String body;
  final DateTime at;
  final String payloadChannelId;
}

class _FakeGateway implements EpgReminderNotificationGateway {
  bool isAvailableValue = true;
  bool permissionGranted = true;
  bool throwOnSchedule = false;
  bool throwOnCancel = false;
  Future<bool> Function()? onRequestPermission;
  var permissionRequests = 0;
  final scheduled = <_ScheduledCall>[];
  final canceled = <int>[];

  @override
  bool get isAvailable => isAvailableValue;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return onRequestPermission?.call() ?? permissionGranted;
  }

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime at,
    required String payloadChannelId,
  }) async {
    if (throwOnSchedule) throw StateError('schedule failed');
    scheduled.add(
      _ScheduledCall(
        notificationId: notificationId,
        title: title,
        body: body,
        at: at,
        payloadChannelId: payloadChannelId,
      ),
    );
  }

  @override
  Future<void> cancel(int notificationId) async {
    if (throwOnCancel) throw StateError('cancel failed');
    canceled.add(notificationId);
  }
}
