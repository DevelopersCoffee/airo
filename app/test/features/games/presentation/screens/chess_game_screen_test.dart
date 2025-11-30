import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airo_app/features/games/presentation/screens/chess_game_screen_new.dart';

void main() {
  group('ChessGameScreenNew', () {
    testWidgets('displays difficulty selection on start', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChessGameScreenNew(),
          ),
        ),
      );

      expect(find.text('Chess Master'), findsOneWidget);
      expect(find.text('Select Difficulty'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Expert'), findsOneWidget);
    });

    testWidgets('displays shuffle sides toggle', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChessGameScreenNew(),
          ),
        ),
      );

      expect(find.text('Random side:'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.text('OFF'), findsOneWidget);
    });

    testWidgets('shuffle toggle changes state', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChessGameScreenNew(),
          ),
        ),
      );

      // Initially OFF
      expect(find.text('OFF'), findsOneWidget);

      // Tap the switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Should now be ON
      expect(find.text('ON'), findsOneWidget);
    });

    testWidgets('difficulty button descriptions are correct', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChessGameScreenNew(),
          ),
        ),
      );

      expect(find.text('Perfect for beginners'), findsOneWidget);
      expect(find.text('Balanced challenge'), findsOneWidget);
      expect(find.text('Advanced level'), findsOneWidget);
      expect(find.text('World Champion (ELO 3600+)'), findsOneWidget);
    });

    testWidgets('has correct number of difficulty buttons', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChessGameScreenNew(),
          ),
        ),
      );

      // Should have 4 ElevatedButtons for difficulty levels
      expect(find.byType(ElevatedButton), findsNWidgets(4));
    });
  });
}

