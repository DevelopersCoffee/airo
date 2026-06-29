import 'package:airo_app/features/media_hub/domain/models/media_category.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';
import 'package:airo_app/features/media_hub/domain/models/unified_media_content.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/content_carousel.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/content_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const item = UnifiedMediaContent(
    id: 'track-1',
    mode: MediaMode.music,
    category: MediaCategory.music,
    title: 'Track One',
    subtitle: 'Artist',
    imageUrl: null,
    streamUrl: 'https://example.com/track.mp3',
    tags: ['Chill'],
  );

  testWidgets('music discovery uses horizontal carousel layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ContentCarousel(
            title: 'Browse Music',
            items: [item],
            onSelected: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Browse Music'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Track One'), findsOneWidget);
  });

  testWidgets('tv discovery uses two-column grid layout', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ContentGrid(
            title: 'Browse Live TV',
            items: [item, item],
            onSelected: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Browse Live TV'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Track One'), findsNWidgets(2));
  });
}

void _noop(UnifiedMediaContent _) {}
