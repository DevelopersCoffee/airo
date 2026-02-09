import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airo_app/features/iptv/application/providers/iptv_providers.dart';
import 'package:airo_app/features/media_hub/application/providers/media_hub_providers.dart';
import 'package:airo_app/features/media_hub/application/providers/personalization_provider.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';
import 'package:airo_app/features/media_hub/domain/models/personalization_state.dart';
import 'package:airo_app/features/media_hub/domain/models/unified_media_content.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/personalization_carousel.dart';

/// Mock PersonalizationNotifier that returns pre-configured state
class MockPersonalizationNotifier extends StateNotifier<PersonalizationState>
    implements PersonalizationNotifier {
  MockPersonalizationNotifier(super.state);

  @override
  void addToRecent(UnifiedMediaContent content) {}
  @override
  void savePosition(String contentId, Duration position) {}
  @override
  void clearPosition(String contentId) {}
  @override
  void toggleFavorite(String contentId) {}
  @override
  void addFavorite(String contentId) {}
  @override
  void removeFavorite(String contentId) {}
  @override
  Future<void> clearAll() async {}
}

void main() {
  group('PersonalizationCarousel', () {
    late SharedPreferences mockPrefs;

    // Test fixtures
    UnifiedMediaContent createTestContent(
      String id, {
      MediaMode type = MediaMode.music,
    }) {
      return UnifiedMediaContent(
        id: id,
        title: 'Test $id',
        subtitle: 'Artist $id',
        type: type,
        duration: const Duration(minutes: 5),
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockPrefs = await SharedPreferences.getInstance();
    });

    Widget createTestWidget({
      PersonalizationSectionType sectionType =
          PersonalizationSectionType.continueWatching,
      void Function(UnifiedMediaContent)? onItemTap,
      List<Override> additionalOverrides = const [],
      MediaMode initialMode = MediaMode.music,
    }) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(mockPrefs),
          selectedMediaModeProvider.overrideWith((ref) => initialMode),
          ...additionalOverrides,
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PersonalizationCarousel(
              sectionType: sectionType,
              onItemTap: onItemTap,
            ),
          ),
        ),
      );
    }

    group('rendering', () {
      testWidgets('shows nothing when no content', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Should render nothing (SizedBox.shrink)
        expect(find.byType(PersonalizationCarousel), findsOneWidget);
        expect(find.text('Continue Watching'), findsNothing);
      });

      testWidgets('shows section title for continue watching', (tester) async {
        final content = createTestContent('1');
        final mockState = PersonalizationState(
          continueWatching: [content],
          recentlyPlayed: [content],
          playbackPositions: {'1': const Duration(seconds: 30)},
        );

        await tester.pumpWidget(
          createTestWidget(
            additionalOverrides: [
              personalizationProvider.overrideWith(
                (ref) => MockPersonalizationNotifier(mockState),
              ),
            ],
          ),
        );

        expect(find.text('Continue Watching'), findsOneWidget);
      });

      testWidgets('shows recently played title', (tester) async {
        final content = createTestContent('1');
        final mockState = PersonalizationState(recentlyPlayed: [content]);

        await tester.pumpWidget(
          createTestWidget(
            sectionType: PersonalizationSectionType.recentlyPlayed,
            additionalOverrides: [
              personalizationProvider.overrideWith(
                (ref) => MockPersonalizationNotifier(mockState),
              ),
            ],
          ),
        );

        expect(find.text('Recently Played'), findsOneWidget);
      });

      testWidgets('shows favorites title', (tester) async {
        final content = createTestContent('1');
        final mockState = PersonalizationState(
          recentlyPlayed: [content],
          favoriteIds: {'1'},
        );

        await tester.pumpWidget(
          createTestWidget(
            sectionType: PersonalizationSectionType.favorites,
            additionalOverrides: [
              personalizationProvider.overrideWith(
                (ref) => MockPersonalizationNotifier(mockState),
              ),
            ],
          ),
        );

        expect(find.text('Favorites'), findsOneWidget);
      });
    });

    group('mode filtering', () {
      testWidgets('filters content by music mode', (tester) async {
        final musicContent = createTestContent(
          'music-1',
          type: MediaMode.music,
        );
        final tvContent = createTestContent('tv-1', type: MediaMode.tv);
        final mockState = PersonalizationState(
          recentlyPlayed: [musicContent, tvContent],
        );

        await tester.pumpWidget(
          createTestWidget(
            sectionType: PersonalizationSectionType.recentlyPlayed,
            initialMode: MediaMode.music,
            additionalOverrides: [
              personalizationProvider.overrideWith(
                (ref) => MockPersonalizationNotifier(mockState),
              ),
            ],
          ),
        );

        // Should show music content only
        expect(find.text('Test music-1'), findsOneWidget);
        expect(find.text('Test tv-1'), findsNothing);
      });

      testWidgets('filters content by TV mode', (tester) async {
        final musicContent = createTestContent(
          'music-1',
          type: MediaMode.music,
        );
        final tvContent = createTestContent('tv-1', type: MediaMode.tv);
        final mockState = PersonalizationState(
          recentlyPlayed: [musicContent, tvContent],
        );

        await tester.pumpWidget(
          createTestWidget(
            sectionType: PersonalizationSectionType.recentlyPlayed,
            initialMode: MediaMode.tv,
            additionalOverrides: [
              personalizationProvider.overrideWith(
                (ref) => MockPersonalizationNotifier(mockState),
              ),
            ],
          ),
        );

        await tester.pump();

        // Should show TV content only
        expect(find.text('Test tv-1'), findsOneWidget);
        expect(find.text('Test music-1'), findsNothing);
      });
    });

    group('convenience widgets', () {
      testWidgets('ContinueWatchingSection renders correctly', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(mockPrefs),
              selectedMediaModeProvider.overrideWith((ref) => MediaMode.music),
            ],
            child: const MaterialApp(
              home: Scaffold(body: ContinueWatchingSection()),
            ),
          ),
        );

        expect(find.byType(ContinueWatchingSection), findsOneWidget);
      });

      testWidgets('RecentlyPlayedSection renders correctly', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(mockPrefs),
              selectedMediaModeProvider.overrideWith((ref) => MediaMode.music),
            ],
            child: const MaterialApp(
              home: Scaffold(body: RecentlyPlayedSection()),
            ),
          ),
        );

        expect(find.byType(RecentlyPlayedSection), findsOneWidget);
      });

      testWidgets('FavoritesSection renders correctly', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(mockPrefs),
              selectedMediaModeProvider.overrideWith((ref) => MediaMode.music),
            ],
            child: const MaterialApp(home: Scaffold(body: FavoritesSection())),
          ),
        );

        expect(find.byType(FavoritesSection), findsOneWidget);
      });
    });
  });
}
