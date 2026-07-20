import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  group('IPTVChannel group normalization', () {
    test('fromM3U maps sentinel "Undefined" group to Uncategorized', () {
      final channel = IPTVChannel.fromM3U(
        name: 'Leaderboard Sports News',
        url: 'https://cdn.example.com/live.m3u8',
        group: 'Undefined',
      );

      expect(channel.group, 'Uncategorized');
    });

    test('fromM3U maps case-insensitive sentinel values', () {
      for (final raw in ['undefined', 'UNDEFINED', 'N/A', 'none', 'null']) {
        final channel = IPTVChannel.fromM3U(
          name: 'Channel',
          url: 'https://cdn.example.com/live.m3u8',
          group: raw,
        );
        expect(channel.group, 'Uncategorized', reason: 'raw group: $raw');
      }
    });

    test('fromM3U maps empty/whitespace group to Uncategorized', () {
      final channel = IPTVChannel.fromM3U(
        name: 'Channel',
        url: 'https://cdn.example.com/live.m3u8',
        group: '   ',
      );

      expect(channel.group, 'Uncategorized');
    });

    test('fromM3U preserves a real provider group', () {
      final channel = IPTVChannel.fromM3U(
        name: 'Channel',
        url: 'https://cdn.example.com/live.m3u8',
        group: 'Sports HD',
      );

      expect(channel.group, 'Sports HD');
    });

    test('fromJson maps sentinel group to Uncategorized', () {
      final channel = IPTVChannel.fromJson(const {
        'id': '1',
        'name': 'Leaderboard Sports News',
        'streamUrl': 'https://cdn.example.com/live.m3u8',
        'group': 'Undefined',
      });

      expect(channel.group, 'Uncategorized');
    });

    test('fromJson preserves a real provider group', () {
      final channel = IPTVChannel.fromJson(const {
        'id': '1',
        'name': 'Channel',
        'streamUrl': 'https://cdn.example.com/live.m3u8',
        'group': 'News',
      });

      expect(channel.group, 'News');
    });
  });
}
