import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  final start = DateTime.utc(2026, 7, 27, 10);
  final end = start.add(const Duration(hours: 3));

  GuideWindowQuery query([String channelId = 'news']) => GuideWindowQuery(
    channelIds: [channelId],
    windowStart: start,
    windowEnd: end,
    now: start,
  );

  CompactEpgProgram program(
    String id,
    String title,
    int startMinutes,
    int endMinutes, {
    DateTime? absoluteStart,
    DateTime? absoluteEnd,
  }) => CompactEpgProgram(
    programId: id,
    title: title,
    startsAt: absoluteStart ?? start.add(Duration(minutes: startMinutes)),
    endsAt: absoluteEnd ?? start.add(Duration(minutes: endMinutes)),
  );

  CompactEpgWindowEntry entry(
    List<CompactEpgProgram> programs, {
    String channelId = 'news',
    String name = 'News',
  }) => CompactEpgWindowEntry(
    channelId: channelId,
    channelName: name,
    programs: programs,
  );

  EpgSourceWindow source(
    String id,
    int priority,
    String revision,
    List<CompactEpgWindowEntry> entries, {
    DateTime? windowStart,
    DateTime? windowEnd,
    Iterable<String>? refreshedChannelIds,
  }) => EpgSourceWindow(
    source: EpgSourceDescriptor(
      sourceId: id,
      priority: priority,
      revision: revision,
    ),
    windowStart: windowStart ?? start,
    windowEnd: windowEnd ?? end,
    entries: entries,
    refreshedChannelIds: refreshedChannelIds,
    generatedAt: start,
    expiresAt: end,
  );

  group('MultiSourceEpgMerger', () {
    test('priority source wins conflicts and lower source fills open time', () {
      final merged = const MultiSourceEpgMerger().merge(
        query: query(),
        sources: [
          source('backup', 10, '1', [
            entry([
              program('backup-conflict', 'Backup news', 0, 60),
              program('backup-fill', 'Late update', 60, 120),
            ]),
          ]),
          source('primary', 0, '1', [
            entry([program('primary', 'Primary news', 0, 60)]),
          ]),
        ],
      );

      expect(merged.entries.single.programs.map((value) => value.programId), [
        'primary',
        'backup-fill',
      ]);
    });

    test('deduplicates equal listings even when source ids differ', () {
      final merged = const MultiSourceEpgMerger().merge(
        query: query(),
        sources: [
          source('a', 0, '1', [
            entry([program('a-id', 'Morning News!', 0, 60)]),
          ]),
          source('b', 1, '1', [
            entry([program('b-id', 'morning news', 0, 60)]),
          ]),
        ],
      );

      expect(merged.entries.single.programs, hasLength(1));
      expect(merged.entries.single.programs.single.programId, 'a-id');
    });

    test('normalizes offset timestamps to UTC before merging', () {
      final localStart = DateTime.parse('2026-07-27T15:30:00+05:30');
      final localEnd = DateTime.parse('2026-07-27T16:30:00+05:30');
      final merged = const MultiSourceEpgMerger().merge(
        query: query(),
        sources: [
          source('offset', 0, '1', [
            entry([
              program(
                'offset-program',
                'Offset',
                0,
                0,
                absoluteStart: localStart,
                absoluteEnd: localEnd,
              ),
            ]),
          ]),
        ],
      );

      final result = merged.entries.single.programs.single;
      expect(result.startsAt, DateTime.utc(2026, 7, 27, 10));
      expect(result.endsAt, DateTime.utc(2026, 7, 27, 11));
      expect(result.startsAt.isUtc, isTrue);
    });

    test('returns explicit gaps without manufacturing programmes', () {
      final merged = const MultiSourceEpgMerger().merge(
        query: query(),
        sources: [
          source('primary', 0, '1', [
            entry([program('middle', 'Middle', 30, 90)]),
          ]),
        ],
      );

      final result = merged.entries.single;
      expect(result.programs, hasLength(1));
      expect(result.gaps, hasLength(2));
      expect(result.gaps.first.startsAt, start);
      expect(result.gaps.first.endsAt, start.add(const Duration(minutes: 30)));
      expect(result.gaps.last.startsAt, start.add(const Duration(minutes: 90)));
      expect(result.gaps.last.endsAt, end);
      expect(
        result.gaps.map((gap) => gap.kind),
        everyElement(CompactEpgGapKind.explicit),
      );
    });

    test('can mark a short adjacent gap without extending a programme', () {
      final merged =
          const MultiSourceEpgMerger(
            policy: MultiSourceEpgMergePolicy(
              inferAdjacentGaps: true,
              maximumInferredGap: Duration(minutes: 5),
            ),
          ).merge(
            query: query(),
            sources: [
              source('primary', 0, '1', [
                entry([
                  program('first', 'First', 0, 60),
                  program('second', 'Second', 64, 120),
                ]),
              ]),
            ],
          );

      final inferred = merged.entries.single.gaps.singleWhere(
        (gap) => gap.kind == CompactEpgGapKind.inferredAdjacent,
      );
      expect(inferred.duration, const Duration(minutes: 4));
      expect(inferred.adjacentProgramId, 'first');
      expect(
        merged.entries.single.programs.first.endsAt,
        start.add(const Duration(hours: 1)),
      );
    });
  });

  group('IncrementalMultiSourceEpgRepository', () {
    test(
      'partial refresh replaces only the addressed channel window',
      () async {
        final repository = IncrementalMultiSourceEpgRepository();
        repository.applyRefresh(
          source('primary', 0, '1', [
            entry([
              program('old-before', 'Before', 0, 60),
              program('old-window', 'Old', 60, 120),
              program('old-after', 'After', 120, 180),
            ]),
            entry(
              [program('sports-old', 'Sports', 0, 180)],
              channelId: 'sports',
              name: 'Sports',
            ),
          ]),
        );

        final result = repository.applyRefresh(
          source(
            'primary',
            0,
            '2',
            [
              entry([program('new-window', 'New', 60, 120)]),
            ],
            windowStart: start.add(const Duration(hours: 1)),
            windowEnd: start.add(const Duration(hours: 2)),
          ),
        );

        expect(result.replacedProgrammeCount, 1);
        expect(result.retainedProgrammeCount, 3);
        final merged = await repository.loadWindow(
          GuideWindowQuery(
            channelIds: const ['news', 'sports'],
            windowStart: start,
            windowEnd: end,
            now: start,
          ),
        );
        expect(
          merged
              .entryForChannel('news')!
              .programs
              .map((value) => value.programId),
          ['old-before', 'new-window', 'old-after'],
        );
        expect(
          merged.entryForChannel('sports')!.programs.single.programId,
          'sports-old',
        );
      },
    );

    test(
      'same revision is unchanged and source removal is immediate',
      () async {
        final repository = IncrementalMultiSourceEpgRepository();
        final initial = source('primary', 0, '1', [
          entry([program('one', 'One', 0, 60)]),
        ]);
        expect(
          repository.applyRefresh(initial).status,
          EpgRefreshStatus.applied,
        );
        expect(
          repository.applyRefresh(initial).status,
          EpgRefreshStatus.unchanged,
        );
        expect(repository.removeSource('primary'), isTrue);
        expect((await repository.loadWindow(query())).entries, isEmpty);
      },
    );

    test(
      'empty partial refresh clears stale data in addressed channel',
      () async {
        final repository = IncrementalMultiSourceEpgRepository();
        repository.applyRefresh(
          source('primary', 0, '1', [
            entry([program('stale', 'Stale', 60, 120)]),
          ]),
        );

        repository.applyRefresh(
          source(
            'primary',
            0,
            '2',
            const [],
            windowStart: start.add(const Duration(hours: 1)),
            windowEnd: start.add(const Duration(hours: 2)),
            refreshedChannelIds: const ['news'],
          ),
        );

        final merged = await repository.loadWindow(query());
        expect(merged.entryForChannel('news'), isNull);
      },
    );

    test('removing priority source reveals backup schedule', () async {
      final repository = IncrementalMultiSourceEpgRepository();
      repository.applyRefresh(
        source('backup', 10, '1', [
          entry([program('backup-show', 'Backup', 0, 60)]),
        ]),
      );
      repository.applyRefresh(
        source('primary', 0, '1', [
          entry([program('primary-show', 'Primary', 0, 60)]),
        ]),
      );

      expect(
        (await repository.loadWindow(
          query(),
        )).entries.single.programs.single.programId,
        'primary-show',
      );
      repository.removeSource('primary');
      expect(
        (await repository.loadWindow(
          query(),
        )).entries.single.programs.single.programId,
        'backup-show',
      );
    });
  });

  test('source ids reject raw endpoint and credential material', () {
    expect(
      () => EpgSourceDescriptor(
        sourceId: 'https://example.test/guide.xml',
        priority: 0,
        revision: '1',
      ),
      throwsArgumentError,
    );
    expect(
      () => EpgSourceDescriptor(
        sourceId: 'Bearer secret-token',
        priority: 0,
        revision: '1',
      ),
      throwsArgumentError,
    );
  });
}
