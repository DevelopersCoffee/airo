import 'package:feature_iptv/application/mutable_xmltv_compact_epg_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  test('defaults to unavailable when no source has been set', () async {
    final repository = MutableXmltvCompactEpgRepository();
    final now = DateTime.utc(2026, 7, 17, 12);

    final slice = await repository.loadCurrentNext(
      channelIds: ['chan-1'],
      now: now,
    );

    expect(slice.availabilityAt(now), CompactEpgAvailability.unavailable);
  });

  test(
    'updateSource swaps in a real repository, delegating loadWindow',
    () async {
      final repository = MutableXmltvCompactEpgRepository();
      final now = DateTime.utc(2026, 7, 17, 12);
      final fakeInner = InMemoryCompactEpgRepository(
        seed: CompactEpgSlice(
          entries: [
            CompactEpgEntry(
              channelId: 'chan-1',
              channelName: 'Channel 1',
              current: CompactEpgProgram(
                programId: 'p1',
                title: 'Now Showing',
                startsAt: now.subtract(const Duration(minutes: 10)),
                endsAt: now.add(const Duration(minutes: 20)),
              ),
            ),
          ],
          generatedAt: now,
          expiresAt: now.add(const Duration(hours: 1)),
          source: CompactEpgSliceSource.localCache,
        ),
      );

      repository.updateSource(fakeInner);
      final query = GuideWindowQuery(
        channelIds: ['chan-1'],
        windowStart: now.subtract(const Duration(hours: 1)),
        windowEnd: now.add(const Duration(hours: 1)),
        now: now,
      );
      final window = await repository.loadWindow(query);

      expect(window.entryForChannel('chan-1')?.programs, isNotEmpty);
    },
  );

  test('updateSource(null) reverts to unavailable', () async {
    final repository = MutableXmltvCompactEpgRepository();
    final now = DateTime.utc(2026, 7, 17, 12);
    repository.updateSource(
      InMemoryCompactEpgRepository(
        seed: CompactEpgSlice(
          entries: const [],
          generatedAt: now,
          expiresAt: now,
          source: CompactEpgSliceSource.localCache,
        ),
      ),
    );

    repository.updateSource(null);
    final slice = await repository.loadCurrentNext(
      channelIds: ['chan-1'],
      now: now,
    );

    expect(slice.availabilityAt(now), CompactEpgAvailability.unavailable);
  });
}
