import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  group('CompactEpgReminderReconciler', () {
    final now = DateTime.utc(2026, 7, 15, 9);
    const request = CompactEpgReminderRequest(
      reminderId: 'reminder-1',
      title: 'IND vs AUS, 1st ODI',
      eventId: 'fixture-ind-aus-odi-1',
    );

    test('reschedules event reminder when channel carriage changes', () {
      final reconciler = CompactEpgReminderReconciler();
      final oldSlice = _slice(
        now: now,
        channelId: 'sports-1',
        programId: 'old-program',
        startsAt: DateTime.utc(2026, 7, 15, 10),
      );
      final freshSlice = _slice(
        now: now,
        channelId: 'sports-2',
        programId: 'fresh-program',
        startsAt: DateTime.utc(2026, 7, 15, 10, 30),
      );

      final initial = reconciler.reconcileOne(
        request: request,
        slice: oldSlice,
        now: now,
      );
      final refreshed = reconciler.reconcileOne(
        request: request,
        slice: freshSlice,
        now: now,
        existing: initial.pending,
      );

      expect(initial.status, CompactEpgReminderStatus.scheduled);
      expect(refreshed.status, CompactEpgReminderStatus.scheduled);
      expect(refreshed.command?.channelId, 'sports-2');
      expect(refreshed.command?.programId, 'fresh-program');
      expect(refreshed.command?.notifyAt, DateTime.utc(2026, 7, 15, 10, 25));
    });

    test('leaves unresolved event reminders pending without a command', () {
      final result = const CompactEpgReminderReconciler().reconcileOne(
        request: request,
        slice: CompactEpgSlice(
          entries: const [],
          generatedAt: now,
          expiresAt: now.add(const Duration(minutes: 15)),
          source: CompactEpgSliceSource.unavailable,
        ),
        now: now,
      );

      expect(result.status, CompactEpgReminderStatus.unresolved);
      expect(result.command, isNull);
      expect(result.pending, isNull);
    });

    test('does not schedule notifications in the past', () {
      final result = const CompactEpgReminderReconciler().reconcileOne(
        request: request,
        slice: _slice(
          now: now,
          channelId: 'sports-1',
          programId: 'program-now',
          startsAt: DateTime.utc(2026, 7, 15, 9, 3),
        ),
        now: now,
      );

      expect(result.status, CompactEpgReminderStatus.skippedPastNotification);
      expect(result.command, isNull);
    });
  });
}

CompactEpgSlice _slice({
  required DateTime now,
  required String channelId,
  required String programId,
  required DateTime startsAt,
}) {
  return CompactEpgSlice(
    generatedAt: now,
    expiresAt: now.add(const Duration(minutes: 15)),
    source: CompactEpgSliceSource.localCache,
    entries: [
      CompactEpgEntry(
        channelId: channelId,
        channelName: channelId,
        current: CompactEpgProgram(
          programId: programId,
          eventId: 'fixture-ind-aus-odi-1',
          title: 'IND vs AUS, 1st ODI',
          kind: CompactEpgProgramKind.sports,
          startsAt: startsAt,
          endsAt: startsAt.add(const Duration(hours: 3)),
        ),
      ),
    ],
  );
}
