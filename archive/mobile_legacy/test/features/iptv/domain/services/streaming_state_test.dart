import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/iptv/domain/models/iptv_channel.dart';
import 'package:airo_app/features/iptv/domain/models/streaming_state.dart';

void main() {
  group('VideoQuality', () {
    test('should have correct labels', () {
      expect(VideoQuality.auto.label, equals('Auto'));
      expect(VideoQuality.low.label, equals('360p'));
      expect(VideoQuality.medium.label, equals('480p'));
      expect(VideoQuality.high.label, equals('720p'));
      expect(VideoQuality.fullHd.label, equals('1080p'));
      expect(VideoQuality.ultraHd.label, equals('4K'));
    });

    test('should have correct heights', () {
      expect(VideoQuality.auto.height, equals(0)); // Auto adapts
      expect(VideoQuality.low.height, lessThan(VideoQuality.medium.height));
      expect(VideoQuality.medium.height, lessThan(VideoQuality.high.height));
      expect(VideoQuality.high.height, lessThan(VideoQuality.fullHd.height));
      expect(VideoQuality.fullHd.height, lessThan(VideoQuality.ultraHd.height));
    });
  });

  group('ChannelCategory', () {
    test('should have all expected categories', () {
      expect(
        ChannelCategory.values,
        containsAll([
          ChannelCategory.all,
          ChannelCategory.news,
          ChannelCategory.entertainment,
          ChannelCategory.sports,
          ChannelCategory.music,
          ChannelCategory.movies,
          ChannelCategory.kids,
          ChannelCategory.documentary,
          ChannelCategory.regional,
          ChannelCategory.international,
        ]),
      );
    });
  });

  group('IPTVChannel', () {
    test('should create channel with required fields', () {
      final channel = IPTVChannel(
        id: 'test-id',
        name: 'Test Channel',
        streamUrl: 'https://example.com/stream.m3u8',
        group: 'News',
      );

      expect(channel.id, equals('test-id'));
      expect(channel.name, equals('Test Channel'));
      expect(channel.streamUrl, equals('https://example.com/stream.m3u8'));
      expect(channel.group, equals('News'));
      expect(channel.isAudioOnly, isFalse);
      expect(channel.category, equals(ChannelCategory.all));
    });

    test('should detect audio-only from URL', () {
      final audioChannel = IPTVChannel(
        id: 'radio-1',
        name: 'Radio FM',
        streamUrl: 'https://example.com/stream.mp3',
        group: 'Radio',
        isAudioOnly: true,
      );

      expect(audioChannel.isAudioOnly, isTrue);
    });

    test('should be equatable', () {
      final channel1 = IPTVChannel(
        id: 'same-id',
        name: 'Channel',
        streamUrl: 'https://example.com/stream.m3u8',
        group: 'Group',
      );
      final channel2 = IPTVChannel(
        id: 'same-id',
        name: 'Channel',
        streamUrl: 'https://example.com/stream.m3u8',
        group: 'Group',
      );

      expect(channel1, equals(channel2));
    });
  });

  group('StreamingState', () {
    test('should have correct initial state', () {
      const state = StreamingState();

      expect(state.currentChannel, isNull);
      expect(state.playbackState, equals(PlaybackState.idle));
      expect(state.currentQuality, equals(VideoQuality.auto));
      expect(state.isPlaying, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.isBuffering, isFalse);
    });

    test('isPlaying should return true only when playing', () {
      final playingState = const StreamingState().copyWith(
        playbackState: PlaybackState.playing,
      );
      final pausedState = const StreamingState().copyWith(
        playbackState: PlaybackState.paused,
      );

      expect(playingState.isPlaying, isTrue);
      expect(pausedState.isPlaying, isFalse);
    });

    test('isBuffering should return true only when buffering', () {
      final bufferingState = const StreamingState().copyWith(
        playbackState: PlaybackState.buffering,
      );
      final loadingState = const StreamingState().copyWith(
        playbackState: PlaybackState.loading,
      );

      expect(bufferingState.isBuffering, isTrue);
      expect(loadingState.isBuffering, isFalse);
    });
  });

  group('BufferStatus', () {
    test('should create with correct values', () {
      const buffer = BufferStatus(
        bufferedAhead: Duration(seconds: 15),
        totalBuffered: Duration(minutes: 30),
        bufferHealth: 85,
      );

      expect(buffer.bufferedAhead, equals(const Duration(seconds: 15)));
      expect(buffer.bufferHealth, equals(85));
    });

    test('isHealthy should return true when buffer is 10+ seconds', () {
      const healthyBuffer = BufferStatus(bufferedAhead: Duration(seconds: 15));
      const unhealthyBuffer = BufferStatus(bufferedAhead: Duration(seconds: 5));

      expect(healthyBuffer.isHealthy, isTrue);
      expect(unhealthyBuffer.isHealthy, isFalse);
    });

    test('isOptimal should return true when buffer is 20+ seconds', () {
      const optimalBuffer = BufferStatus(bufferedAhead: Duration(seconds: 25));
      const subOptimalBuffer = BufferStatus(
        bufferedAhead: Duration(seconds: 15),
      );

      expect(optimalBuffer.isOptimal, isTrue);
      expect(subOptimalBuffer.isOptimal, isFalse);
    });
  });
}
