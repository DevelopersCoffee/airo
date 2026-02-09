import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';
import 'package:airo_app/features/media_hub/domain/models/media_category.dart';
import 'package:airo_app/features/media_hub/domain/models/player_display_mode.dart';
import 'package:airo_app/features/media_hub/domain/models/quality_settings.dart';
import 'package:airo_app/features/media_hub/domain/models/unified_media_content.dart';
import 'package:airo_app/features/media_hub/domain/models/discovery_state.dart';
import 'package:airo_app/features/media_hub/domain/models/personalization_state.dart';
import 'package:airo_app/features/iptv/domain/models/iptv_channel.dart';
import 'package:airo_app/features/music/domain/services/music_service.dart';

void main() {
  group('MediaMode', () {
    test('music mode has correct properties', () {
      expect(MediaMode.music.label, 'Music');
      expect(MediaMode.music.icon, Icons.music_note);
      expect(MediaMode.music.isMusic, isTrue);
      expect(MediaMode.music.isTV, isFalse);
    });

    test('tv mode has correct properties', () {
      expect(MediaMode.tv.label, 'TV');
      expect(MediaMode.tv.icon, Icons.live_tv);
      expect(MediaMode.tv.isMusic, isFalse);
      expect(MediaMode.tv.isTV, isTrue);
    });

    test('values contain all modes', () {
      expect(MediaMode.values.length, 2);
      expect(MediaMode.values, contains(MediaMode.music));
      expect(MediaMode.values, contains(MediaMode.tv));
    });
  });

  group('MediaCategory', () {
    test('creates category with required fields', () {
      const category = MediaCategory(
        id: 'test_category',
        label: 'Test Category',
        mode: MediaMode.music,
      );

      expect(category.id, 'test_category');
      expect(category.label, 'Test Category');
      expect(category.mode, MediaMode.music);
      expect(category.icon, isNull);
    });

    test('creates category with icon', () {
      const category = MediaCategory(
        id: 'test',
        label: 'Test',
        icon: Icons.music_note,
        mode: MediaMode.music,
      );

      expect(category.icon, Icons.music_note);
    });

    test('equality works correctly', () {
      const cat1 = MediaCategory(
        id: 'test',
        label: 'Test',
        mode: MediaMode.music,
      );
      const cat2 = MediaCategory(
        id: 'test',
        label: 'Different',
        mode: MediaMode.music,
      );
      const cat3 = MediaCategory(
        id: 'other',
        label: 'Test',
        mode: MediaMode.music,
      );

      expect(cat1, equals(cat2)); // Same id and mode
      expect(cat1, isNot(equals(cat3))); // Different id
    });
  });

  group('MediaCategories', () {
    test('tvCategories returns 6 categories', () {
      expect(MediaCategories.tvCategories.length, 6);
      expect(
        MediaCategories.tvCategories.every((c) => c.mode == MediaMode.tv),
        isTrue,
      );
    });

    test('musicCategories returns 6 categories', () {
      expect(MediaCategories.musicCategories.length, 6);
      expect(
        MediaCategories.musicCategories.every((c) => c.mode == MediaMode.music),
        isTrue,
      );
    });

    test('forMode returns correct categories', () {
      expect(
        MediaCategories.forMode(MediaMode.tv),
        MediaCategories.tvCategories,
      );
      expect(
        MediaCategories.forMode(MediaMode.music),
        MediaCategories.musicCategories,
      );
    });

    test('findById returns correct category', () {
      expect(MediaCategories.findById('tv_live'), MediaCategories.tvLive);
      expect(
        MediaCategories.findById('music_trending'),
        MediaCategories.musicTrending,
      );
      expect(MediaCategories.findById('nonexistent'), isNull);
    });
  });

  group('PlayerDisplayMode', () {
    test('contains all expected modes', () {
      expect(PlayerDisplayMode.values.length, 5);
      expect(PlayerDisplayMode.values, contains(PlayerDisplayMode.collapsed));
      expect(PlayerDisplayMode.values, contains(PlayerDisplayMode.expanded));
      expect(PlayerDisplayMode.values, contains(PlayerDisplayMode.fullscreen));
      expect(PlayerDisplayMode.values, contains(PlayerDisplayMode.mini));
      expect(PlayerDisplayMode.values, contains(PlayerDisplayMode.hidden));
    });
  });

  group('QualitySettings', () {
    test('creates with default values', () {
      const settings = QualitySettings();

      expect(settings.videoQuality, VideoQuality.auto);
      expect(settings.audioLanguage, isNull);
      expect(settings.playbackSpeed, 1.0);
      expect(settings.isAutoQuality, isTrue);
      expect(settings.isNormalSpeed, isTrue);
      expect(settings.speedLabel, '1.0x');
    });

    test('creates with custom values', () {
      const settings = QualitySettings(
        videoQuality: VideoQuality.high,
        audioLanguage: 'en',
        playbackSpeed: 1.5,
      );

      expect(settings.videoQuality, VideoQuality.high);
      expect(settings.audioLanguage, 'en');
      expect(settings.playbackSpeed, 1.5);
      expect(settings.isAutoQuality, isFalse);
      expect(settings.isNormalSpeed, isFalse);
      expect(settings.speedLabel, '1.5x');
    });

    test('copyWith updates fields correctly', () {
      const original = QualitySettings();
      final updated = original.copyWith(
        videoQuality: VideoQuality.high,
        playbackSpeed: 2.0,
      );

      expect(updated.videoQuality, VideoQuality.high);
      expect(updated.playbackSpeed, 2.0);
      expect(updated.audioLanguage, isNull);
    });

    test('availableSpeeds contains expected values', () {
      expect(QualitySettings.availableSpeeds, [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]);
    });

    test('toJson/fromJson round trip works', () {
      const original = QualitySettings(
        videoQuality: VideoQuality.high,
        audioLanguage: 'es',
        playbackSpeed: 1.25,
      );

      final json = original.toJson();
      final restored = QualitySettings.fromJson(json);

      expect(restored, equals(original));
    });
  });

  group('UnifiedMediaContent', () {
    test('creates content with required fields', () {
      const content = UnifiedMediaContent(
        id: 'test_1',
        title: 'Test Content',
        type: MediaMode.music,
      );

      expect(content.id, 'test_1');
      expect(content.title, 'Test Content');
      expect(content.type, MediaMode.music);
      expect(content.isMusic, isTrue);
      expect(content.isTV, isFalse);
      expect(content.isLive, isFalse);
      expect(content.canResume, isFalse);
    });

    test('creates TV content with all fields', () {
      const content = UnifiedMediaContent(
        id: 'tv_1',
        title: 'Live Channel',
        subtitle: 'News',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        streamUrl: 'https://example.com/stream.m3u8',
        type: MediaMode.tv,
        isLive: true,
        viewerCount: 1000,
        tags: ['news', 'live'],
      );

      expect(content.isTV, isTrue);
      expect(content.isLive, isTrue);
      expect(content.viewerCount, 1000);
      expect(content.tags, ['news', 'live']);
    });

    test('canResume returns true when position > 10 seconds', () {
      const content = UnifiedMediaContent(
        id: 'test',
        title: 'Test',
        type: MediaMode.music,
        lastPosition: Duration(seconds: 15),
      );

      expect(content.canResume, isTrue);
    });

    test('canResume returns false when position <= 10 seconds', () {
      const content = UnifiedMediaContent(
        id: 'test',
        title: 'Test',
        type: MediaMode.music,
        lastPosition: Duration(seconds: 5),
      );

      expect(content.canResume, isFalse);
    });

    test('progress returns correct value', () {
      const content = UnifiedMediaContent(
        id: 'test',
        title: 'Test',
        type: MediaMode.music,
        duration: Duration(minutes: 4),
        lastPosition: Duration(minutes: 2),
      );

      expect(content.progress, closeTo(0.5, 0.01));
    });

    test('progress returns 0 when no duration', () {
      const content = UnifiedMediaContent(
        id: 'test',
        title: 'Test',
        type: MediaMode.music,
        lastPosition: Duration(minutes: 2),
      );

      expect(content.progress, 0.0);
    });

    test('copyWith updates fields correctly', () {
      const original = UnifiedMediaContent(
        id: 'test',
        title: 'Original',
        type: MediaMode.music,
      );

      final updated = original.copyWith(
        title: 'Updated',
        isLive: true,
        lastPosition: const Duration(seconds: 30),
      );

      expect(updated.id, 'test');
      expect(updated.title, 'Updated');
      expect(updated.isLive, isTrue);
      expect(updated.lastPosition, const Duration(seconds: 30));
    });

    test('equality is based on id and type', () {
      const content1 = UnifiedMediaContent(
        id: 'test',
        title: 'Title 1',
        type: MediaMode.music,
      );
      const content2 = UnifiedMediaContent(
        id: 'test',
        title: 'Title 2',
        type: MediaMode.music,
      );
      const content3 = UnifiedMediaContent(
        id: 'test',
        title: 'Title 1',
        type: MediaMode.tv,
      );

      expect(content1, equals(content2)); // Same id and type
      expect(content1, isNot(equals(content3))); // Different type
    });

    group('fromChannel factory', () {
      test('creates content from IPTVChannel with all fields', () {
        const channel = IPTVChannel(
          id: 'ch_123',
          name: 'News Channel',
          streamUrl: 'https://stream.example.com/news.m3u8',
          logoUrl: 'https://example.com/logo.png',
          group: 'News Group',
          category: ChannelCategory.news,
          languages: ['en', 'es'],
        );

        final content = UnifiedMediaContent.fromChannel(channel);

        expect(content.id, 'tv_ch_123');
        expect(content.title, 'News Channel');
        expect(content.subtitle, 'News Group');
        expect(content.thumbnailUrl, 'https://example.com/logo.png');
        expect(content.streamUrl, 'https://stream.example.com/news.m3u8');
        expect(content.type, MediaMode.tv);
        expect(content.isTV, isTrue);
        expect(content.isLive, isTrue);
        expect(content.category?.id, 'tv_news');
        expect(content.tags, contains('News'));
        expect(content.tags, containsAll(['en', 'es']));
      });

      test('maps movie category correctly', () {
        const channel = IPTVChannel(
          id: 'ch_movie',
          name: 'Movie Channel',
          streamUrl: 'https://stream.example.com/movie.m3u8',
          category: ChannelCategory.movies,
        );

        final content = UnifiedMediaContent.fromChannel(channel);

        expect(content.category?.id, 'tv_movies');
        expect(content.category?.label, 'Movies');
      });

      test('maps kids category correctly', () {
        const channel = IPTVChannel(
          id: 'ch_kids',
          name: 'Kids Channel',
          streamUrl: 'https://stream.example.com/kids.m3u8',
          category: ChannelCategory.kids,
        );

        final content = UnifiedMediaContent.fromChannel(channel);

        expect(content.category?.id, 'tv_kids');
        expect(content.category?.label, 'Kids');
      });

      test('maps music category correctly', () {
        const channel = IPTVChannel(
          id: 'ch_music',
          name: 'Music Channel',
          streamUrl: 'https://stream.example.com/music.m3u8',
          category: ChannelCategory.music,
        );

        final content = UnifiedMediaContent.fromChannel(channel);

        expect(content.category?.id, 'tv_music');
      });

      test('maps regional category correctly', () {
        const channel = IPTVChannel(
          id: 'ch_regional',
          name: 'Regional Channel',
          streamUrl: 'https://stream.example.com/regional.m3u8',
          category: ChannelCategory.regional,
        );

        final content = UnifiedMediaContent.fromChannel(channel);

        expect(content.category?.id, 'tv_regional');
      });

      test('maps all category to tvLive', () {
        const channel = IPTVChannel(
          id: 'ch_all',
          name: 'All Channel',
          streamUrl: 'https://stream.example.com/all.m3u8',
          category: ChannelCategory.all,
        );

        final content = UnifiedMediaContent.fromChannel(channel);

        // Default 'all' category maps to 'tvLive'
        expect(content.category?.id, 'tv_live');
      });

      test('handles channel without optional fields', () {
        const channel = IPTVChannel(
          id: 'ch_minimal',
          name: 'Minimal Channel',
          streamUrl: 'https://stream.example.com/minimal.m3u8',
        );

        final content = UnifiedMediaContent.fromChannel(channel);

        expect(content.id, 'tv_ch_minimal');
        expect(content.title, 'Minimal Channel');
        // group defaults to 'Uncategorized' in IPTVChannel
        expect(content.subtitle, 'Uncategorized');
        expect(content.thumbnailUrl, isNull);
        expect(content.isLive, isTrue);
      });
    });

    group('fromTrack factory', () {
      test('creates content from MusicTrack with all fields', () {
        const track = MusicTrack(
          id: 'track_123',
          title: 'My Song',
          artist: 'Famous Artist',
          albumArt: 'https://example.com/album.jpg',
          duration: Duration(minutes: 3, seconds: 30),
          streamUrl: 'https://stream.example.com/song.mp3',
        );

        final content = UnifiedMediaContent.fromTrack(track);

        expect(content.id, 'music_track_123');
        expect(content.title, 'My Song');
        expect(content.subtitle, 'Famous Artist');
        expect(content.thumbnailUrl, 'https://example.com/album.jpg');
        expect(content.streamUrl, 'https://stream.example.com/song.mp3');
        expect(content.type, MediaMode.music);
        expect(content.isMusic, isTrue);
        expect(content.isLive, isFalse);
        expect(content.duration, const Duration(minutes: 3, seconds: 30));
      });

      test('handles track without optional fields', () {
        const track = MusicTrack(
          id: 'track_minimal',
          title: 'Minimal Song',
          artist: 'Unknown Artist',
          duration: Duration.zero,
        );

        final content = UnifiedMediaContent.fromTrack(track);

        expect(content.id, 'music_track_minimal');
        expect(content.title, 'Minimal Song');
        expect(content.subtitle, 'Unknown Artist');
        expect(content.thumbnailUrl, isNull);
        expect(content.streamUrl, isNull);
        expect(content.duration, Duration.zero);
        expect(content.isLive, isFalse);
      });

      test('track content is not resumable by default', () {
        const track = MusicTrack(
          id: 'track_test',
          title: 'Test Song',
          artist: 'Test Artist',
          duration: Duration(minutes: 5),
        );

        final content = UnifiedMediaContent.fromTrack(track);

        expect(content.canResume, isFalse);
        expect(content.lastPosition, isNull);
      });
    });
  });

  group('DiscoveryState', () {
    test('creates with default values', () {
      const state = DiscoveryState();

      expect(state.currentMode, MediaMode.music);
      expect(state.selectedCategory, isNull);
      expect(state.contentItems, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.searchQuery, isNull);
      expect(state.hasMore, isTrue);
      expect(state.isSearching, isFalse);
      expect(state.hasError, isFalse);
      expect(state.isEmpty, isTrue);
    });

    test('availableCategories returns mode-specific categories', () {
      const musicState = DiscoveryState(currentMode: MediaMode.music);
      const tvState = DiscoveryState(currentMode: MediaMode.tv);

      expect(musicState.availableCategories, MediaCategories.musicCategories);
      expect(tvState.availableCategories, MediaCategories.tvCategories);
    });

    test('filteredContent filters by selected category', () {
      final content = [
        const UnifiedMediaContent(
          id: '1',
          title: 'News Show',
          type: MediaMode.tv,
          category: MediaCategories.tvNews,
        ),
        const UnifiedMediaContent(
          id: '2',
          title: 'Movie',
          type: MediaMode.tv,
          category: MediaCategories.tvMovies,
        ),
      ];

      final state = DiscoveryState(
        contentItems: content,
        selectedCategory: MediaCategories.tvNews,
      );

      expect(state.filteredContent.length, 1);
      expect(state.filteredContent.first.id, '1');
    });

    test('modeFilteredContent filters by current mode', () {
      final content = [
        const UnifiedMediaContent(
          id: '1',
          title: 'Song',
          type: MediaMode.music,
        ),
        const UnifiedMediaContent(
          id: '2',
          title: 'Channel',
          type: MediaMode.tv,
        ),
      ];

      final state = DiscoveryState(
        currentMode: MediaMode.music,
        contentItems: content,
      );

      expect(state.modeFilteredContent.length, 1);
      expect(state.modeFilteredContent.first.id, '1');
    });

    test('isSearching returns true when query is not empty', () {
      const state = DiscoveryState(searchQuery: 'test');
      expect(state.isSearching, isTrue);
    });

    test('copyWith with clearCategory clears category', () {
      const state = DiscoveryState(selectedCategory: MediaCategories.tvNews);
      final updated = state.copyWith(clearCategory: true);

      expect(updated.selectedCategory, isNull);
    });

    test('copyWith with clearError clears error', () {
      const state = DiscoveryState(errorMessage: 'Error');
      final updated = state.copyWith(clearError: true);

      expect(updated.errorMessage, isNull);
    });
  });

  group('PersonalizationState', () {
    test('creates with default values', () {
      const state = PersonalizationState();

      expect(state.continueWatching, isEmpty);
      expect(state.recentlyPlayed, isEmpty);
      expect(state.favoriteIds, isEmpty);
      expect(state.playbackPositions, isEmpty);
      expect(state.favoritesCount, 0);
      expect(state.continueWatchingCount, 0);
    });

    test('isFavorite returns correct value', () {
      const state = PersonalizationState(
        favoriteIds: {'content_1', 'content_2'},
      );

      expect(state.isFavorite('content_1'), isTrue);
      expect(state.isFavorite('content_3'), isFalse);
    });

    test('getLastPosition returns correct duration', () {
      final state = PersonalizationState(
        playbackPositions: {'content_1': const Duration(seconds: 120)},
      );

      expect(state.getLastPosition('content_1'), const Duration(seconds: 120));
      expect(state.getLastPosition('content_2'), isNull);
    });

    test('canResume returns true for position > 10 seconds', () {
      final state = PersonalizationState(
        playbackPositions: {
          'content_1': const Duration(seconds: 30),
          'content_2': const Duration(seconds: 5),
        },
      );

      expect(state.canResume('content_1'), isTrue);
      expect(state.canResume('content_2'), isFalse);
      expect(state.canResume('content_3'), isFalse);
    });

    test('getProgress returns correct value', () {
      final state = PersonalizationState(
        playbackPositions: {'content_1': const Duration(minutes: 2)},
      );

      expect(
        state.getProgress('content_1', const Duration(minutes: 4)),
        closeTo(0.5, 0.01),
      );
      expect(state.getProgress('content_2', const Duration(minutes: 4)), 0.0);
      expect(state.getProgress('content_1', null), 0.0);
    });

    test('toJson/fromJson round trip works', () {
      final original = PersonalizationState(
        favoriteIds: const {'fav_1', 'fav_2'},
        playbackPositions: const {
          'content_1': Duration(seconds: 120),
          'content_2': Duration(minutes: 5),
        },
      );

      final json = original.toJson();
      final restored = PersonalizationState.fromJson(json);

      expect(restored.favoriteIds, original.favoriteIds);
      expect(restored.playbackPositions, original.playbackPositions);
    });

    test('maxRecentItems and maxContinueItems are correct', () {
      expect(PersonalizationState.maxRecentItems, 50);
      expect(PersonalizationState.maxContinueItems, 20);
    });
  });
}
