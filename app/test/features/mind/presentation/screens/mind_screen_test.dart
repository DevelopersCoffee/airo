import 'package:airo_app/features/mind/presentation/screens/mind_screen.dart';
import 'package:airo_app/features/quotes/application/providers/quote_provider.dart';
import 'package:airo_app/features/quotes/domain/models/quote_model.dart';
import 'package:airo_app/features/quotes/domain/models/quote_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestQuotePreferencesNotifier extends QuotePreferencesNotifier {
  _TestQuotePreferencesNotifier() : super() {
    state = const QuotePreferences();
  }
}

void main() {
  Widget buildScreen() {
    return ProviderScope(
      overrides: [
        quotePreferencesProvider.overrideWith(
          (ref) => _TestQuotePreferencesNotifier(),
        ),
        dailyQuoteProvider.overrideWith((ref) async {
          return const Quote(text: 'Small steps count.', author: 'Airo');
        }),
      ],
      child: const MaterialApp(home: MindScreen()),
    );
  }

  group('MindScreen', () {
    testWidgets('shows greeting, quote, actions, and progress sections', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Good', findRichText: true), findsOneWidget);
      expect(find.text('Small steps count.'), findsOneWidget);
      expect(find.text('Mind Actions'), findsOneWidget);
      expect(find.text('Daily Insight'), findsOneWidget);
      expect(find.text('Breathing Exercise'), findsOneWidget);
      expect(find.text('Reflection'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Progress'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('Mind Streak'), findsOneWidget);
      expect(find.text('Focus Momentum'), findsOneWidget);
    });

    testWidgets('allows the greeting card to be dismissed', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final greeting = find.textContaining('Good', findRichText: true);
      expect(greeting, findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss greeting'));
      await tester.pumpAndSettle();

      expect(greeting, findsNothing);
    });

    testWidgets('exposes action and progress semantics for screen readers', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          'Daily Insight. Open your assistant for a short guided check-in.',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.bySemanticsLabel('Mind Streak: 4 days. Daily check-ins'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.bySemanticsLabel('Mind Streak: 4 days. Daily check-ins'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Focus Momentum. Breathing goal 60 percent. Reflection goal 40 percent.',
        ),
        findsOneWidget,
      );
    });
  });
}
