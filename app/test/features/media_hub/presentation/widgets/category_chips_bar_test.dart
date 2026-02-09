import 'package:airo_app/features/media_hub/application/providers/media_hub_providers.dart';
import 'package:airo_app/features/media_hub/domain/models/media_category.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/category_chip.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/category_chips_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategoryChipsBar', () {
    Widget buildTestWidget({
      MediaMode initialMode = MediaMode.music,
      MediaCategory? initialCategory,
      void Function(MediaCategory?)? onCategorySelected,
    }) {
      return ProviderScope(
        overrides: [
          selectedMediaModeProvider.overrideWith((ref) => initialMode),
          if (initialCategory != null)
            selectedCategoryProvider.overrideWith((ref) => initialCategory),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CategoryChipsBar(onCategorySelected: onCategorySelected),
          ),
        ),
      );
    }

    testWidgets('renders All chip and first music categories in music mode', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(initialMode: MediaMode.music));

      // All chip and first few categories should be visible
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Trending'), findsOneWidget);
      expect(find.text('Regional'), findsOneWidget);
      // Later categories may be off-screen due to lazy loading
    });

    testWidgets('renders All chip and first TV categories in TV mode', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(initialMode: MediaMode.tv));

      // All chip and first few categories should be visible
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Movies'), findsOneWidget);
      // Later categories may be off-screen due to lazy loading
    });

    testWidgets('All chip is selected by default', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final allChip = find.byType(AllCategoryChip);
      expect(allChip, findsOneWidget);

      final allChipWidget = tester.widget<AllCategoryChip>(allChip);
      expect(allChipWidget.isSelected, isTrue);
    });

    testWidgets('tapping a category chip selects it', (tester) async {
      MediaCategory? selectedCategory;
      await tester.pumpWidget(
        buildTestWidget(onCategorySelected: (cat) => selectedCategory = cat),
      );

      await tester.tap(find.text('Trending'));
      await tester.pumpAndSettle();

      expect(selectedCategory?.id, equals('music_trending'));
    });

    testWidgets('tapping All chip clears category selection', (tester) async {
      MediaCategory? selectedCategory = MediaCategories.musicTrending;
      await tester.pumpWidget(
        buildTestWidget(
          initialCategory: MediaCategories.musicTrending,
          onCategorySelected: (cat) => selectedCategory = cat,
        ),
      );

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(selectedCategory, isNull);
    });

    testWidgets('chips are horizontally scrollable', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final listView = find.byType(ListView);
      expect(listView, findsOneWidget);

      final listViewWidget = tester.widget<ListView>(listView);
      expect(listViewWidget.scrollDirection, equals(Axis.horizontal));
    });

    testWidgets('selected chip has different styling', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(initialCategory: MediaCategories.musicTrending),
      );

      // Find the CategoryChip for Trending
      final trendingChip = find.byWidgetPredicate(
        (widget) =>
            widget is CategoryChip &&
            widget.category.id == 'music_trending' &&
            widget.isSelected,
      );
      expect(trendingChip, findsOneWidget);
    });
  });

  group('CategoryChip', () {
    testWidgets('displays icon and label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryChip(
              category: MediaCategories.musicTrending,
              isSelected: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Trending'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });

    testWidgets('animates on selection change', (tester) async {
      bool isSelected = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: CategoryChip(
                  category: MediaCategories.musicTrending,
                  isSelected: isSelected,
                  onTap: () => setState(() => isSelected = !isSelected),
                ),
              ),
            );
          },
        ),
      );

      await tester.tap(find.text('Trending'));
      await tester.pump(const Duration(milliseconds: 100));
      // Animation should be in progress
      await tester.pump(const Duration(milliseconds: 100));
      // Animation should complete
    });
  });
}
