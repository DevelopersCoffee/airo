import 'package:core_data/core_data.dart';
import 'package:feature_iptv/application/epg_reminder_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late EpgReminderStore store;

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
  });

  test('list is empty when nothing is stored', () async {
    expect(await store.list(), isEmpty);
  });

  test('save then list round-trips the reminder', () async {
    final r = reminder('p1', DateTime.utc(2026, 7, 20, 18));

    await store.save(r);
    final list = await store.list();

    expect(list, hasLength(1));
    expect(list.single, r);
  });

  test('save upserts by programId', () async {
    await store.save(reminder('p1', DateTime.utc(2026, 7, 20, 18)));
    await store.save(reminder('p1', DateTime.utc(2026, 7, 20, 19)));

    final list = await store.list();

    expect(list, hasLength(1));
    expect(list.single.startsAt, DateTime.utc(2026, 7, 20, 19));
  });

  test('contains reflects saved program ids', () async {
    await store.save(reminder('p1', DateTime.utc(2026, 7, 20, 18)));

    expect(await store.contains('p1'), isTrue);
    expect(await store.contains('p2'), isFalse);
  });

  test('remove deletes only the targeted reminder', () async {
    await store.save(reminder('p1', DateTime.utc(2026, 7, 20, 18)));
    await store.save(reminder('p2', DateTime.utc(2026, 7, 20, 20)));

    await store.remove('p1');

    expect(await store.contains('p1'), isFalse);
    expect(await store.contains('p2'), isTrue);
  });

  test(
    'pruneElapsed removes and returns reminders whose program has ended',
    () async {
      final now = DateTime.utc(2026, 7, 20, 21);
      await store.save(reminder('past', DateTime.utc(2026, 7, 20, 19)));
      await store.save(reminder('future', DateTime.utc(2026, 7, 20, 22)));

      final removed = await store.pruneElapsed(now);

      expect(removed.map((r) => r.programId), ['past']);
      expect(await store.contains('past'), isFalse);
      expect(await store.contains('future'), isTrue);
    },
  );
}
