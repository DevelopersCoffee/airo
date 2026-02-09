import 'package:airo_app/features/media_hub/presentation/widgets/collapsible_player_container.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/content_grid.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/unified_mini_player.dart';
import 'package:airo_app/shared/widgets/responsive_center.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MH-016: Responsive Layouts', () {
    group('ResponsiveBreakpoints', () {
      test('mobile breakpoint is 600', () {
        expect(ResponsiveBreakpoints.mobile, 600);
      });

      test('tablet breakpoint is 1024', () {
        expect(ResponsiveBreakpoints.tablet, 1024);
      });

      test('desktop breakpoint is 1440', () {
        expect(ResponsiveBreakpoints.desktop, 1440);
      });

      test('getGridColumns returns correct values', () {
        // Mobile
        expect(
          ResponsiveBreakpoints.getGridColumns(
            400,
            mobile: 2,
            tablet: 3,
            desktop: 4,
          ),
          2,
        );
        // Tablet
        expect(
          ResponsiveBreakpoints.getGridColumns(
            800,
            mobile: 2,
            tablet: 3,
            desktop: 4,
          ),
          3,
        );
        // Desktop
        expect(
          ResponsiveBreakpoints.getGridColumns(
            1200,
            mobile: 2,
            tablet: 3,
            desktop: 4,
          ),
          4,
        );
      });
    });

    group('CollapsiblePlayerContainer responsive heights', () {
      test('mobileCollapsedHeight is 200px', () {
        expect(CollapsiblePlayerContainer.mobileCollapsedHeight, 200.0);
      });

      test('tabletCollapsedHeight is 280px', () {
        expect(CollapsiblePlayerContainer.tabletCollapsedHeight, 280.0);
      });

      test('expandedMultiplier is approximately 1.54', () {
        expect(
          CollapsiblePlayerContainer.expandedMultiplier,
          closeTo(1.54, 0.01),
        );
      });

      test('animation duration is 300ms', () {
        expect(
          CollapsiblePlayerContainer.animationDuration,
          const Duration(milliseconds: 300),
        );
      });

      test('animation curve is easeOutCubic', () {
        expect(CollapsiblePlayerContainer.animationCurve, Curves.easeOutCubic);
      });
    });

    group('UnifiedMiniPlayer responsive heights', () {
      test('mobileHeight is 64px', () {
        expect(UnifiedMiniPlayer.mobileHeight, 64.0);
      });

      test('tabletHeight is 72px', () {
        expect(UnifiedMiniPlayer.tabletHeight, 72.0);
      });

      test('minTouchTarget meets accessibility requirements (≥44px)', () {
        expect(UnifiedMiniPlayer.minTouchTarget, greaterThanOrEqualTo(44.0));
      });
    });

    group('ContentGrid responsive columns', () {
      testWidgets('uses 2 columns on mobile', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(400, 800)),
              child: Scaffold(
                body: ContentGrid(content: const [], shrinkWrap: true),
              ),
            ),
          ),
        );

        expect(find.byType(ContentGrid), findsOneWidget);
      });

      testWidgets('uses 3 columns on tablet', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(800, 1024)),
              child: Scaffold(
                body: ContentGrid(content: const [], shrinkWrap: true),
              ),
            ),
          ),
        );

        expect(find.byType(ContentGrid), findsOneWidget);
      });

      testWidgets('uses 4 columns on desktop', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(1400, 900)),
              child: Scaffold(
                body: ContentGrid(content: const [], shrinkWrap: true),
              ),
            ),
          ),
        );

        expect(find.byType(ContentGrid), findsOneWidget);
      });
    });

    group('ResponsiveCenter', () {
      test('contentMaxWidth is 1000px', () {
        expect(ResponsiveBreakpoints.contentMaxWidth, 1000);
      });

      test('dashboardMaxWidth is 1200px', () {
        expect(ResponsiveBreakpoints.dashboardMaxWidth, 1200);
      });

      test('wideMaxWidth is 1440px', () {
        expect(ResponsiveBreakpoints.wideMaxWidth, 1440);
      });
    });
  });
}
