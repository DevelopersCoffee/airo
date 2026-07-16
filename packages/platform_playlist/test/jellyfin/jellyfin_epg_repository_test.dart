import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:platform_playlist/platform_playlist.dart';

class _FakeJellyfinClient implements JellyfinClient {
  _FakeJellyfinClient(this._programs);

  final List<JellyfinProgram> _programs;
  int getProgramsCallCount = 0;
  List<String>? lastChannelIds;

  @override
  Future<List<JellyfinProgram>> getPrograms({
    required String accessToken,
    required String userId,
    required List<String> channelIds,
  }) async {
    getProgramsCallCount++;
    lastChannelIds = channelIds;
    return _programs
        .where((program) => channelIds.contains(program.channelId))
        .toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.utc(2026, 7, 16, 18, 10);
  final currentProgram = JellyfinProgram(
    id: 'p1',
    name: 'Evening News',
    channelId: 'chan-1',
    startDate: DateTime.utc(2026, 7, 16, 18, 0),
    endDate: DateTime.utc(2026, 7, 16, 18, 30),
    overview: 'Top stories',
  );
  final nextProgram = JellyfinProgram(
    id: 'p2',
    name: 'Late Show',
    channelId: 'chan-1',
    startDate: DateTime.utc(2026, 7, 16, 18, 30),
    endDate: DateTime.utc(2026, 7, 16, 19, 0),
    overview: 'Talk show',
  );
  final otherChannelProgram = JellyfinProgram(
    id: 'p3',
    name: 'Weather',
    channelId: 'chan-2',
    startDate: DateTime.utc(2026, 7, 16, 18, 0),
    endDate: DateTime.utc(2026, 7, 16, 18, 15),
  );

  test(
    'loadCurrentNext issues a single batched request for multiple channels',
    () async {
      final client = _FakeJellyfinClient([
        currentProgram,
        nextProgram,
        otherChannelProgram,
      ]);
      final repo = JellyfinEpgRepository(
        client,
        accessToken: 'jf-token',
        userId: 'user-1',
      );

      final slice = await repo.loadCurrentNext(
        channelIds: ['jellyfin-chan-1', 'jellyfin-chan-2'],
        now: now,
      );

      expect(client.getProgramsCallCount, 1);
      expect(client.lastChannelIds, ['chan-1', 'chan-2']);
      expect(slice.entries, hasLength(2));
      final entry1 = slice.entryForChannel('jellyfin-chan-1')!;
      expect(entry1.current?.title, 'Evening News');
      expect(entry1.next?.title, 'Late Show');
      final entry2 = slice.entryForChannel('jellyfin-chan-2')!;
      expect(entry2.current?.title, 'Weather');
    },
  );

  test(
    'loadWindow issues a single batched request and filters to the window',
    () async {
      final client = _FakeJellyfinClient([currentProgram, nextProgram]);
      final repo = JellyfinEpgRepository(
        client,
        accessToken: 'jf-token',
        userId: 'user-1',
      );
      final query = GuideWindowQuery(
        channelIds: ['jellyfin-chan-1'],
        windowStart: DateTime.utc(2026, 7, 16, 18, 0),
        windowEnd: DateTime.utc(2026, 7, 16, 18, 35),
        now: now,
      );

      final window = await repo.loadWindow(query);

      expect(client.getProgramsCallCount, 1);
      expect(window.entries, hasLength(1));
      final entry = window.entries.single;
      expect(entry.programs, hasLength(2));
      expect(entry.programs.map((p) => p.title), ['Evening News', 'Late Show']);
    },
  );
}
