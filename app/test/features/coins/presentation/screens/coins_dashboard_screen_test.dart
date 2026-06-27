import 'package:airo_app/core/utils/currency_formatter.dart';
import 'package:airo_app/core/utils/locale_settings.dart';
import 'package:airo_app/features/coins/application/providers/dashboard_providers.dart';
import 'package:airo_app/features/coins/domain/entities/transaction.dart';
import 'package:airo_app/features/coins/domain/models/safe_to_spend.dart';
import 'package:airo_app/features/coins/presentation/screens/add_expense_screen.dart';
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
    expect(find.text('Monthly spend'), findsOneWidget);
    expect(find.text('Budget remaining'), findsOneWidget);
    expect(find.text('Groups & settlements'), findsOneWidget);
    expect(find.text('Split New Expense'), findsWidgets);
    expect(find.text('2 groups'), findsOneWidget);
    expect(find.text('1 settlement'), findsOneWidget);
  });

  testWidgets('shows guided empty states for first-time finance users', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardDataProvider.overrideWith(
            (ref) async => const DashboardData(),
          ),
        ],
        child: const MaterialApp(home: CoinsDashboardScreen()),
      ),
    );
    await tester.pump();

    expect(
      find.text('Add your first expense to begin tracking spending.'),
      findsOneWidget,
    );
    expect(
      find.text('Create a monthly budget to see remaining spend here.'),
      findsOneWidget,
    );
    expect(find.text('AI finance insights'), findsOneWidget);
    expect(find.text('Start your money baseline'), findsOneWidget);
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

  testWidgets('quick add opens a prefilled expense draft', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardDataProvider.overrideWith(
            (ref) async => const DashboardData(),
          ),
        ],
        child: const MaterialApp(home: CoinsDashboardScreen()),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('coins_quick_add_field')),
      'Pizza 420 split with Alex',
    );
    await tester.tap(find.text('Draft expense'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(AddExpenseScreen), findsOneWidget);
    expect(find.text('Split with Alex'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Pizza'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '420.00'), findsOneWidget);
  });

  testWidgets('shows reviewed and pending review badges in recent expenses', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardDataProvider.overrideWith(
            (ref) async => DashboardData(
              recentExpenses: [
                Transaction(
                  id: 'manual-1',
                  description: 'Coffee',
                  amountCents: -450,
                  type: TransactionType.expense,
                  categoryId: 'food',
                  accountId: 'cash',
                  transactionDate: DateTime(2026, 6, 27),
                  createdAt: DateTime(2026, 6, 27),
                ),
                Transaction(
                  id: 'chat-1',
                  description: 'Swiggy',
                  amountCents: -1200,
                  type: TransactionType.expense,
                  categoryId: 'food',
                  accountId: 'cash',
                  transactionDate: DateTime(2026, 6, 27),
                  tags: const ['source:chat'],
                  createdAt: DateTime(2026, 6, 27),
                ),
              ],
            ),
          ),
        ],
        child: const MaterialApp(home: CoinsDashboardScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Reviewed'), findsOneWidget);
    expect(find.text('Pending Review'), findsOneWidget);
  });
}
