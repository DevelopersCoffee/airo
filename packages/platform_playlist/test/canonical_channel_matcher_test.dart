import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  final matcher = CanonicalChannelMatcher();

  IPTVChannel channel({
    required String id,
    required String name,
    int? tvgId,
    String group = 'General',
  }) {
    return IPTVChannel(
      id: id,
      name: name,
      streamUrl: 'https://example.com/$id.m3u8',
      group: group,
      tvgId: tvgId,
    );
  }

  group('CanonicalChannelMatcher', () {
    test('matches with high confidence when tvg-id agrees', () {
      final a = channel(id: 'a', name: 'BBC One HD', tvgId: 101);
      final b = channel(id: 'b', name: 'Totally Different Label', tvgId: 101);

      final result = matcher.match(a, b);

      expect(result.confidence, ChannelMatchConfidence.high);
      expect(result.reason, 'tvg_id');
    });

    test('does not match on tvg-id when the ids differ', () {
      final a = channel(id: 'a', name: 'BBC One', tvgId: 101);
      final b = channel(id: 'b', name: 'BBC One', tvgId: 202);

      final result = matcher.match(a, b);

      // tvg-ids disagree -- falls through to name-based matching instead.
      expect(result.confidence, ChannelMatchConfidence.medium);
      expect(result.reason, 'normalized_name');
    });

    test('matches with medium confidence on normalized name alone', () {
      final a = channel(id: 'a', name: 'BBC One HD');
      final b = channel(id: 'b', name: 'bbc-one');

      final result = matcher.match(a, b);

      expect(result.confidence, ChannelMatchConfidence.medium);
      expect(result.reason, 'normalized_name');
    });

    test('does not match unrelated channels', () {
      final a = channel(id: 'a', name: 'BBC One');
      final b = channel(id: 'b', name: 'CNN International');

      final result = matcher.match(a, b);

      expect(result.confidence, ChannelMatchConfidence.none);
    });

    test(
      'keeps distinct regional variants separate despite a shared base name',
      () {
        final east = channel(id: 'a', name: 'BBC One East');
        final west = channel(id: 'b', name: 'BBC One West');

        final result = matcher.match(east, west);

        expect(result.confidence, ChannelMatchConfidence.none);
      },
    );
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
