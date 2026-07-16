import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:platform_playlist/platform_playlist.dart';

class _FakeXtreamClient implements XtreamClient {
  _FakeXtreamClient(this._listingsByStreamId);

  final Map<int, List<XtreamEpgListing>> _listingsByStreamId;

  @override
  Future<List<XtreamEpgListing>> getShortEpg({
    required int streamId,
    int limit = 4,
  }) async => _listingsByStreamId[streamId] ?? const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.utc(2026, 7, 16, 18, 10);
  final currentListing = XtreamEpgListing(
    id: 'p1',
    title: 'Evening News',
    description: 'Top stories',
    start: DateTime.utc(2026, 7, 16, 18, 0),
    end: DateTime.utc(2026, 7, 16, 18, 30),
    streamId: 101,
  );
  final nextListing = XtreamEpgListing(
    id: 'p2',
    title: 'Late Show',
    description: 'Talk show',
    start: DateTime.utc(2026, 7, 16, 18, 30),
    end: DateTime.utc(2026, 7, 16, 19, 0),
    streamId: 101,
  );

  test('loadCurrentNext maps listings into current/next per mapped channel', () async {
    final client = _FakeXtreamClient({
      101: [currentListing, nextListing],
    });
    final repo = XtreamEpgRepository(
      client,
      channelIdToStreamId: (channelId) =>
          channelId == 'xtream-101' ? 101 : null,
    );

    final slice = await repo.loadCurrentNext(
      channelIds: ['xtream-101'],
      now: now,
    );

    expect(slice.entries, hasLength(1));
    final entry = slice.entries.single;
    expect(entry.channelId, 'xtream-101');
    expect(entry.current?.title, 'Evening News');
    expect(entry.next?.title, 'Late Show');
  });

  test('loadCurrentNext skips channels with no stream_id mapping', () async {
    final client = _FakeXtreamClient({
      101: [currentListing],
    });
    final repo = XtreamEpgRepository(
      client,
      channelIdToStreamId: (_) => null,
    );

    final slice = await repo.loadCurrentNext(
      channelIds: ['xtream-unknown'],
      now: now,
    );

    expect(slice.entries, isEmpty);
  });

  test('loadWindow returns only programmes intersecting the query window', () async {
    final client = _FakeXtreamClient({
      101: [currentListing, nextListing],
    });
    final repo = XtreamEpgRepository(
      client,
      channelIdToStreamId: (channelId) =>
          channelId == 'xtream-101' ? 101 : null,
    );
    final query = GuideWindowQuery(
      channelIds: ['xtream-101'],
      windowStart: DateTime.utc(2026, 7, 16, 18, 0),
      windowEnd: DateTime.utc(2026, 7, 16, 18, 35),
      now: now,
    );

    final window = await repo.loadWindow(query);

    expect(window.entries, hasLength(1));
    final entry = window.entries.single;
    expect(entry.programs, hasLength(2));
    expect(entry.programs.map((p) => p.title), [
      'Evening News',
      'Late Show',
    ]);
  });
}
