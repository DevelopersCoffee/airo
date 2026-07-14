import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  group('Compact EPG contracts', () {
    final now = DateTime.utc(2026, 7, 14, 12);
    final current = CompactEpgProgram(
      programId: 'program-current',
      title: 'Live News',
      startsAt: now.subtract(const Duration(minutes: 30)),
      endsAt: now.add(const Duration(minutes: 30)),
      category: 'news',
    );
    final next = CompactEpgProgram(
      programId: 'program-next',
      title: 'Daily Sports',
      startsAt: now.add(const Duration(minutes: 30)),
      endsAt: now.add(const Duration(hours: 1)),
      category: 'sports',
    );

    test('selects current and earliest next program from a compact window', () {
      final entry = CompactEpgEntry.fromPrograms(
        channelId: 'channel-1',
        channelName: 'City Live',
        channelNumber: '7',
        now: now,
        programs: [
          next,
          current,
          CompactEpgProgram(
            programId: 'program-later',
            title: 'Later',
            startsAt: now.add(const Duration(hours: 2)),
            endsAt: now.add(const Duration(hours: 3)),
          ),
        ],
      );

      expect(entry.schemaVersion, kCompactEpgSchemaVersion);
      expect(entry.current, current);
      expect(entry.next, next);
      expect(entry.programAt(now), current);
    });

    test('keeps next program available when there is no current match', () {
      final entry = CompactEpgEntry.fromPrograms(
        channelId: 'channel-1',
        channelName: 'City Live',
        now: now,
        programs: [next],
      );

      expect(entry.current, isNull);
      expect(entry.next, next);
      expect(entry.hasPrograms, isTrue);
    });

    test('slice lookup and expiry return stable availability states', () {
      final slice = CompactEpgSlice(
        entries: [
          CompactEpgEntry(
            channelId: 'channel-1',
            channelName: 'City Live',
            current: current,
            next: next,
          ),
        ],
        generatedAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
        source: CompactEpgSliceSource.localCache,
      );

      expect(slice.entryForChannel('channel-1')?.current, current);
      expect(slice.entryForChannel('missing'), isNull);
      expect(slice.availabilityAt(now), CompactEpgAvailability.available);
      expect(
        slice.availabilityAt(now.add(const Duration(minutes: 5))),
        CompactEpgAvailability.stale,
      );
    });

    test(
      'in-memory repository filters requested channels in requested order',
      () async {
        final slice = CompactEpgSlice(
          entries: [
            CompactEpgEntry(channelId: 'channel-1', channelName: 'One'),
            CompactEpgEntry(channelId: 'channel-2', channelName: 'Two'),
            CompactEpgEntry(channelId: 'channel-3', channelName: 'Three'),
          ],
          generatedAt: now,
          expiresAt: now.add(const Duration(minutes: 5)),
          source: CompactEpgSliceSource.delegatedNode,
        );
        final repository = InMemoryCompactEpgRepository(seed: slice);

        final result = await repository.loadCurrentNext(
          channelIds: const ['channel-3', 'channel-1'],
          now: now,
        );

        expect(result.entries.map((entry) => entry.channelId), [
          'channel-3',
          'channel-1',
        ]);
        expect(result.source, CompactEpgSliceSource.delegatedNode);
      },
    );

    test('empty repository returns normal unavailable state', () async {
      final repository = EmptyCompactEpgRepository();

      final result = await repository.loadCurrentNext(
        channelIds: const ['channel-1'],
        now: now,
      );

      expect(result.entries, isEmpty);
      expect(result.source, CompactEpgSliceSource.unavailable);
      expect(result.availabilityAt(now), CompactEpgAvailability.unavailable);
    });

    test('redacted source references reject unsafe EPG source values', () {
      expect(
        CompactEpgSourceRef.validate(''),
        CompactEpgSourceRefRejectionCode.empty,
      );
      expect(
        CompactEpgSourceRef.validate('https://example.com/guide.xml'),
        CompactEpgSourceRefRejectionCode.urlValue,
      );
      expect(
        CompactEpgSourceRef.validate('/Users/example/guide.xml'),
        CompactEpgSourceRefRejectionCode.localPathValue,
      );
      expect(
        CompactEpgSourceRef.validate('guide from 192.168.1.10'),
        CompactEpgSourceRefRejectionCode.localIpValue,
      );
      expect(
        CompactEpgSourceRef.validate('Basic abc.def'),
        CompactEpgSourceRefRejectionCode.credentialLikeValue,
      );
      expect(
        CompactEpgSourceRef.redacted('epg-source-ref-1').toString(),
        'CompactEpgSourceRef(redacted)',
      );
    });
  });
}
