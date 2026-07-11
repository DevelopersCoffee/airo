import "package:feature_iptv/feature_iptv.dart";
import "package:platform_channels/platform_channels.dart";
import 'package:airo_app/features/media_hub/domain/models/media_category.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';
import 'package:airo_app/features/media_hub/domain/models/unified_media_content.dart';
import 'package:airo_app/features/music/domain/services/music_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnifiedMediaContent', () {
    test('creates music content from a track with resume support', () {
      const track = MusicTrack(
        id: 'track-1',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        albumArt: 'https://example.com/art.jpg',
        duration: Duration(minutes: 3, seconds: 20),
        streamUrl: 'https://example.com/audio.mp3',
      );

      final content = UnifiedMediaContent.fromTrack(
        track,
        lastPosition: const Duration(minutes: 1),
        tags: const ['pop'],
      );

      expect(content.mode, MediaMode.music);
      expect(content.category, MediaCategory.music);
      expect(content.title, 'Blinding Lights');
      expect(content.subtitle, 'The Weeknd');
      expect(content.imageUrl, 'https://example.com/art.jpg');
      expect(content.streamUrl, 'https://example.com/audio.mp3');
      expect(content.canResume, isTrue);
      expect(content.tags, ['pop']);
    });

    test('creates tv content from a channel without resume support', () {
      const channel = IPTVChannel(
        id: 'tv-1',
        name: 'Airo Sports',
        streamUrl: 'https://example.com/live.m3u8',
        logoUrl: 'https://example.com/logo.png',
        group: 'Live Sports',
        category: ChannelCategory.sports,
        languages: ['en', 'hi'],
      );

      final content = UnifiedMediaContent.fromChannel(
        channel,
        lastPosition: const Duration(minutes: 10),
        viewerCount: 4200,
      );

      expect(content.mode, MediaMode.tv);
      expect(content.category, MediaCategory.sports);
      expect(content.title, 'Airo Sports');
      expect(content.subtitle, 'Live Sports');
      expect(content.imageUrl, 'https://example.com/logo.png');
      expect(content.canResume, isFalse);
      expect(content.isLive, isTrue);
      expect(content.viewerCount, 4200);
      expect(content.tags, ['en', 'hi']);
    });

    test('supports equatable comparisons', () {
      const first = UnifiedMediaContent(
        id: 'same',
        mode: MediaMode.music,
        category: MediaCategory.music,
        title: 'Track',
        subtitle: 'Artist',
        imageUrl: null,
        streamUrl: 'https://example.com/audio.mp3',
      );
      const second = UnifiedMediaContent(
        id: 'same',
        mode: MediaMode.music,
        category: MediaCategory.music,
        title: 'Track',
        subtitle: 'Artist',
        imageUrl: null,
        streamUrl: 'https://example.com/audio.mp3',
      );

      expect(first, second);
      expect(first.props, second.props);
    });
  });
}
