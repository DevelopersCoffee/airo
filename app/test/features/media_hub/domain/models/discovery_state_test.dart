import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/media_hub/domain/models/discovery_state.dart';
import 'package:airo_app/features/media_hub/domain/models/unified_media_content.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';
import 'package:airo_app/features/media_hub/domain/models/media_category.dart';

void main() {
  group('DiscoveryState', () {
    // Test fixtures
    UnifiedMediaContent createTestContent(
      String id, {
      MediaMode type = MediaMode.music,
      MediaCategory? category,
      List<String> tags = const [],
    }) {
      return UnifiedMediaContent(
        id: id,
        title: 'Test Content $id',
        type: type,
        category: category,
        tags: tags,
      );
    }

    group('constructor', () {
      test('creates empty state by default', () {
        const state = DiscoveryState();

        expect(state.currentMode, MediaMode.music);
        expect(state.selectedCategory, isNull);
        expect(state.contentItems, isEmpty);
        expect(state.isLoading, isFalse);
        expect(state.errorMessage, isNull);
        expect(state.searchQuery, isNull);
        expect(state.hasMore, isTrue);
        expect(state.nextCursor, isNull);
      });

      test('creates state with provided values', () {
        final content = createTestContent('1');
        final state = DiscoveryState(
          currentMode: MediaMode.tv,
          selectedCategory: MediaCategories.tvLive,
          contentItems: [content],
          isLoading: true,
          errorMessage: 'Error',
          searchQuery: 'test',
          hasMore: false,
          nextCursor: 'abc',
        );

        expect(state.currentMode, MediaMode.tv);
        expect(state.selectedCategory, MediaCategories.tvLive);
        expect(state.contentItems.length, 1);
        expect(state.isLoading, isTrue);
        expect(state.errorMessage, 'Error');
        expect(state.searchQuery, 'test');
        expect(state.hasMore, isFalse);
        expect(state.nextCursor, 'abc');
      });
    });

    group('availableCategories', () {
      test('returns music categories for music mode', () {
        const state = DiscoveryState(currentMode: MediaMode.music);
        expect(state.availableCategories, MediaCategories.musicCategories);
      });

      test('returns TV categories for TV mode', () {
        const state = DiscoveryState(currentMode: MediaMode.tv);
        expect(state.availableCategories, MediaCategories.tvCategories);
      });
    });

    group('filteredContent', () {
      test('returns all content when no category selected', () {
        final content1 = createTestContent(
          '1',
          category: MediaCategories.musicTrending,
        );
        final content2 = createTestContent(
          '2',
          category: MediaCategories.musicChill,
        );
        final state = DiscoveryState(contentItems: [content1, content2]);

        expect(state.filteredContent.length, 2);
      });

      test('returns only matching content when category selected', () {
        final content1 = createTestContent(
          '1',
          category: MediaCategories.musicTrending,
        );
        final content2 = createTestContent(
          '2',
          category: MediaCategories.musicChill,
        );
        final state = DiscoveryState(
          contentItems: [content1, content2],
          selectedCategory: MediaCategories.musicTrending,
        );

        expect(state.filteredContent.length, 1);
        expect(state.filteredContent.first.id, '1');
      });
    });

    group('modeFilteredContent', () {
      test('returns only content matching current mode', () {
        final musicContent = createTestContent('1', type: MediaMode.music);
        final tvContent = createTestContent('2', type: MediaMode.tv);
        final state = DiscoveryState(
          currentMode: MediaMode.music,
          contentItems: [musicContent, tvContent],
        );

        expect(state.modeFilteredContent.length, 1);
        expect(state.modeFilteredContent.first.id, '1');
      });
    });

    group('isSearching', () {
      test('returns true when searchQuery is not empty', () {
        const state = DiscoveryState(searchQuery: 'test');
        expect(state.isSearching, isTrue);
      });

      test('returns false when searchQuery is null', () {
        const state = DiscoveryState();
        expect(state.isSearching, isFalse);
      });

      test('returns false when searchQuery is empty', () {
        const state = DiscoveryState(searchQuery: '');
        expect(state.isSearching, isFalse);
      });
    });

    group('hasError', () {
      test('returns true when errorMessage is not null', () {
        const state = DiscoveryState(errorMessage: 'Error');
        expect(state.hasError, isTrue);
      });

      test('returns false when errorMessage is null', () {
        const state = DiscoveryState();
        expect(state.hasError, isFalse);
      });
    });

    group('isEmpty', () {
      test('returns true when contentItems empty and not loading', () {
        const state = DiscoveryState(contentItems: [], isLoading: false);
        expect(state.isEmpty, isTrue);
      });

      test('returns false when loading', () {
        const state = DiscoveryState(contentItems: [], isLoading: true);
        expect(state.isEmpty, isFalse);
      });

      test('returns false when has content', () {
        final state = DiscoveryState(contentItems: [createTestContent('1')]);
        expect(state.isEmpty, isFalse);
      });
    });

    group('copyWith', () {
      test('copies all values when provided', () {
        const original = DiscoveryState();
        final content = createTestContent('1');
        final updated = original.copyWith(
          currentMode: MediaMode.tv,
          selectedCategory: MediaCategories.tvLive,
          contentItems: [content],
          isLoading: true,
          errorMessage: 'Error',
          searchQuery: 'test',
          hasMore: false,
          nextCursor: 'cursor',
        );

        expect(updated.currentMode, MediaMode.tv);
        expect(updated.selectedCategory, MediaCategories.tvLive);
        expect(updated.contentItems.length, 1);
        expect(updated.isLoading, isTrue);
        expect(updated.errorMessage, 'Error');
        expect(updated.searchQuery, 'test');
        expect(updated.hasMore, isFalse);
        expect(updated.nextCursor, 'cursor');
      });

      test('preserves values when not provided', () {
        final content = createTestContent('1');
        final original = DiscoveryState(
          currentMode: MediaMode.tv,
          contentItems: [content],
        );
        final updated = original.copyWith(isLoading: true);

        expect(updated.currentMode, MediaMode.tv);
        expect(updated.contentItems.length, 1);
        expect(updated.isLoading, isTrue);
      });

      test('clearCategory sets selectedCategory to null', () {
        final state = DiscoveryState(
          selectedCategory: MediaCategories.musicTrending,
        );
        final updated = state.copyWith(clearCategory: true);

        expect(updated.selectedCategory, isNull);
      });

      test('clearError sets errorMessage to null', () {
        const state = DiscoveryState(errorMessage: 'Error');
        final updated = state.copyWith(clearError: true);

        expect(updated.errorMessage, isNull);
      });

      test('clearSearch sets searchQuery to null', () {
        const state = DiscoveryState(searchQuery: 'test');
        final updated = state.copyWith(clearSearch: true);

        expect(updated.searchQuery, isNull);
      });
    });

    group('Equatable', () {
      test('two states with same props are equal', () {
        const state1 = DiscoveryState(currentMode: MediaMode.music);
        const state2 = DiscoveryState(currentMode: MediaMode.music);

        expect(state1, equals(state2));
      });

      test('two states with different props are not equal', () {
        const state1 = DiscoveryState(currentMode: MediaMode.music);
        const state2 = DiscoveryState(currentMode: MediaMode.tv);

        expect(state1, isNot(equals(state2)));
      });
    });
  });
}
