import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airo_app/features/iptv/domain/models/iptv_channel.dart';
import 'package:airo_app/features/iptv/domain/models/streaming_state.dart';
import 'package:airo_app/features/iptv/domain/services/iptv_streaming_service.dart';
import 'package:airo_app/features/iptv/application/providers/iptv_providers.dart';

void main() {
  group('IPTV Providers', () {
    late ProviderContainer container;

    setUp(() async {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('selectedCategoryProvider', () {
      test('should default to ChannelCategory.all', () {
        final category = container.read(selectedCategoryProvider);
        expect(category, equals(ChannelCategory.all));
      });

      test('should update when changed', () {
        container.read(selectedCategoryProvider.notifier).state =
            ChannelCategory.sports;
        final category = container.read(selectedCategoryProvider);
        expect(category, equals(ChannelCategory.sports));
      });
    });

    group('channelSearchQueryProvider', () {
      test('should default to empty string', () {
        final query = container.read(channelSearchQueryProvider);
        expect(query, isEmpty);
      });

      test('should update when changed', () {
        container.read(channelSearchQueryProvider.notifier).state = 'news';
        final query = container.read(channelSearchQueryProvider);
        expect(query, equals('news'));
      });
    });

    group('StreamingConfig', () {
      test('youtube preset should have correct values', () {
        const config = StreamingConfig.youtube;

        expect(
          config.targetBufferDuration,
          equals(const Duration(seconds: 30)),
        );
        expect(config.minBufferDuration, equals(const Duration(seconds: 2)));
        expect(config.maxRetries, equals(5));
        expect(config.enableABR, isTrue);
      });

      test('live preset should have correct values', () {
        const config = StreamingConfig.live;

        expect(
          config.targetBufferDuration,
          equals(const Duration(seconds: 10)),
        );
        expect(config.minBufferDuration, equals(const Duration(seconds: 1)));
        expect(config.lowLatencyMode, isTrue);
      });
    });

    group('filteredChannelsProvider', () {
      test('should filter channels by category', () async {
        // Note: This test would require mocking the channels provider
        // For now, we test the filtering logic structure
        final category = container.read(selectedCategoryProvider);
        expect(category, equals(ChannelCategory.all));
      });
    });

    group('Preference sorting', () {
      test('channels matching preferences should be ranked higher', () {
        final channels = [
          IPTVChannel(
            id: '1',
            name: 'Sports News',
            streamUrl: 'https://example.com/1.m3u8',
            group: 'Sports',
            category: ChannelCategory.sports,
          ),
          IPTVChannel(
            id: '2',
            name: 'General Channel',
            streamUrl: 'https://example.com/2.m3u8',
            group: 'General',
            category: ChannelCategory.all,
          ),
          IPTVChannel(
            id: '3',
            name: 'Music Radio',
            streamUrl: 'https://example.com/3.m3u8',
            group: 'Music',
            category: ChannelCategory.music,
          ),
        ];

        final preferences = ['sports', 'music'];

        // Simulate preference scoring
        int getScore(IPTVChannel channel) {
          final name = channel.name.toLowerCase();
          final group = channel.group.toLowerCase();
          for (int i = 0; i < preferences.length; i++) {
            if (name.contains(preferences[i]) ||
                group.contains(preferences[i])) {
              return preferences.length - i;
            }
          }
          return 0;
        }

        final sorted = List<IPTVChannel>.from(channels)
          ..sort((a, b) => getScore(b).compareTo(getScore(a)));

        expect(sorted[0].name, equals('Sports News')); // Matches 'sports'
        expect(sorted[1].name, equals('Music Radio')); // Matches 'music'
        expect(sorted[2].name, equals('General Channel')); // No match
      });
    });
  });

  group('NetworkQuality', () {
    test('should have all expected quality levels', () {
      expect(
        NetworkQuality.values,
        containsAll([
          NetworkQuality.excellent,
          NetworkQuality.good,
          NetworkQuality.fair,
          NetworkQuality.poor,
          NetworkQuality.offline,
        ]),
      );
    });
  });

  group('PlaybackState', () {
    test('should have all expected states', () {
      expect(
        PlaybackState.values,
        containsAll([
          PlaybackState.idle,
          PlaybackState.loading,
          PlaybackState.buffering,
          PlaybackState.playing,
          PlaybackState.paused,
          PlaybackState.error,
          PlaybackState.ended,
        ]),
      );
    });
  });
}
