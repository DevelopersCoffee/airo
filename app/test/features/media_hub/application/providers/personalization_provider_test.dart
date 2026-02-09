import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airo_app/features/iptv/application/providers/iptv_providers.dart';
import 'package:airo_app/features/media_hub/application/providers/personalization_provider.dart';
import 'package:airo_app/features/media_hub/domain/models/personalization_state.dart';
import 'package:airo_app/features/media_hub/domain/models/unified_media_content.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';

void main() {
  group('PersonalizationNotifier', () {
    late ProviderContainer container;
    late SharedPreferences prefs;

    // Test fixtures
    UnifiedMediaContent createTestContent(
      String id, {
      MediaMode type = MediaMode.music,
    }) {
      return UnifiedMediaContent(
        id: id,
        title: 'Test Content $id',
        type: type,
        duration: const Duration(minutes: 5),
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('addToRecent', () {
      test('adds content to recently played list', () {
        final notifier = container.read(personalizationProvider.notifier);
        final content = createTestContent('1');

        notifier.addToRecent(content);

        final state = container.read(personalizationProvider);
        expect(state.recentlyPlayed.length, 1);
        expect(state.recentlyPlayed.first.id, '1');
      });

      test('moves existing content to front of list', () {
        final notifier = container.read(personalizationProvider.notifier);
        final content1 = createTestContent('1');
        final content2 = createTestContent('2');

        notifier.addToRecent(content1);
        notifier.addToRecent(content2);
        notifier.addToRecent(content1); // Add again

        final state = container.read(personalizationProvider);
        expect(state.recentlyPlayed.length, 2);
        expect(state.recentlyPlayed.first.id, '1'); // Should be first now
        expect(state.recentlyPlayed[1].id, '2');
      });

      test('limits to maxRecentItems', () {
        final notifier = container.read(personalizationProvider.notifier);

        // Add more than max items
        for (int i = 0; i < PersonalizationState.maxRecentItems + 10; i++) {
          notifier.addToRecent(createTestContent('item-$i'));
        }

        final state = container.read(personalizationProvider);
        expect(
          state.recentlyPlayed.length,
          lessThanOrEqualTo(PersonalizationState.maxRecentItems),
        );
      });
    });

    group('savePosition', () {
      test('saves playback position for content', () {
        final notifier = container.read(personalizationProvider.notifier);
        const position = Duration(minutes: 2);

        notifier.savePosition('content-1', position);

        final state = container.read(personalizationProvider);
        expect(state.playbackPositions['content-1'], position);
      });

      test('updates continue watching when position > 10 seconds', () {
        final notifier = container.read(personalizationProvider.notifier);
        final content = createTestContent('1');

        // First add to recent
        notifier.addToRecent(content);
        // Then save position > 10 seconds
        notifier.savePosition('1', const Duration(seconds: 30));

        final state = container.read(personalizationProvider);
        expect(state.continueWatching.length, 1);
        expect(state.continueWatching.first.id, '1');
      });
    });

    group('clearPosition', () {
      test('removes playback position', () {
        final notifier = container.read(personalizationProvider.notifier);

        notifier.savePosition('content-1', const Duration(minutes: 2));
        notifier.clearPosition('content-1');

        final state = container.read(personalizationProvider);
        expect(state.playbackPositions.containsKey('content-1'), isFalse);
      });

      test('removes content from continue watching', () {
        final notifier = container.read(personalizationProvider.notifier);
        final content = createTestContent('1');

        notifier.addToRecent(content);
        notifier.savePosition('1', const Duration(seconds: 30));
        expect(
          container.read(personalizationProvider).continueWatching.length,
          1,
        );

        notifier.clearPosition('1');
        expect(
          container.read(personalizationProvider).continueWatching.length,
          0,
        );
      });
    });

    group('toggleFavorite', () {
      test('adds to favorites when not favorited', () {
        final notifier = container.read(personalizationProvider.notifier);

        notifier.toggleFavorite('content-1');

        final state = container.read(personalizationProvider);
        expect(state.isFavorite('content-1'), isTrue);
      });

      test('removes from favorites when already favorited', () {
        final notifier = container.read(personalizationProvider.notifier);

        notifier.toggleFavorite('content-1');
        notifier.toggleFavorite('content-1');

        final state = container.read(personalizationProvider);
        expect(state.isFavorite('content-1'), isFalse);
      });
    });

    group('addFavorite', () {
      test('adds content to favorites', () {
        final notifier = container.read(personalizationProvider.notifier);

        notifier.addFavorite('content-1');

        final state = container.read(personalizationProvider);
        expect(state.isFavorite('content-1'), isTrue);
      });

      test('does nothing if already favorited', () {
        final notifier = container.read(personalizationProvider.notifier);

        notifier.addFavorite('content-1');
        notifier.addFavorite('content-1');

        final state = container.read(personalizationProvider);
        expect(state.favoritesCount, 1);
      });
    });

    group('removeFavorite', () {
      test('removes content from favorites', () {
        final notifier = container.read(personalizationProvider.notifier);

        notifier.addFavorite('content-1');
        notifier.removeFavorite('content-1');

        final state = container.read(personalizationProvider);
        expect(state.isFavorite('content-1'), isFalse);
      });

      test('does nothing if not favorited', () {
        final notifier = container.read(personalizationProvider.notifier);

        notifier.removeFavorite('content-1');

        final state = container.read(personalizationProvider);
        expect(state.favoritesCount, 0);
      });
    });

    group('clearAll', () {
      test('clears all personalization data', () async {
        final notifier = container.read(personalizationProvider.notifier);

        notifier.addToRecent(createTestContent('1'));
        notifier.savePosition('1', const Duration(minutes: 2));
        notifier.addFavorite('content-1');

        await notifier.clearAll();

        final state = container.read(personalizationProvider);
        expect(state.recentlyPlayed, isEmpty);
        expect(state.playbackPositions, isEmpty);
        expect(state.favoriteIds, isEmpty);
        expect(state.continueWatching, isEmpty);
      });
    });

    group('persistence', () {
      test('persists data to SharedPreferences', () async {
        final notifier = container.read(personalizationProvider.notifier);

        notifier.addFavorite('fav-1');
        notifier.savePosition('pos-1', const Duration(seconds: 45));

        // Wait for async save
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Check SharedPreferences has data
        final stored = prefs.getString('media_hub_personalization');
        expect(stored, isNotNull);
        expect(stored, contains('fav-1'));
        expect(stored, contains('pos-1'));
      });

      test('loads data from SharedPreferences on init', () async {
        // Pre-populate SharedPreferences
        await prefs.setString(
          'media_hub_personalization',
          '{"favoriteIds":["pre-fav"],"playbackPositions":{"pre-pos":60000}}',
        );

        // Create a new container that will load from storage
        final newContainer = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );

        // Wait for async load
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final state = newContainer.read(personalizationProvider);
        expect(state.isFavorite('pre-fav'), isTrue);
        expect(state.playbackPositions['pre-pos'], const Duration(minutes: 1));

        newContainer.dispose();
      });
    });

    group('derived providers', () {
      test('continueWatchingProvider returns continue watching list', () {
        final notifier = container.read(personalizationProvider.notifier);
        final content = createTestContent('1');

        notifier.addToRecent(content);
        notifier.savePosition('1', const Duration(seconds: 30));

        final continueWatching = container.read(continueWatchingProvider);
        expect(continueWatching.length, 1);
        expect(continueWatching.first.id, '1');
      });

      test('recentlyPlayedProvider returns recently played list', () {
        final notifier = container.read(personalizationProvider.notifier);
        notifier.addToRecent(createTestContent('1'));
        notifier.addToRecent(createTestContent('2'));

        final recentlyPlayed = container.read(recentlyPlayedProvider);
        expect(recentlyPlayed.length, 2);
      });

      test('isFavoriteProvider returns favorite status', () {
        final notifier = container.read(personalizationProvider.notifier);
        notifier.addFavorite('content-1');

        expect(container.read(isFavoriteProvider('content-1')), isTrue);
        expect(container.read(isFavoriteProvider('content-2')), isFalse);
      });
    });
  });
}
