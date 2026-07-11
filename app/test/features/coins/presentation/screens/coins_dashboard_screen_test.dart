import 'package:airo_app/core/utils/currency_formatter.dart';
import 'package:airo_app/core/utils/locale_settings.dart';
import 'package:airo_app/features/coins/application/providers/dashboard_providers.dart';
import 'package:airo_app/features/coins/application/providers/expense_providers.dart';
import 'package:airo_app/features/coins/domain/entities/transaction.dart';
import 'package:airo_app/features/coins/domain/repositories/transaction_repository.dart';
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

  testWidgets('shows review queue and approves imported transaction', (
    tester,
  ) async {
    final pending = _pendingImportedTransaction();
    final repository = _InMemoryTransactionRepository([pending]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
          dashboardDataProvider.overrideWith(
            (ref) async => DashboardData(pendingTransactionReviews: [pending]),
          ),
        ],
        child: const MaterialApp(home: CoinsDashboardScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Review imported transactions'), findsOneWidget);
    expect(find.text('Zomato'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Approve imported transaction'));
    await tester.tap(find.byTooltip('Approve imported transaction'));
    await tester.pumpAndSettle();

    expect(repository.transactions.single.tags, contains('review:approved'));
    expect(
      repository.transactions.single.tags,
      isNot(contains('review:pending')),
    );
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

  testWidgets('shows Android import permission education when not enabled', (
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

    expect(find.text('Android SMS & notification import'), findsOneWidget);
    expect(
      find.textContaining(
        'Import bank, UPI, and card alerts only after you enable access',
      ),
      findsOneWidget,
    );
    expect(find.text('Permission disabled'), findsOneWidget);
  });
}

Transaction _pendingImportedTransaction() {
  return Transaction(
    id: 'txn_review_1',
    description: 'Zomato',
    amountCents: -29900,
    type: TransactionType.expense,
    categoryId: 'food',
    accountId: 'cash_default',
    transactionDate: DateTime(2026, 6, 20),
    tags: const [
      'review:pending',
      'source:chat_sms:abc123',
      'source:raw_text_b64:UkFXX1NNUw==',
    ],
    createdAt: DateTime(2026, 6, 20),
  );
}

class _InMemoryTransactionRepository implements TransactionRepository {
  final List<Transaction> transactions;

  _InMemoryTransactionRepository(this.transactions);

  @override
  Future<Result<Transaction>> create(Transaction transaction) async {
    transactions.add(transaction);
    return (data: transaction, error: null);
  }

  @override
  Future<Result<Transaction>> update(Transaction transaction) async {
    final index = transactions.indexWhere((item) => item.id == transaction.id);
    if (index == -1) return (data: null, error: 'not found');
    transactions[index] = transaction;
    return (data: transaction, error: null);
  }

  @override
  Future<Result<void>> delete(String id) async {
    final index = transactions.indexWhere((item) => item.id == id);
    if (index == -1) return (data: null, error: 'not found');
    transactions[index] = transactions[index].copyWith(isDeleted: true);
    return (data: null, error: null);
  }

  @override
  Future<Result<Transaction>> findById(String id) async {
    final matches = transactions.where((item) => item.id == id).toList();
    if (matches.isEmpty) return (data: null, error: 'not found');
    return (data: matches.single, error: null);
  }

  @override
  Future<Result<List<Transaction>>> findByTag(String tag) async {
    return (
      data: transactions.where((item) => item.tags.contains(tag)).toList(),
      error: null,
    );
  }

  @override
  Future<Result<List<Transaction>>> findByAccount(String accountId) async =>
      (data: <Transaction>[], error: null);

  @override
  Future<Result<List<Transaction>>> findByCategory(String categoryId) async =>
      (data: <Transaction>[], error: null);

  @override
  Future<Result<List<Transaction>>> findByDateRange(
    DateTime start,
    DateTime end,
  ) async => (data: <Transaction>[], error: null);

  @override
  Future<Result<List<Transaction>>> findRecent({int limit = 10}) async =>
      (data: transactions.take(limit).toList(), error: null);

  @override
  Future<Result<Map<String, int>>> getSpentByCategory(
    DateTime start,
    DateTime end,
  ) async => (data: <String, int>{}, error: null);

  @override
  Future<Result<int>> getTotalSpent(DateTime start, DateTime end) async =>
      (data: 0, error: null);

  @override
  Future<Result<void>> hardDelete(String id) async => (data: null, error: null);

  @override
  Future<Result<Transaction>> restore(String id) async =>
      (data: null, error: 'not found');

  @override
  Future<Result<List<Transaction>>> search(String query) async =>
      (data: <Transaction>[], error: null);

  @override
  Stream<List<Transaction>> watchAll() => Stream.value(transactions);

  @override
  Stream<List<Transaction>> watchByCategory(String categoryId) =>
      Stream.value(<Transaction>[]);

  @override
  Stream<List<Transaction>> watchByDate(DateTime date) =>
      Stream.value(<Transaction>[]);
}
