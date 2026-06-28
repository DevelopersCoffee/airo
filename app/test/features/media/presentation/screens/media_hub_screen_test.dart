import 'package:airo_app/features/media/presentation/screens/media_hub_screen.dart';
import 'package:airo_app/features/media_hub/domain/models/media_category.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';
import 'package:airo_app/features/media_hub/domain/models/personalization_state.dart';
import 'package:airo_app/features/media_hub/domain/models/unified_media_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recentItemsForSection filters content by active media section', () {
    const musicItem = UnifiedMediaContent(
      id: 'track-1',
      mode: MediaMode.music,
      category: MediaCategory.music,
      title: 'Track',
      subtitle: 'Artist',
      imageUrl: null,
      streamUrl: 'https://example.com/audio.mp3',
    );
    const tvItem = UnifiedMediaContent(
      id: 'tv-1',
      mode: MediaMode.tv,
      category: MediaCategory.news,
      title: 'News',
      subtitle: 'TV',
      imageUrl: null,
      streamUrl: 'https://example.com/live.m3u8',
    );
    const state = PersonalizationState(recentlyPlayed: [musicItem, tvItem]);

    expect(recentItemsForSection(state, MediaSection.music), [musicItem]);
    expect(recentItemsForSection(state, MediaSection.tv), [tvItem]);
  });

  test('favoriteItemsForSection filters favorites by active media section', () {
    const musicItem = UnifiedMediaContent(
      id: 'track-1',
      mode: MediaMode.music,
      category: MediaCategory.music,
      title: 'Track',
      subtitle: 'Artist',
      imageUrl: null,
      streamUrl: 'https://example.com/audio.mp3',
    );
    const tvItem = UnifiedMediaContent(
      id: 'tv-1',
      mode: MediaMode.tv,
      category: MediaCategory.news,
      title: 'News',
      subtitle: 'TV',
      imageUrl: null,
      streamUrl: 'https://example.com/live.m3u8',
    );
    const state = PersonalizationState(favorites: [musicItem, tvItem]);

    expect(favoriteItemsForSection(state, MediaSection.music), [musicItem]);
    expect(favoriteItemsForSection(state, MediaSection.tv), [tvItem]);
  });

  test(
    'continueWatchingItemsForSection keeps resumable items over 10 seconds',
    () {
      const resumableMusic = UnifiedMediaContent(
        id: 'track-1',
        mode: MediaMode.music,
        category: MediaCategory.music,
        title: 'Track',
        subtitle: 'Artist',
        imageUrl: null,
        streamUrl: 'https://example.com/audio.mp3',
        duration: Duration(minutes: 3),
        lastPosition: Duration(seconds: 42),
      );
      const tooShort = UnifiedMediaContent(
        id: 'track-2',
        mode: MediaMode.music,
        category: MediaCategory.music,
        title: 'Short',
        subtitle: 'Artist',
        imageUrl: null,
        streamUrl: 'https://example.com/audio-2.mp3',
        duration: Duration(minutes: 3),
        lastPosition: Duration(seconds: 9),
      );
      const liveTv = UnifiedMediaContent(
        id: 'tv-1',
        mode: MediaMode.tv,
        category: MediaCategory.news,
        title: 'News',
        subtitle: 'TV',
        imageUrl: null,
        streamUrl: 'https://example.com/live.m3u8',
        isLive: true,
        lastPosition: Duration(minutes: 1),
      );
      const state = PersonalizationState(
        continueWatching: [resumableMusic, tooShort, liveTv],
      );

      expect(continueWatchingItemsForSection(state, MediaSection.music), [
        resumableMusic,
      ]);
      expect(continueWatchingItemsForSection(state, MediaSection.tv), isEmpty);
    },
  );

  test('mediaModeForSection maps sections to discovery modes', () {
    expect(mediaModeForSection(MediaSection.music), MediaMode.music);
    expect(mediaModeForSection(MediaSection.tv), MediaMode.tv);
  });
}
