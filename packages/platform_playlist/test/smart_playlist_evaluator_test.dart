import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  final evaluator = SmartPlaylistEvaluator();

  IPTVChannel channel({
    required String id,
    required String name,
    required String group,
    List<String> languages = const ['en'],
    ChannelCategory category = ChannelCategory.general,
  }) {
    return IPTVChannel(
      id: id,
      name: name,
      streamUrl: 'https://example.com/$id.m3u8',
      group: group,
      category: category,
      languages: languages,
    );
  }

  test('no-op rule returns every channel unchanged', () {
    final channels = [
      channel(id: '1', name: 'News', group: 'News'),
      channel(id: '2', name: 'Movie', group: 'Movies'),
    ];

    final result = evaluator.apply(const SmartPlaylistRule(), channels);

    expect(result, channels);
  });

  test('excludeAdult removes channels whose group looks adult-shaped', () {
    final channels = [
      channel(id: '1', name: 'News', group: 'News'),
      channel(id: '2', name: 'XXX Prime', group: 'Adult XXX'),
    ];

    final result = evaluator.apply(
      const SmartPlaylistRule(excludeAdult: true),
      channels,
    );

    expect(result.map((c) => c.id), ['1']);
  });

  test('excludeVod removes VOD-shaped channels (category or group)', () {
    final channels = [
      channel(id: '1', name: 'News', group: 'News'),
      channel(
        id: '2',
        name: 'Movie',
        group: 'Movies',
        category: ChannelCategory.movies,
      ),
      channel(id: '3', name: 'Some Title', group: 'US VOD'),
    ];

    final result = evaluator.apply(
      const SmartPlaylistRule(excludeVod: true),
      channels,
    );

    expect(result.map((c) => c.id), ['1']);
  });

  test('excludeRadio removes radio-shaped channels by group', () {
    final channels = [
      channel(id: '1', name: 'News', group: 'News'),
      channel(id: '2', name: 'FM 101', group: 'Radio Stations'),
    ];

    final result = evaluator.apply(
      const SmartPlaylistRule(excludeRadio: true),
      channels,
    );

    expect(result.map((c) => c.id), ['1']);
  });

  test(
    'allowedLanguages keeps only channels matching one of the languages',
    () {
      final channels = [
        channel(id: '1', name: 'BBC', group: 'News', languages: ['en']),
        channel(id: '2', name: 'TF1', group: 'News', languages: ['fr']),
      ];

      final result = evaluator.apply(
        const SmartPlaylistRule(allowedLanguages: {'en'}),
        channels,
      );

      expect(result.map((c) => c.id), ['1']);
    },
  );

  test('explicit exclude wins even when the channel would otherwise pass', () {
    final channels = [
      channel(id: '1', name: 'News', group: 'News'),
      channel(id: '2', name: 'Other News', group: 'News'),
    ];

    final result = evaluator.apply(
      const SmartPlaylistRule(explicitExcludeChannelIds: {'2'}),
      channels,
    );

    expect(result.map((c) => c.id), ['1']);
  });

  test(
    'explicit include always keeps a channel even if it fails other filters',
    () {
      final channels = [
        channel(id: '1', name: 'News', group: 'News'),
        channel(id: '2', name: 'FM 101', group: 'Radio Stations'),
      ];

      final result = evaluator.apply(
        const SmartPlaylistRule(
          excludeRadio: true,
          explicitIncludeChannelIds: {'2'},
        ),
        channels,
      );

      expect(result.map((c) => c.id).toSet(), {'1', '2'});
    },
  );

  test('combines multiple exclusion rules', () {
    final channels = [
      channel(id: '1', name: 'News', group: 'News'),
      channel(id: '2', name: 'XXX Prime', group: 'Adult XXX'),
      channel(id: '3', name: 'FM 101', group: 'Radio Stations'),
      channel(
        id: '4',
        name: 'Movie',
        group: 'Movies',
        category: ChannelCategory.movies,
      ),
    ];

    final result = evaluator.apply(
      const SmartPlaylistRule(
        excludeAdult: true,
        excludeRadio: true,
        excludeVod: true,
      ),
      channels,
    );

    expect(result.map((c) => c.id), ['1']);
  });

  test('empty source list yields empty result', () {
    expect(
      evaluator.apply(const SmartPlaylistRule(excludeAdult: true), const []),
      isEmpty,
    );
  });
}
