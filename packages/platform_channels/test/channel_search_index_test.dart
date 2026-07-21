import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  group('AiroChannelSearchIndex', () {
    test('searches name and group case-insensitively', () {
      final index = AiroChannelSearchIndex(_channels);

      final matches = index.filterAndSort(query: 'NEWS');

      expect(matches.map((channel) => channel.id), ['1', '3']);
    });

    test('combines category, flavor, and query filters in one result set', () {
      final index = AiroChannelSearchIndex(_channels);

      final matches = index.filterAndSort(
        category: ChannelCategory.news,
        flavor: ChannelFlavor.englishNews,
        query: 'global',
      );

      expect(matches.map((channel) => channel.id), ['3']);
    });

    test('sorts preference matches before alphabetical fallback', () {
      final index = AiroChannelSearchIndex(_channels);

      final matches = index.filterAndSort(
        preferenceKeywords: const ['music', 'sports'],
      );

      expect(matches.map((channel) => channel.id), ['2', '4', '1', '3']);
    });

    test('memoizes category and flavor counts', () {
      final index = AiroChannelSearchIndex(_channels);

      expect(index.categoryCounts[ChannelCategory.all], 4);
      expect(index.categoryCounts[ChannelCategory.news], 2);
      expect(index.categoryCounts[ChannelCategory.music], 1);
      expect(index.flavorCounts[ChannelFlavor.englishNews], 1);
      expect(index.flavorCounts[ChannelFlavor.hindiNews], 1);
      expect(index.flavorCounts[ChannelFlavor.hindiMusic], 1);
      expect(index.flavorCounts[ChannelFlavor.sports], 1);
    });

    test('returns channels by flavor from the index', () {
      final index = AiroChannelSearchIndex(_channels);

      final matches = index.channelsByFlavor(ChannelFlavor.hindiNews);

      expect(matches.map((channel) => channel.id), ['1']);
    });

    test('does not retain an extra full channel list copy', () {
      final index = AiroChannelSearchIndex(_channels);

      expect(index.retainedFullChannelListCopies, 0);
      expect(index.channels.map((channel) => channel.id), ['1', '2', '3', '4']);
    });

    test('alphabetical fallback is human-natural: case-insensitive and '
        'ignores leading punctuation (Guide raw-ASCII ordering fix)', () {
      final index = AiroChannelSearchIndex(const [
        IPTVChannel(
          id: 'punct-amp',
          name: '&TV',
          streamUrl: 'https://example.com/a.m3u8',
        ),
        IPTVChannel(
          id: 'alpha-bbc',
          name: 'BBC One',
          streamUrl: 'https://example.com/b.m3u8',
        ),
        IPTVChannel(
          id: 'punct-dot',
          name: '.black',
          streamUrl: 'https://example.com/c.m3u8',
        ),
        IPTVChannel(
          id: 'alpha-cnn',
          name: 'cnn',
          streamUrl: 'https://example.com/d.m3u8',
        ),
      ]);

      final sorted = index.filterAndSort();

      // Raw ASCII order would put '&TV' and '.black' first and 'cnn'
      // after 'BBC One'; natural order compares by normalized key
      // ('bbc one' < 'black' < 'cnn' < 'tv').
      expect(sorted.map((channel) => channel.id), [
        'alpha-bbc',
        'punct-dot',
        'alpha-cnn',
        'punct-amp',
      ]);
    });
  });
}

const _channels = [
  IPTVChannel(
    id: '1',
    name: 'Bharat Samachar',
    streamUrl: 'https://example.com/1.m3u8',
    group: 'Hindi News',
    category: ChannelCategory.news,
    flavor: ChannelFlavor.hindiNews,
  ),
  IPTVChannel(
    id: '2',
    name: 'Aaj Music',
    streamUrl: 'https://example.com/2.m3u8',
    group: 'Hindi Hits',
    category: ChannelCategory.music,
    flavor: ChannelFlavor.hindiMusic,
  ),
  IPTVChannel(
    id: '3',
    name: 'Global News',
    streamUrl: 'https://example.com/3.m3u8',
    group: 'World',
    category: ChannelCategory.news,
    flavor: ChannelFlavor.englishNews,
  ),
  IPTVChannel(
    id: '4',
    name: 'Cricket Live',
    streamUrl: 'https://example.com/4.m3u8',
    group: 'Sports',
    category: ChannelCategory.sports,
    flavor: ChannelFlavor.sports,
  ),
];
