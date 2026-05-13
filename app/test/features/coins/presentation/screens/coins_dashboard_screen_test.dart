import 'package:airo_app/core/utils/currency_formatter.dart';
import 'package:airo_app/core/utils/locale_settings.dart';
import 'package:airo_app/features/coins/application/providers/dashboard_providers.dart';
import 'package:airo_app/features/coins/domain/models/safe_to_spend.dart';
import 'package:airo_app/features/coins/presentation/screens/coins_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows real safe-to-spend data in the user currency', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyFormatterProvider.overrideWithValue(
            CurrencyFormatter.fromCode('USD'),
          ),
          dashboardDataProvider.overrideWith(
            (ref) async => DashboardData(
              safeToSpend: SafeToSpend(
                amountCents: 1250,
                dailyLimitCents: 2500,
                spentTodayCents: 750,
                spentThisMonthCents: 10000,
                monthlyBudgetCents: 50000,
                daysRemaining: 10,
                percentUsed: 20,
                health: BudgetHealth.healthy,
                currencyCode: 'USD',
                calculatedAt: DateTime(2026, 5, 13),
              ),
              spentTodayCents: 750,
              spentThisMonthCents: 10000,
              totalGroups: 2,
              pendingSettlements: 1,
            ),
          ),
        ],
        child: const MaterialApp(home: CoinsDashboardScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Safe to Spend Today'), findsOneWidget);
    expect(find.textContaining(r'$12.50'), findsOneWidget);
    expect(find.text('₹0'), findsNothing);
    expect(find.text('2 groups'), findsOneWidget);
    expect(find.text('1 pending settlement'), findsOneWidget);
  });

  testWidgets('opens add expense from the dashboard add action', (
    tester,
  ) async {
    var openedAddExpense = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardDataProvider.overrideWith(
            (ref) async => const DashboardData(),
          ),
        ],
        child: MaterialApp(
          home: CoinsDashboardScreen(
            onOpenAddExpense: () => openedAddExpense = true,
          ),
        ),
      ),
    );
    await tester.pump();

    final addAction = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    addAction.onPressed!();

    expect(openedAddExpense, isTrue);
  });
}
