import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  group('RailQuery.matches', () {
    const sports = IPTVChannel(
      id: '1',
      name: 'Star Sports 1 HD',
      streamUrl: 'http://x/1.m3u8',
      category: ChannelCategory.sports,
      languages: ['hi', 'en'],
    );
    const news = IPTVChannel(
      id: '2',
      name: 'Aaj Tak HD',
      streamUrl: 'http://x/2.m3u8',
      category: ChannelCategory.news,
      languages: ['hi'],
    );

    test('category filter matches only that category', () {
      const q = RailQuery(category: ChannelCategory.sports);
      expect(q.matches(sports), isTrue);
      expect(q.matches(news), isFalse);
    });

    test('language filter matches any listed language', () {
      const q = RailQuery(language: 'hi');
      expect(q.matches(sports), isTrue);
      expect(q.matches(news), isTrue);
      const en = RailQuery(language: 'ta');
      expect(en.matches(news), isFalse);
    });

    test('empty query matches everything', () {
      const q = RailQuery();
      expect(q.matches(sports), isTrue);
      expect(q.matches(news), isTrue);
    });
  });

  test('RailDefinition equality is value-based', () {
    const a = RailDefinition(
      id: 'live-sports',
      title: 'Live Sports',
      query: RailQuery(category: ChannelCategory.sports),
      priority: 10,
    );
    const b = RailDefinition(
      id: 'live-sports',
      title: 'Live Sports',
      query: RailQuery(category: ChannelCategory.sports),
      priority: 10,
    );
    expect(a, equals(b));
  });
}
