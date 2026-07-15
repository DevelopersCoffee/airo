import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  group('compact EPG snapshot codec', () {
    test('round trips compact guide slices with redacted source refs', () {
      final now = DateTime.utc(2026, 7, 15, 9);
      final slice = _slice(
        now: now,
        entries: [
          CompactEpgEntry(
            channelId: 'news-1',
            channelName: 'News One',
            channelNumber: '101',
            sourceRef: CompactEpgSourceRef.redacted('user-guide-primary'),
            current: CompactEpgProgram(
              programId: 'current',
              title: 'Morning News',
              subtitle: 'Top stories',
              category: 'news',
              rating: 'G',
              startsAt: now.subtract(const Duration(minutes: 15)),
              endsAt: now.add(const Duration(minutes: 15)),
            ),
            next: CompactEpgProgram(
              programId: 'next',
              title: 'Market Watch',
              startsAt: now.add(const Duration(minutes: 15)),
              endsAt: now.add(const Duration(minutes: 45)),
            ),
          ),
        ],
      );

      final decoded = decodeCompactEpgSlice(encodeCompactEpgSlice(slice));

      expect(decoded, slice);
      expect(
        decoded.entryForChannel('news-1')?.sourceRef?.value,
        'user-guide-primary',
      );
    });

    test('rejects malformed snapshot payloads', () {
      expect(
        () => decodeCompactEpgSlice('[]'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => compactEpgSliceFromJson({
          'generatedAt': DateTime.utc(2026, 7, 15).toIso8601String(),
          'expiresAt': DateTime.utc(2026, 7, 15, 1).toIso8601String(),
          'source': 'local_cache',
          'entries': [
            {
              'channelId': 'news-1',
              'channelName': 'News One',
              'sourceRef': 'https://example.com/private-guide.xml',
            },
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('SnapshotBackedCompactEpgRepository', () {
    test('loads requested channels from snapshot in requested order', () async {
      final now = DateTime.utc(2026, 7, 15, 9);
      final store = InMemoryCompactEpgSnapshotStore(
        encodeCompactEpgSlice(
          _slice(
            now: now,
            entries: [
              _entry('news-1', 'News One', now),
              _entry('sports-1', 'Sports One', now),
            ],
          ),
        ),
      );
      final repository = SnapshotBackedCompactEpgRepository(store: store);

      final result = await repository.loadCurrentNext(
        channelIds: const ['sports-1', 'missing', 'news-1'],
        now: now,
      );

      expect(result.source, CompactEpgSliceSource.localCache);
      expect(result.entries.map((entry) => entry.channelId), [
        'sports-1',
        'news-1',
      ]);
      expect(
        result.entryForChannel('sports-1')?.current?.title,
        'Sports One Now',
      );
    });

    test('falls back when snapshot is missing or corrupted', () async {
      final now = DateTime.utc(2026, 7, 15, 9);
      final fallback = InMemoryCompactEpgRepository(
        seed: _slice(now: now, entries: [_entry('fallback', 'Fallback', now)]),
      );
      final missing = SnapshotBackedCompactEpgRepository(
        store: InMemoryCompactEpgSnapshotStore(),
        fallback: fallback,
      );
      final corrupted = SnapshotBackedCompactEpgRepository(
        store: InMemoryCompactEpgSnapshotStore('{bad-json'),
        fallback: fallback,
      );

      expect(
        (await missing.loadCurrentNext(
          channelIds: const ['fallback'],
          now: now,
        )).entryForChannel('fallback')?.current?.title,
        'Fallback Now',
      );
      expect(
        (await corrupted.loadCurrentNext(
          channelIds: const ['fallback'],
          now: now,
        )).entryForChannel('fallback')?.current?.title,
        'Fallback Now',
      );
    });

    test('can suppress expired snapshots for unavailable fallback', () async {
      final now = DateTime.utc(2026, 7, 15, 9);
      final expired = _slice(
        now: now.subtract(const Duration(hours: 1)),
        entries: [_entry('news-1', 'News One', now)],
      );
      final repository = SnapshotBackedCompactEpgRepository(
        store: InMemoryCompactEpgSnapshotStore(encodeCompactEpgSlice(expired)),
        returnExpiredSnapshots: false,
      );

      final result = await repository.loadCurrentNext(
        channelIds: const ['news-1'],
        now: now,
      );

      expect(result.entries, isEmpty);
      expect(result.source, CompactEpgSliceSource.unavailable);
    });

    test('saves, replaces, and clears snapshots', () async {
      final now = DateTime.utc(2026, 7, 15, 9);
      final store = InMemoryCompactEpgSnapshotStore();
      final repository = SnapshotBackedCompactEpgRepository(store: store);

      await repository.saveSnapshot(
        _slice(now: now, entries: [_entry('news-1', 'News One', now)]),
      );
      expect(
        (await repository.loadCurrentNext(
          channelIds: const ['news-1'],
          now: now,
        )).entryForChannel('news-1')?.current?.title,
        'News One Now',
      );

      await repository.saveSnapshot(
        _slice(now: now, entries: [_entry('sports-1', 'Sports One', now)]),
      );
      expect(
        (await repository.loadCurrentNext(
          channelIds: const ['news-1', 'sports-1'],
          now: now,
        )).entries.map((entry) => entry.channelId),
        ['sports-1'],
      );

      await repository.clearSnapshot();
      final empty = await repository.loadCurrentNext(
        channelIds: const ['sports-1'],
        now: now,
      );
      expect(empty.source, CompactEpgSliceSource.unavailable);
      expect(empty.entries, isEmpty);
    });

    test('persists snapshots through file-backed store', () async {
      final now = DateTime.utc(2026, 7, 15, 9);
      final directory = await Directory.systemTemp.createTemp(
        'platform_epg_snapshot_test_',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final file = File('${directory.path}/compact_epg_snapshot.json');
      final store = FileCompactEpgSnapshotStore(fileProvider: () async => file);
      final writer = SnapshotBackedCompactEpgRepository(store: store);

      await writer.saveSnapshot(
        _slice(now: now, entries: [_entry('news-1', 'News One', now)]),
      );

      final reader = SnapshotBackedCompactEpgRepository(store: store);
      final result = await reader.loadCurrentNext(
        channelIds: const ['news-1'],
        now: now,
      );

      expect(await file.exists(), isTrue);
      expect(result.entryForChannel('news-1')?.current?.title, 'News One Now');
    });
  });
}

CompactEpgSlice _slice({
  required DateTime now,
  required List<CompactEpgEntry> entries,
}) {
  return CompactEpgSlice(
    entries: entries,
    generatedAt: now,
    expiresAt: now.add(const Duration(minutes: 15)),
    source: CompactEpgSliceSource.localCache,
  );
}

CompactEpgEntry _entry(String channelId, String channelName, DateTime now) {
  return CompactEpgEntry(
    channelId: channelId,
    channelName: channelName,
    current: CompactEpgProgram(
      programId: '$channelId-current',
      title: '$channelName Now',
      startsAt: now.subtract(const Duration(minutes: 10)),
      endsAt: now.add(const Duration(minutes: 20)),
    ),
  );
}
