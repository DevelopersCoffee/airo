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

class EpgReminderGatewayUnavailableException implements Exception {
  const EpgReminderGatewayUnavailableException();
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

    final existingReminders = await _store.list();
    final previousReminder = existingReminders
        .where((item) => item.programId == program.programId)
        .firstOrNull;
    final reminder = EpgReminder(
      channelId: channel.id,
      channelName: channel.name,
      programId: program.programId,
      programTitle: program.title,
      startsAt: program.startsAt,
      endsAt: program.endsAt,
      notificationId: _notificationIdFor(program, existingReminders),
    );
    await _store.save(reminder);

    try {
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
    } on EpgReminderGatewayUnavailableException {
      if (previousReminder != null) {
        await _store.save(previousReminder);
      } else {
        await _store.remove(program.programId);
      }
      return EpgReminderOutcome.unavailable;
    } catch (_) {
      if (previousReminder != null) {
        await _store.save(previousReminder);
      } else {
        await _store.remove(program.programId);
      }
      rethrow;
    }
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
    final now = _now().toUtc();
    final elapsed = (await _store.list())
        .where((item) => !item.endsAt.isAfter(now))
        .toList();
    for (final reminder in elapsed) {
      await _gateway.cancel(reminder.notificationId);
    }
    await _store.pruneElapsed(now);
  }

  int _notificationIdFor(
    CompactEpgProgram program,
    List<EpgReminder> existingReminders,
  ) {
    final existingForProgram = existingReminders
        .where((item) => item.programId == program.programId)
        .firstOrNull;
    if (existingForProgram != null) return existingForProgram.notificationId;

    final usedIds = {
      for (final reminder in existingReminders) reminder.notificationId,
    };
    var candidate = program.programId.hashCode & 0x7fffffff;
    while (usedIds.contains(candidate)) {
      candidate = (candidate + 1) & 0x7fffffff;
    }
    return candidate;
  }
}
