import 'package:feature_iptv/application/guide_window_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  final now = DateTime.utc(2026, 7, 20, 12);

  const channel = IPTVChannel(
    id: 'channel-1',
    name: 'Example Channel',
    streamUrl: 'https://example.com/stream.m3u8',
    group: 'News',
  );

  CompactEpgProgram program(
    String id,
    String title,
    int startHour,
    int endHour,
  ) {
    return CompactEpgProgram(
      programId: id,
      title: title,
      startsAt: DateTime.utc(2026, 7, 20, startHour),
      endsAt: DateTime.utc(2026, 7, 20, endHour),
    );
  }

  InMemoryCompactEpgRepository repoWith(List<CompactEpgEntry> entries) {
    return InMemoryCompactEpgRepository(
      seed: CompactEpgSlice(
        entries: entries,
        generatedAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
        source: CompactEpgSliceSource.localCache,
      ),
    );
  }

  group('queryGuideWindowWithOverrides', () {
    test('queries with the raw channel id when no override is set', () async {
      final repo = repoWith([
        CompactEpgEntry(
          channelId: 'channel-1',
          channelName: 'Example Channel',
          current: program('p1', 'Now Showing', 11, 13),
        ),
      ]);

      final window = await queryGuideWindowWithOverrides(
        channels: const [channel],
        overrides: const {},
        hiddenGroupIds: const {},
        repository: repo,
        windowStart: now.subtract(const Duration(hours: 1)),
        windowEnd: now.add(const Duration(hours: 2)),
        now: now,
      );

      expect(window.entryForChannel('channel-1')?.programs, isNotEmpty);
    });

    test(
      'queries with the override EPG id and remaps to the channel id',
      () async {
        final repo = repoWith([
          CompactEpgEntry(
            channelId: 'overridden.epg.id',
            channelName: 'Example Channel (EPG)',
            current: program('p1', 'Now Showing', 11, 13),
          ),
        ]);

        final window = await queryGuideWindowWithOverrides(
          channels: const [channel],
          overrides: const {'channel-1': 'overridden.epg.id'},
          hiddenGroupIds: const {},
          repository: repo,
          windowStart: now.subtract(const Duration(hours: 1)),
          windowEnd: now.add(const Duration(hours: 2)),
          now: now,
        );

        expect(window.entryForChannel('channel-1')?.programs, isNotEmpty);
        expect(window.entryForChannel('overridden.epg.id'), isNull);
      },
    );

    test(
      'excludes channels in hidden groups from the query (CV-021)',
      () async {
        var queriedIds = <String>[];
        final repo = _RecordingRepository(
          onQuery: (ids) => queriedIds = List.of(ids),
          now: now,
        );

        final window = await queryGuideWindowWithOverrides(
          channels: const [channel],
          overrides: const {},
          hiddenGroupIds: const {'News'},
          repository: repo,
          windowStart: now,
          windowEnd: now.add(const Duration(hours: 1)),
          now: now,
        );

        expect(queriedIds, isEmpty);
        expect(window.entries, isEmpty);
      },
    );
  });

  group('mergeGuideWindowPage', () {
    CompactEpgWindow windowFor(
      List<CompactEpgProgram> programs,
      DateTime start,
      DateTime end,
    ) {
      return CompactEpgWindow(
        entries: [
          CompactEpgWindowEntry(
            channelId: 'channel-1',
            channelName: 'Example Channel',
            programs: programs,
          ),
        ],
        windowStart: start,
        windowEnd: end,
        generatedAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
        source: CompactEpgSliceSource.localCache,
      );
    }

    test('null base returns the page unchanged', () {
      final page = windowFor(
        [program('p1', 'A', 12, 13)],
        now,
        now.add(const Duration(hours: 3)),
      );

      expect(mergeGuideWindowPage(null, page), same(page));
    });

    test('concatenates programs per channel, sorted by startsAt', () {
      final base = windowFor(
        [program('p2', 'B', 13, 14)],
        now,
        now.add(const Duration(hours: 1)),
      );
      final page = windowFor(
        [program('p1', 'A', 14, 15)],
        now.add(const Duration(hours: 1)),
        now.add(const Duration(hours: 2)),
      );

      final merged = mergeGuideWindowPage(base, page);
      final titles = merged
          .entryForChannel('channel-1')!
          .programs
          .map((p) => p.title);

      expect(titles, ['B', 'A']);
      expect(merged.windowStart, now);
      expect(merged.windowEnd, now.add(const Duration(hours: 2)));
    });

    test('dedupes programs by programId when pages overlap', () {
      final shared = program('p1', 'Shared', 13, 14);
      final base = windowFor([shared], now, now.add(const Duration(hours: 2)));
      final page = windowFor(
        [shared, program('p2', 'New', 14, 15)],
        now.add(const Duration(hours: 2)),
        now.add(const Duration(hours: 4)),
      );

      final merged = mergeGuideWindowPage(base, page);

      expect(merged.entryForChannel('channel-1')!.programs, hasLength(2));
    });
  });
}

class _RecordingRepository implements CompactEpgRepository {
  _RecordingRepository({required this.onQuery, required this.now});

  final void Function(Iterable<String> channelIds) onQuery;
  final DateTime now;

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) async {
    return CompactEpgSlice(
      entries: const [],
      generatedAt: now,
      expiresAt: now,
      source: CompactEpgSliceSource.unavailable,
    );
  }

  @override
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query) async {
    onQuery(query.channelIds);
    return CompactEpgWindow(
      entries: const [],
      windowStart: query.windowStart,
      windowEnd: query.windowEnd,
      generatedAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
      source: CompactEpgSliceSource.unavailable,
    );
  }
}
