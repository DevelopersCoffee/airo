import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  final now = DateTime.utc(2026, 7, 16, 18, 10);
  final currentProgram = CompactEpgProgram(
    programId: 'p1',
    title: 'Evening News',
    startsAt: DateTime.utc(2026, 7, 16, 18, 0),
    endsAt: DateTime.utc(2026, 7, 16, 18, 30),
  );
  final nextProgram = CompactEpgProgram(
    programId: 'p2',
    title: 'Late Show',
    startsAt: DateTime.utc(2026, 7, 16, 18, 30),
    endsAt: DateTime.utc(2026, 7, 16, 19, 0),
  );

  Future<List<CompactEpgProgram>> Function(String) fetch(
    Map<String, List<CompactEpgProgram>> byChannel,
  ) =>
      (String channelId) async => byChannel[channelId] ?? const [];

  test(
    'loadCurrentNext maps fetched programmes into current/next per channel',
    () async {
      final repo = StalkerEpgRepository(
        fetch({
          'stalker-1': [currentProgram, nextProgram],
        }),
      );

      final slice = await repo.loadCurrentNext(
        channelIds: ['stalker-1'],
        now: now,
      );

      expect(slice.entries, hasLength(1));
      final entry = slice.entries.single;
      expect(entry.channelId, 'stalker-1');
      expect(entry.current?.title, 'Evening News');
      expect(entry.next?.title, 'Late Show');
    },
  );

  test(
    'loadCurrentNext returns an empty entry when the fetch callback finds nothing',
    () async {
      final repo = StalkerEpgRepository(fetch({}));

      final slice = await repo.loadCurrentNext(
        channelIds: ['stalker-unknown'],
        now: now,
      );

      expect(slice.entries, hasLength(1));
      expect(slice.entries.single.hasPrograms, isFalse);
    },
  );

  test(
    'loadWindow returns only programmes intersecting the query window',
    () async {
      final repo = StalkerEpgRepository(
        fetch({
          'stalker-1': [currentProgram, nextProgram],
        }),
      );
      final query = GuideWindowQuery(
        channelIds: ['stalker-1'],
        windowStart: DateTime.utc(2026, 7, 16, 18, 0),
        windowEnd: DateTime.utc(2026, 7, 16, 18, 35),
        now: now,
      );

      final window = await repo.loadWindow(query);

      expect(window.entries, hasLength(1));
      final entry = window.entries.single;
      expect(entry.programs, hasLength(2));
      expect(entry.programs.map((p) => p.title), ['Evening News', 'Late Show']);
    },
  );
}
