import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

import 'epg_reminder_store.dart';

/// Host-provided bridge to OS local notifications for EPG reminders.
///
/// `feature_iptv` deliberately depends only on this interface; the app wires a
/// platform notification implementation by overriding the provider in Task 9.
abstract interface class EpgReminderNotificationGateway {
  bool get isAvailable;

  Future<bool> requestPermission();

  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime at,
    required String payloadChannelId,
  });

  Future<void> cancel(int notificationId);
}

class UnavailableEpgReminderNotificationGateway
    implements EpgReminderNotificationGateway {
  const UnavailableEpgReminderNotificationGateway();

  @override
  bool get isAvailable => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime at,
    required String payloadChannelId,
  }) async {}

  @override
  Future<void> cancel(int notificationId) async {}
}

enum EpgReminderOutcome { scheduled, scheduledInAppOnly, unavailable }

class EpgReminderScheduler {
  EpgReminderScheduler({
    required EpgReminderStore store,
    required EpgReminderNotificationGateway gateway,
    DateTime Function()? now,
  }) : this._(store: store, gateway: gateway, now: now ?? DateTime.now);

  EpgReminderScheduler._({
    required this._store,
    required this._gateway,
    required this._now,
  });

  final EpgReminderStore _store;
  final EpgReminderNotificationGateway _gateway;
  final DateTime Function() _now;

  Future<EpgReminderOutcome> scheduleReminder({
    required IPTVChannel channel,
    required CompactEpgProgram program,
  }) async {
    if (!_gateway.isAvailable) {
      return EpgReminderOutcome.unavailable;
    }

    final reminder = EpgReminder(
      channelId: channel.id,
      channelName: channel.name,
      programId: program.programId,
      programTitle: program.title,
      startsAt: program.startsAt,
      endsAt: program.endsAt,
      notificationId: program.programId.hashCode & 0x7fffffff,
    );
    await _store.save(reminder);

    final granted = await _gateway.requestPermission();
    if (!granted) {
      return EpgReminderOutcome.scheduledInAppOnly;
    }

    await _gateway.schedule(
      notificationId: reminder.notificationId,
      title: program.title,
      body: 'Starting now on ${channel.name}',
      at: program.startsAt,
      payloadChannelId: channel.id,
    );
    return EpgReminderOutcome.scheduled;
  }

  Future<void> cancelReminder(String programId) async {
    final reminders = await _store.list();
    for (final reminder in reminders.where(
      (item) => item.programId == programId,
    )) {
      await _gateway.cancel(reminder.notificationId);
    }
    await _store.remove(programId);
  }

  Future<bool> isReminded(String programId) {
    return _store.contains(programId);
  }

  Future<void> pruneElapsed() async {
    final removed = await _store.pruneElapsed(_now().toUtc());
    for (final reminder in removed) {
      await _gateway.cancel(reminder.notificationId);
    }
  }
}
