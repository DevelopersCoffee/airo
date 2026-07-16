import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  group('SportsDeskEventResolver', () {
    final now = DateTime.utc(2026, 7, 15, 9);

    test('resolves fixture rows through EPG event ids', () {
      final row = SportsDeskRow(
        rowId: 'live-sports',
        title: 'Live Sports Desk',
        fixtures: [
          SportsFixture(
            eventId: 'fixture-ind-aus-odi-1',
            title: 'IND vs AUS, 1st ODI',
            sport: 'cricket',
            startsAt: DateTime.utc(2026, 7, 15, 10),
            regionCode: 'IN',
          ),
        ],
      );
      final slice = CompactEpgSlice(
        generatedAt: now,
        expiresAt: now.add(const Duration(minutes: 15)),
        source: CompactEpgSliceSource.localCache,
        entries: [
          CompactEpgEntry(
            channelId: 'sports-hd',
            channelName: 'Sports HD',
            next: CompactEpgProgram(
              programId: 'program-1',
              eventId: 'fixture-ind-aus-odi-1',
              title: 'IND vs AUS, 1st ODI',
              kind: CompactEpgProgramKind.sports,
              startsAt: DateTime.utc(2026, 7, 15, 10),
              endsAt: DateTime.utc(2026, 7, 15, 13),
            ),
          ),
        ],
      );

      final resolutions = const SportsDeskEventResolver().resolveRow(
        row: row,
        slice: slice,
      );

      expect(resolutions.single.hasCarriage, isTrue);
      expect(
        resolutions.single.epgResolution.resolved?.entry.channelId,
        'sports-hd',
      );
    });

    test('keeps fixture row renderable when EPG carriage is unresolved', () {
      final row = SportsDeskRow(
        rowId: 'live-sports',
        title: 'Live Sports Desk',
        fixtures: [
          SportsFixture(
            eventId: 'fixture-later',
            title: 'Later Fixture',
            sport: 'football',
            startsAt: DateTime.utc(2026, 7, 15, 18),
          ),
        ],
      );
      final slice = CompactEpgSlice(
        entries: const [],
        generatedAt: now,
        expiresAt: now.add(const Duration(minutes: 15)),
        source: CompactEpgSliceSource.localCache,
      );

      final resolutions = const SportsDeskEventResolver().resolveRow(
        row: row,
        slice: slice,
      );

      expect(resolutions.single.fixture.title, 'Later Fixture');
      expect(resolutions.single.hasCarriage, isFalse);
      expect(
        resolutions.single.epgResolution.code,
        CompactEpgEventResolutionCode.unresolved,
      );
    });
  });
}
