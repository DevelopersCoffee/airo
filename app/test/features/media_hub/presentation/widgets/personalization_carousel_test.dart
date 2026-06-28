import 'package:airo_app/features/media_hub/domain/models/media_category.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';
import 'package:airo_app/features/media_hub/domain/models/unified_media_content.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/personalization_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders recently played items in a horizontal carousel', (
    tester,
  ) async {
    const items = [
      UnifiedMediaContent(
        id: 'track-1',
        mode: MediaMode.music,
        category: MediaCategory.music,
        title: 'Track One',
        subtitle: 'Artist One',
        imageUrl: null,
        streamUrl: 'https://example.com/one.mp3',
      ),
      UnifiedMediaContent(
        id: 'track-2',
        mode: MediaMode.music,
        category: MediaCategory.music,
        title: 'Track Two',
        subtitle: 'Artist Two',
        imageUrl: null,
        streamUrl: 'https://example.com/two.mp3',
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PersonalizationCarousel(title: 'Recently Played', items: items),
        ),
      ),
    );

    expect(find.text('Recently Played'), findsOneWidget);
    expect(find.text('Track One'), findsOneWidget);
    expect(find.text('Track Two'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('hides itself when there are no items', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PersonalizationCarousel(title: 'Recently Played', items: []),
        ),
      ),
    );

    expect(find.text('Recently Played'), findsNothing);
  });

  testWidgets('shows filled heart for favorited items and handles toggle', (
    tester,
  ) async {
    const item = UnifiedMediaContent(
      id: 'track-1',
      mode: MediaMode.music,
      category: MediaCategory.music,
      title: 'Favorite Track',
      subtitle: 'Artist',
      imageUrl: null,
      streamUrl: 'https://example.com/one.mp3',
    );
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalizationCarousel(
            title: 'Favorites',
            items: const [item],
            showFavoriteButton: true,
            isFavorite: (_) => true,
            onFavoriteToggle: (_) => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('shows playback progress for resumable items', (tester) async {
    const item = UnifiedMediaContent(
      id: 'track-1',
      mode: MediaMode.music,
      category: MediaCategory.music,
      title: 'Resume Track',
      subtitle: 'Artist',
      imageUrl: null,
      streamUrl: 'https://example.com/one.mp3',
      duration: Duration(minutes: 4),
      lastPosition: Duration(minutes: 1, seconds: 30),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PersonalizationCarousel(
            title: 'Continue Watching',
            items: [item],
          ),
        ),
      ),
    );

    expect(find.text('01:30 / 04:00'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
