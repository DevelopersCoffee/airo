import 'package:airo_app/features/media_hub/domain/models/media_category.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';
import 'package:airo_app/features/media_hub/domain/models/unified_media_content.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/media_content_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders content metadata, live badge, and viewers', (
    tester,
  ) async {
    const item = UnifiedMediaContent(
      id: 'tv-1',
      mode: MediaMode.tv,
      category: MediaCategory.news,
      title: 'Airo News',
      subtitle: 'News',
      imageUrl: null,
      streamUrl: 'https://example.com/live.m3u8',
      isLive: true,
      viewerCount: 1200,
      tags: ['Hindi'],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: MediaContentCard(item: item)),
        ),
      ),
    );

    expect(find.text('Airo News'), findsOneWidget);
    expect(find.text('News'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('1200 watching'), findsOneWidget);
    expect(find.text('HINDI'), findsOneWidget);
  });

  testWidgets('renders skeleton state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: MediaContentCard.skeleton())),
      ),
    );

    expect(
      find.byKey(const ValueKey('media-card-skeleton-image')),
      findsOneWidget,
    );
  });
}
