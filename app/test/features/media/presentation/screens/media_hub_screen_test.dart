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
}
