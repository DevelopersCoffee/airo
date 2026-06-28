import 'package:airo_app/features/media_hub/domain/models/discovery_state.dart';
import 'package:airo_app/features/media_hub/domain/models/media_category.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';
import 'package:airo_app/features/media_hub/domain/models/unified_media_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscoveryState', () {
    test('initial state applies first page and hasMore metadata', () {
      final items = List.generate(
        3,
        (index) => UnifiedMediaContent(
          id: 'item-$index',
          mode: MediaMode.music,
          category: MediaCategory.music,
          title: 'Track $index',
          subtitle: 'Artist',
          imageUrl: null,
          streamUrl: 'https://example.com/$index.mp3',
        ),
      );

      final state = DiscoveryState.initial(
        mode: MediaMode.music,
        items: items,
        pageSize: 2,
      );

      expect(state.visibleItems, hasLength(2));
      expect(state.filteredCount, 3);
      expect(state.currentPage, 1);
      expect(state.hasMore, isTrue);
    });

    test('copyWith preserves immutable values', () {
      final state = DiscoveryState.initial(mode: MediaMode.tv, items: const []);

      final updated = state.copyWith(
        searchQuery: 'sports',
        selectedCategory: MediaCategory.sports,
        currentPage: 2,
        filteredCount: 5,
        hasMore: true,
      );

      expect(updated.searchQuery, 'sports');
      expect(updated.selectedCategory, MediaCategory.sports);
      expect(updated.currentPage, 2);
      expect(updated.filteredCount, 5);
      expect(updated.hasMore, isTrue);
      expect(updated.mode, MediaMode.tv);
    });
  });
}
