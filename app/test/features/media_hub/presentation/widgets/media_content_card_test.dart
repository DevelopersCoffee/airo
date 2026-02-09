import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/media_content_card.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/content_grid.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/content_carousel.dart';
import 'package:airo_app/features/media_hub/domain/models/unified_media_content.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';
import 'package:airo_app/features/media_hub/domain/models/media_category.dart';

/// Mock HttpClient to prevent network calls in tests
class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _MockHttpClientRequest();
  }
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  HttpHeaders get headers => _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return _MockHttpClientResponse();
  }
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 404;

  @override
  int get contentLength => 0;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return const Stream<List<int>>.empty().listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  // Test data
  UnifiedMediaContent createTVContent({
    String id = 'tv_1',
    String title = 'Test Channel',
    String? subtitle = 'News',
    String? thumbnailUrl,
    bool isLive = true,
    int? viewerCount,
    MediaCategory? category,
    List<String> tags = const [],
  }) {
    return UnifiedMediaContent(
      id: id,
      title: title,
      subtitle: subtitle,
      thumbnailUrl: thumbnailUrl,
      type: MediaMode.tv,
      isLive: isLive,
      viewerCount: viewerCount,
      category: category,
      tags: tags,
    );
  }

  UnifiedMediaContent createMusicContent({
    String id = 'music_1',
    String title = 'Test Song',
    String? subtitle = 'Test Artist',
    String? thumbnailUrl,
    Duration? duration,
    Duration? lastPosition,
    MediaCategory? category,
    List<String> tags = const [],
  }) {
    return UnifiedMediaContent(
      id: id,
      title: title,
      subtitle: subtitle,
      thumbnailUrl: thumbnailUrl,
      type: MediaMode.music,
      isLive: false,
      duration: duration,
      lastPosition: lastPosition,
      category: category,
      tags: tags,
    );
  }

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('MediaContentCard', () {
    group('Rendering', () {
      testWidgets('renders card with title', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            MediaContentCard(content: createTVContent(title: 'My Channel')),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('My Channel'), findsOneWidget);
      });

      testWidgets('renders card with subtitle', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            MediaContentCard(
              content: createTVContent(subtitle: 'Entertainment'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Entertainment'), findsOneWidget);
      });

      testWidgets('renders LIVE badge for live TV content', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            MediaContentCard(content: createTVContent(isLive: true)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('LIVE'), findsOneWidget);
      });

      testWidgets('does not render LIVE badge for non-live content', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(MediaContentCard(content: createMusicContent())),
        );
        await tester.pumpAndSettle();

        expect(find.text('LIVE'), findsNothing);
      });

      testWidgets('renders viewer count when available', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            MediaContentCard(content: createTVContent(viewerCount: 500)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('500'), findsOneWidget);
        expect(find.byIcon(Icons.visibility), findsOneWidget);
      });

      testWidgets('formats viewer count with K suffix for thousands', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            MediaContentCard(content: createTVContent(viewerCount: 2500)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('2.5K'), findsOneWidget);
      });

      testWidgets('renders duration badge for non-live content', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            MediaContentCard(
              content: createMusicContent(
                duration: const Duration(minutes: 3, seconds: 45),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('3:45'), findsOneWidget);
      });

      testWidgets('renders genre tag from category', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            MediaContentCard(
              content: createTVContent(
                subtitle: 'Entertainment', // Different from category
                category: MediaCategories.tvNews,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The genre tag should display the category label "News"
        expect(find.text('News'), findsOneWidget);
      });

      testWidgets('renders genre tag from tags when no category', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            MediaContentCard(
              content: createTVContent(category: null, tags: ['Sports']),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sports'), findsOneWidget);
      });

      testWidgets('renders placeholder when no thumbnail', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            MediaContentCard(content: createTVContent(thumbnailUrl: null)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.live_tv), findsOneWidget);
      });

      testWidgets('renders music icon placeholder for music content', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            MediaContentCard(content: createMusicContent(thumbnailUrl: null)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.music_note), findsOneWidget);
      });

      testWidgets('renders progress indicator for resumable content', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            MediaContentCard(
              content: createMusicContent(
                duration: const Duration(minutes: 5),
                lastPosition: const Duration(minutes: 2, seconds: 30),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });

      testWidgets('does not render progress when showProgress is false', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            MediaContentCard(
              content: createMusicContent(
                duration: const Duration(minutes: 5),
                lastPosition: const Duration(minutes: 2, seconds: 30),
              ),
              showProgress: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LinearProgressIndicator), findsNothing);
      });
    });

    group('Interactions', () {
      testWidgets('calls onTap when card is tapped', (tester) async {
        bool tapped = false;
        await tester.pumpWidget(
          createTestWidget(
            MediaContentCard(
              content: createTVContent(),
              onTap: () => tapped = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(MediaContentCard));
        expect(tapped, isTrue);
      });

      testWidgets('calls onLongPress when card is long-pressed', (
        tester,
      ) async {
        bool longPressed = false;
        await tester.pumpWidget(
          createTestWidget(
            MediaContentCard(
              content: createTVContent(),
              onLongPress: () => longPressed = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.longPress(find.byType(MediaContentCard));
        expect(longPressed, isTrue);
      });
    });

    group('Constants', () {
      test('fadeInDuration is 200ms', () {
        expect(
          MediaContentCard.fadeInDuration,
          const Duration(milliseconds: 200),
        );
      });

      test('minTouchTarget is 44px', () {
        expect(MediaContentCard.minTouchTarget, 44.0);
      });

      test('aspectRatio is 0.75', () {
        expect(MediaContentCard.aspectRatio, 0.75);
      });
    });

    group('Accessibility', () {
      testWidgets('placeholder icon has semantic label for TV', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            MediaContentCard(content: createTVContent(thumbnailUrl: null)),
          ),
        );
        await tester.pumpAndSettle();

        final icon = tester.widget<Icon>(find.byIcon(Icons.live_tv));
        expect(icon.semanticLabel, 'TV content');
      });

      testWidgets('placeholder icon has semantic label for Music', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            MediaContentCard(content: createMusicContent(thumbnailUrl: null)),
          ),
        );
        await tester.pumpAndSettle();

        final icon = tester.widget<Icon>(find.byIcon(Icons.music_note));
        expect(icon.semanticLabel, 'Music content');
      });
    });
  });

  group('ContentGrid', () {
    group('Rendering', () {
      testWidgets('renders grid with content items', (tester) async {
        final content = [
          createTVContent(id: 'tv_1', title: 'Channel 1'),
          createTVContent(id: 'tv_2', title: 'Channel 2'),
          createTVContent(id: 'tv_3', title: 'Channel 3'),
        ];

        await tester.pumpWidget(
          createTestWidget(ContentGrid(content: content)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Channel 1'), findsOneWidget);
        expect(find.text('Channel 2'), findsOneWidget);
        expect(find.text('Channel 3'), findsOneWidget);
      });

      testWidgets('renders empty state when no content', (tester) async {
        await tester.pumpWidget(
          createTestWidget(const ContentGrid(content: [])),
        );
        await tester.pumpAndSettle();

        expect(find.text('No content available'), findsOneWidget);
      });

      testWidgets('uses GridView.builder', (tester) async {
        final content = [createTVContent()];

        await tester.pumpWidget(
          createTestWidget(ContentGrid(content: content)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GridView), findsOneWidget);
      });
    });

    group('Interactions', () {
      testWidgets('calls onItemTap when item is tapped', (tester) async {
        UnifiedMediaContent? tappedContent;
        final content = [createTVContent(id: 'tv_1', title: 'Channel 1')];

        await tester.pumpWidget(
          createTestWidget(
            ContentGrid(
              content: content,
              onItemTap: (item) => tappedContent = item,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Channel 1'));
        expect(tappedContent?.id, 'tv_1');
      });
    });

    group('Constants', () {
      test('mobileBreakpoint is 600', () {
        expect(ContentGrid.mobileBreakpoint, 600);
      });

      test('tabletBreakpoint is 1200', () {
        expect(ContentGrid.tabletBreakpoint, 1200);
      });

      test('mobileColumns is 2', () {
        expect(ContentGrid.mobileColumns, 2);
      });

      test('tabletColumns is 3', () {
        expect(ContentGrid.tabletColumns, 3);
      });

      test('desktopColumns is 4', () {
        expect(ContentGrid.desktopColumns, 4);
      });
    });
  });

  group('ContentCarousel', () {
    group('Rendering', () {
      testWidgets('renders carousel with content items', (tester) async {
        final content = [
          createMusicContent(id: 'music_1', title: 'Song 1'),
          createMusicContent(id: 'music_2', title: 'Song 2'),
        ];

        await tester.pumpWidget(
          createTestWidget(ContentCarousel(content: content)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Song 1'), findsOneWidget);
        expect(find.text('Song 2'), findsOneWidget);
      });

      testWidgets('renders section title when provided', (tester) async {
        final content = [createMusicContent()];

        await tester.pumpWidget(
          createTestWidget(
            ContentCarousel(content: content, title: 'Trending'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Trending'), findsOneWidget);
      });

      testWidgets('renders See All button when enabled', (tester) async {
        final content = [createMusicContent()];

        await tester.pumpWidget(
          createTestWidget(
            ContentCarousel(
              content: content,
              title: 'Trending',
              showSeeAll: true,
              onSeeAllTap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('See All'), findsOneWidget);
      });

      testWidgets('hides See All button when disabled', (tester) async {
        final content = [createMusicContent()];

        await tester.pumpWidget(
          createTestWidget(
            ContentCarousel(
              content: content,
              title: 'Trending',
              showSeeAll: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('See All'), findsNothing);
      });

      testWidgets('returns empty widget when no content', (tester) async {
        await tester.pumpWidget(
          createTestWidget(const ContentCarousel(content: [])),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsNothing);
      });

      testWidgets('uses horizontal ListView', (tester) async {
        final content = [createMusicContent()];

        await tester.pumpWidget(
          createTestWidget(ContentCarousel(content: content)),
        );
        await tester.pumpAndSettle();

        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.scrollDirection, Axis.horizontal);
      });
    });

    group('Interactions', () {
      testWidgets('calls onItemTap when item is tapped', (tester) async {
        UnifiedMediaContent? tappedContent;
        final content = [createMusicContent(id: 'music_1', title: 'Song 1')];

        await tester.pumpWidget(
          createTestWidget(
            ContentCarousel(
              content: content,
              onItemTap: (item) => tappedContent = item,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Song 1'));
        expect(tappedContent?.id, 'music_1');
      });

      testWidgets('calls onSeeAllTap when See All is tapped', (tester) async {
        bool seeAllTapped = false;
        final content = [createMusicContent()];

        await tester.pumpWidget(
          createTestWidget(
            ContentCarousel(
              content: content,
              title: 'Trending',
              onSeeAllTap: () => seeAllTapped = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('See All'));
        expect(seeAllTapped, isTrue);
      });
    });

    group('Constants', () {
      test('mobileCardWidth is 140', () {
        expect(ContentCarousel.mobileCardWidth, 140);
      });

      test('tabletCardWidth is 160', () {
        expect(ContentCarousel.tabletCardWidth, 160);
      });

      test('desktopCardWidth is 180', () {
        expect(ContentCarousel.desktopCardWidth, 180);
      });

      test('cardHeightMultiplier is 1.33', () {
        expect(ContentCarousel.cardHeightMultiplier, 1.33);
      });

      test('carouselHeight is 240', () {
        expect(ContentCarousel.carouselHeight, 240);
      });
    });
  });
}
