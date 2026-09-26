import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  const matcher = CanonicalChannelMatcher();

  IPTVChannel channel({
    required String id,
    required String name,
    String? streamUrl,
    int? tvgId,
    String group = 'General',
  }) {
    return IPTVChannel(
      id: id,
      name: name,
      streamUrl: streamUrl ?? 'https://example.com/$id.m3u8',
      group: group,
      tvgId: tvgId,
    );
  }

  group('CanonicalChannelMatcher', () {
    test('matches with high confidence when channel ids agree', () {
      final a = channel(id: 'bbc', name: 'BBC One HD');
      final b = channel(id: 'bbc', name: 'BBC One');

      final result = matcher.match(a, b);

      expect(result.confidence, ChannelMatchConfidence.high);
      expect(result.reason, 'channel_id');
    });

    test('matches with high confidence when stream URLs agree', () {
      final a = channel(
        id: 'a',
        name: 'BBC One',
        streamUrl: 'https://cdn.example/bbc.m3u8',
      );
      final b = channel(
        id: 'b',
        name: 'Renamed',
        streamUrl: 'https://cdn.example/bbc.m3u8',
      );

      final result = matcher.match(a, b);

      expect(result.confidence, ChannelMatchConfidence.high);
      expect(result.reason, 'stream_url');
    });

    test('does not match on tvg-id alone in the public Play matcher', () {
      final a = channel(id: 'a', name: 'BBC One HD', tvgId: 101);
      final b = channel(id: 'b', name: 'Totally Different Label', tvgId: 101);

      final result = matcher.match(a, b);

      expect(result.confidence, ChannelMatchConfidence.none);
      expect(result.reason, 'no_match');
    });

    test('does not match on normalized name alone in the public Play matcher', () {
      final a = channel(id: 'a', name: 'BBC One HD');
      final b = channel(id: 'b', name: 'bbc-one');

      final result = matcher.match(a, b);

      expect(result.confidence, ChannelMatchConfidence.none);
    });

    test('does not match unrelated channels', () {
      final a = channel(id: 'a', name: 'BBC One');
      final b = channel(id: 'b', name: 'CNN International');

      final result = matcher.match(a, b);

      expect(result.confidence, ChannelMatchConfidence.none);
    });
  });

  group('ChannelNameNormalizer', () {
    final normalizer = ChannelNameNormalizer();

    test('strips quality/mirror suffixes: HD, FHD, 4K, Backup', () {
      expect(normalizer.normalize('BBC One HD'), 'bbc one');
      expect(normalizer.normalize('BBC One FHD'), 'bbc one');
      expect(normalizer.normalize('BBC One 4K'), 'bbc one');
      expect(normalizer.normalize('BBC One Backup'), 'bbc one');
    });

    test('keeps regional markers: East, West, US, UK', () {
      expect(normalizer.normalize('BBC One East'), 'bbc one east');
      expect(normalizer.normalize('BBC One West'), 'bbc one west');
      expect(normalizer.normalize('CNN US'), 'cnn us');
      expect(normalizer.normalize('CNN UK'), 'cnn uk');
    });

    test('is case-insensitive and separator-agnostic', () {
      expect(normalizer.normalize('BBC-One_HD'), 'bbc one');
      expect(normalizer.normalize('bbc.one.hd'), 'bbc one');
      expect(normalizer.normalize('BBC (One) [HD]'), 'bbc one');
    });
  });
}
