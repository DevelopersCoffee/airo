import 'package:airo_app/features/money/application/providers/money_provider.dart';
import 'package:airo_app/features/money/domain/models/money_models.dart';
import 'package:airo_app/features/money/presentation/screens/money_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildScreen({List<Transaction> transactions = const []}) {
    return ProviderScope(
      overrides: [
        accountsProvider.overrideWith(
          (ref) async => [
            MoneyAccount(
              id: 'acc1',
              name: 'Checking',
              type: 'checking',
              currency: 'USD',
              balanceCents: 125000,
              createdAt: DateTime(2026, 1),
            ),
          ],
        ),
        totalBalanceProvider.overrideWith((ref) async => 125000),
        transactionsStreamProvider.overrideWith(
          (ref) => Stream.value(transactions),
        ),
        budgetsStreamProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(home: MoneyOverviewScreen()),
    );
  }

  Transaction transaction(int index) {
    return Transaction(
      id: 'txn$index',
      accountId: 'acc1',
      timestamp: DateTime(2026, 1, index),
      amountCents: -1000 * index,
      description: 'Transaction $index',
      category: 'Food & Drink',
      createdAt: DateTime(2026, 1, index),
    );
  }

  group('MoneyOverviewScreen', () {
    testWidgets('shows Hermes-style Coins hero and command actions', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('OPEN FINANCE • AIRO COINS'), findsOneWidget);
      expect(find.text('THE MONEY THAT\nWORKS WITH YOU.'), findsOneWidget);
      expect(find.text('1.  CREATE'), findsOneWidget);
      expect(find.text('2.  REVIEW'), findsOneWidget);
      expect(find.text('SEE IT IN ACTION'), findsOneWidget);
      expect(find.text('Split Bill'), findsNothing);
      expect(find.text('Send Money'), findsNothing);
    });

    testWidgets('keeps only the five most recent transactions visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildScreen(transactions: List.generate(6, (i) => transaction(i + 1))),
      );
      await tester.pump();

      for (var i = 1; i <= 5; i++) {
        expect(find.textContaining('Transaction $i'), findsWidgets);
      }
      expect(find.textContaining('Transaction 6'), findsNothing);
      expect(find.textContaining('Found 6 ledger entries.'), findsOneWidget);
    });

    testWidgets('keeps unrelated lifestyle content out of Coins tab', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('quote', findRichText: true), findsNothing);
      expect(find.textContaining('Good morning'), findsNothing);
      expect(find.textContaining('music', findRichText: true), findsNothing);
    });

    testWidgets('labels the primary FAB for the expense form it opens', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      final fab = find.byType(FloatingActionButton);

      expect(fab, findsOneWidget);
      expect(find.byTooltip('Add Expense'), findsOneWidget);
      expect(
        find.descendant(of: fab, matching: find.text('Add Expense')),
        findsOneWidget,
      );
      expect(find.byTooltip('Add Money'), findsNothing);
      expect(find.text('Add Money'), findsNothing);
    });
  });
}
