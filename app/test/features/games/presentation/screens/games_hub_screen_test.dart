import 'package:airo_app/features/games/presentation/screens/game_coming_soon_screen.dart';
import 'package:airo_app/features/games/presentation/screens/games_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildScreen() {
    return const ProviderScope(child: MaterialApp(home: GamesHubScreen()));
  }

  group('GamesHubScreen', () {
    testWidgets('shows the Arena sections requested by issue 193', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Arena'), findsOneWidget);
      expect(find.text('Choose your game and start playing'), findsOneWidget);
      expect(find.text('Card Games'), findsOneWidget);
      expect(find.text('Strategy'), findsOneWidget);
      expect(find.text('Coming Soon'), findsOneWidget);
    });

    testWidgets('shows a compact preview and opens the full category sheet', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Solitaire'), findsNothing);
      expect(find.text('View All'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('games_view_all_card_games')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('games_section_sheet_card_games')),
        findsOneWidget,
      );
      expect(find.text('5 games'), findsOneWidget);
      expect(find.text('Solitaire'), findsOneWidget);
    });

    testWidgets(
      'opens the coming soon screen when an unavailable card is tapped',
      (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Checkers').first,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Checkers').first);
        await tester.pumpAndSettle();

        expect(find.byType(GameComingSoonScreen), findsOneWidget);
        expect(find.text('Full Gameplay Coming Soon'), findsOneWidget);
        expect(find.text('Checkers'), findsWidgets);
      },
    );
  });
}
