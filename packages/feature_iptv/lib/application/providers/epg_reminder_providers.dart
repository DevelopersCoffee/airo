import 'package:core_data/core_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../epg_reminder_scheduler.dart';
import '../epg_reminder_store.dart';
import 'iptv_providers.dart';

final epgReminderStoreProvider = Provider<EpgReminderStore>((ref) {
  return EpgReminderStore(
    PreferencesStore(ref.watch(sharedPreferencesProvider)),
  );
});

final epgReminderNotificationGatewayProvider =
    Provider<EpgReminderNotificationGateway>((ref) {
      return const UnavailableEpgReminderNotificationGateway();
    });

final epgReminderSchedulerProvider = Provider<EpgReminderScheduler>((ref) {
  return EpgReminderScheduler(
    store: ref.watch(epgReminderStoreProvider),
    gateway: ref.watch(epgReminderNotificationGatewayProvider),
  );
});

final epgRemindersProvider = FutureProvider<List<EpgReminder>>((ref) async {
  return ref.watch(epgReminderStoreProvider).list();
});
