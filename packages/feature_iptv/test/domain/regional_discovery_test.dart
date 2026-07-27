import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const dd = IPTVChannel(
    id: 'DDNational.in',
    name: 'DD National',
    streamUrl: 'https://example.com/dd.m3u8',
    country: 'IN',
    category: ChannelCategory.entertainment,
    languages: ['hi'],
  );
  const aajTak = IPTVChannel(
    id: 'AajTak.in',
    name: 'Aaj Tak',
    streamUrl: 'https://example.com/aajtak.m3u8',
    country: 'in',
    category: ChannelCategory.news,
    languages: ['hi'],
  );
  const englishNews = IPTVChannel(
    id: 'news.in',
    name: 'India News English',
    streamUrl: 'https://example.com/news.m3u8',
    country: 'IN',
    category: ChannelCategory.news,
    languages: ['en'],
  );
  const foreign = IPTVChannel(
    id: 'foreign.gb',
    name: 'Foreign',
    streamUrl: 'https://example.com/foreign.m3u8',
    country: 'GB',
    category: ChannelCategory.news,
    languages: ['en'],
  );

  test('composes deterministic honest India rows with curated seed order', () {
    final rows = const RegionalDiscoveryComposer().compose(
      channels: const [dd, aajTak, englishNews, foreign],
      countryCode: 'in',
      countryName: 'India',
      languageNames: const {'hi': 'Hindi', 'en': 'English'},
      availabilityByChannelId: const {
        'AajTak.in': StreamAvailability.available,
        'DDNational.in': StreamAvailability.unavailable,
      },
    );

    expect(
      rows.map((row) => row.definition.title),
      containsAll(<String>[
        'Channels in India',
        'Curated for India',
        'News · India',
        'In Hindi',
        'Reliable now',
      ]),
    );
    expect(rows.first.channels.map((channel) => channel.id), [
      'AajTak.in',
      'news.in',
      'DDNational.in',
    ]);
    final curated = rows.singleWhere(
      (row) => row.definition.id == 'curated-IN',
    );
    expect(curated.channels.map((channel) => channel.id), [
      'DDNational.in',
      'AajTak.in',
    ]);
    final reliable = rows.singleWhere(
      (row) => row.definition.id == 'reliable-IN',
    );
    expect(reliable.channels.map((channel) => channel.id), ['AajTak.in']);
  });

  test('never emits fake popularity labels', () {
    final rows = const RegionalDiscoveryComposer().compose(
      channels: const [dd],
      countryCode: 'IN',
      countryName: 'India',
      languageNames: const {'hi': 'Hindi'},
    );
    final labels = rows
        .expand((row) => [row.definition.title, row.definition.subtitle ?? ''])
        .join(' ')
        .toLowerCase();

    expect(labels, isNot(contains('trending')));
    expect(labels, isNot(contains('popular')));
    expect(labels, isNot(contains('most watched')));
    expect(
      rows.where((row) => row.definition.id.startsWith('reliable-')),
      isEmpty,
    );
  });

  test('ignores missing curated IDs without changing surviving order', () {
    const seed = RegionalDiscoverySeed(
      countryCode: 'IN',
      title: 'Editors in India',
      channelIds: ['missing', 'AajTak.in', 'DDNational.in'],
    );
    final rows = const RegionalDiscoveryComposer().compose(
      channels: const [dd, aajTak],
      countryCode: 'IN',
      countryName: 'India',
      languageNames: const {'hi': 'Hindi'},
      seeds: const [seed],
    );

    expect(
      rows
          .singleWhere((row) => row.definition.id == 'curated-IN')
          .channels
          .map((channel) => channel.id),
      ['AajTak.in', 'DDNational.in'],
    );
  });
}
