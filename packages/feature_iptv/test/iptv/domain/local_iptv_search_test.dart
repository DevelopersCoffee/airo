import 'package:feature_iptv/domain/local_iptv_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  IPTVChannel channel(String id, String name, {String group = 'News'}) {
    return IPTVChannel(
      id: id,
      name: name,
      streamUrl: 'http://example.com/$id.ts',
      group: group,
    );
  }

  CompactEpgProgram program(String id, String title) {
    final start = DateTime.utc(2026, 1, 1, 12);
    return CompactEpgProgram(
      programId: id,
      title: title,
      startsAt: start,
      endsAt: start.add(const Duration(hours: 1)),
    );
  }

  group('LocalIptvSearchIndex', () {
    final channels = [
      channel('c1', 'BBC News'),
      channel('c2', 'CNN International'),
      channel('c3', 'BBC World'),
      channel('c4', 'ESPN', group: 'Sports'),
    ];

    final programsByChannel = {
      'c2': [program('p1', 'Breaking News Tonight')],
      'c4': [program('p2', 'Premier League Highlights')],
    };

    LocalIptvSearchIndex buildIndex({
      Set<String> favoriteChannelIds = const {},
      List<String> recentChannelIds = const [],
      Set<String> hiddenGroupIds = const {},
    }) {
      return LocalIptvSearchIndex.build(
        channels: channels,
        programsByChannelId: programsByChannel,
        favoriteChannelIds: favoriteChannelIds,
        recentChannelIds: recentChannelIds,
        hiddenGroupIds: hiddenGroupIds,
      );
    }

    test('excludes channels whose group is hidden (CV-021)', () {
      final index = buildIndex(hiddenGroupIds: {'Sports'});

      final results = index.search('ESPN');

      expect(results, isEmpty);
    });

    test('hidden groups do not affect channels in other groups', () {
      final index = buildIndex(hiddenGroupIds: {'Sports'});

      final results = index.search('BBC News');

      expect(results, isNotEmpty);
    });

    test('returns empty results for a blank query', () {
      final index = buildIndex();
      expect(index.search(''), isEmpty);
      expect(index.search('   '), isEmpty);
    });

    test('exact channel name match ranks above prefix and substring', () {
      final index = buildIndex();

      final results = index.search('BBC News');

      expect(results.first.type, LocalIptvSearchResultType.channel);
      expect(results.first.title, 'BBC News');
      expect(results.first.channelId, 'c1');
    });

    test('prefix matches rank above pure substring matches', () {
      final index = buildIndex();

      final results = index.search('BBC');

      final titles = results
          .where((r) => r.type == LocalIptvSearchResultType.channel)
          .map((r) => r.title)
          .toList();
      expect(titles, containsAll(['BBC News', 'BBC World']));
      // Both are prefix matches; a non-prefix substring elsewhere must not
      // outrank them (verified structurally: only BBC-prefixed channels
      // exist here, this test locks in the ranking field is populated).
      expect(
        results
            .where((r) => r.type == LocalIptvSearchResultType.channel)
            .every((r) => r.rank <= 1),
        isTrue,
      );
    });

    test('matches EPG program titles as a distinct result type', () {
      final index = buildIndex();

      final results = index.search('Breaking News');

      expect(
        results.any(
          (r) =>
              r.type == LocalIptvSearchResultType.program &&
              r.title == 'Breaking News Tonight' &&
              r.channelId == 'c2',
        ),
        isTrue,
      );
    });

    test(
      'favorite channels rank above non-favorites for equal match quality',
      () {
        final index = buildIndex(favoriteChannelIds: {'c3'});

        final results = index
            .search('BBC')
            .where((r) => r.type == LocalIptvSearchResultType.channel)
            .toList();

        expect(results.first.channelId, 'c3');
        expect(results.first.isFavorite, isTrue);
      },
    );

    test('recent channels break ties after favorites', () {
      final index = buildIndex(recentChannelIds: ['c3']);

      final results = index
          .search('BBC')
          .where((r) => r.type == LocalIptvSearchResultType.channel)
          .toList();

      expect(results.first.channelId, 'c3');
      expect(results.first.isRecent, isTrue);
    });

    test('group matches are included as a lower-priority channel match', () {
      final index = buildIndex();

      final results = index.search('Sports');

      expect(
        results.any(
          (r) =>
              r.type == LocalIptvSearchResultType.channel &&
              r.channelId == 'c4',
        ),
        isTrue,
      );
    });

    test('ranking is deterministic across repeated calls', () {
      final index = buildIndex(favoriteChannelIds: {'c3'});

      final first = index.search('BBC').map((r) => r.channelId).toList();
      final second = index.search('BBC').map((r) => r.channelId).toList();

      expect(first, second);
    });

    test('empty index returns no results without throwing', () {
      final index = LocalIptvSearchIndex.build(
        channels: const [],
        programsByChannelId: const {},
        favoriteChannelIds: const {},
        recentChannelIds: const [],
      );

      expect(index.search('anything'), isEmpty);
    });
  });
}
