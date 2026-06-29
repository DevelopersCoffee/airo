import 'package:airo_app/features/media_hub/domain/models/media_category.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';
import 'package:airo_app/features/media_hub/domain/models/personalization_state.dart';
import 'package:airo_app/features/media_hub/domain/models/unified_media_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PersonalizationState', () {
    const item = UnifiedMediaContent(
      id: 'track-1',
      mode: MediaMode.music,
      category: MediaCategory.music,
      title: 'Track',
      subtitle: 'Artist',
      imageUrl: null,
      streamUrl: 'https://example.com/audio.mp3',
      duration: Duration(minutes: 3),
      lastPosition: Duration(minutes: 1),
    );

    test('serializes and restores personalization lists', () {
      const state = PersonalizationState(
        favorites: [item],
        recentlyPlayed: [item],
        continueWatching: [item],
      );

      final restored = PersonalizationState.fromStorageValue(
        state.toStorageValue(),
      );

      expect(restored, state);
      expect(restored.isFavorite('track-1'), isTrue);
    });

    test('reports favorites by content id', () {
      const state = PersonalizationState(favorites: [item]);

      expect(state.isFavorite('track-1'), isTrue);
      expect(state.isFavorite('missing'), isFalse);
    });
  });
}
