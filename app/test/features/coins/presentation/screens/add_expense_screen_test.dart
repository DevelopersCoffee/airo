import 'package:airo_app/core/utils/currency_formatter.dart';
import 'package:airo_app/core/utils/locale_settings.dart';
import 'package:airo_app/features/coins/application/providers/expense_providers.dart';
import 'package:airo_app/features/coins/domain/entities/account.dart';
import 'package:airo_app/features/coins/domain/entities/transaction.dart';
import 'package:airo_app/features/coins/domain/repositories/transaction_repository.dart';
import 'package:airo_app/features/coins/domain/services/quick_add_expense_parser.dart';
import 'package:airo_app/features/coins/presentation/screens/add_expense_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saves an expense after choosing category and account', (
    tester,
  ) async {
    final repository = _CapturingTransactionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyFormatterProvider.overrideWithValue(
            CurrencyFormatter.fromCode('USD'),
          ),
          transactionRepositoryProvider.overrideWithValue(repository),
          expenseAccountOptionsProvider.overrideWith(
            (ref) async => [
              Account(
                id: 'cash',
                name: 'Cash',
                type: AccountType.cash,
                balanceCents: 10000,
                currencyCode: 'USD',
                createdAt: DateTime(2026, 5, 13),
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: AddExpenseScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), '12.50');
    await tester.enterText(find.byType(TextFormField).at(1), 'Lunch');
    await tester.tap(find.text('Food'));
    await tester.pump();
    await tester.tap(find.text('Cash'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(repository.createdTransaction?.description, 'Lunch');
    expect(repository.createdTransaction?.amountCents, -1250);
    expect(repository.createdTransaction?.categoryId, 'food');
    expect(repository.createdTransaction?.accountId, 'cash');
  });

  testWidgets('surfaces finance-focused entry aids and inline errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseAccountOptionsProvider.overrideWith(
            (ref) async => [
              Account(
                id: 'cash',
                name: 'Cash',
                type: AccountType.cash,
                balanceCents: 10000,
                currencyCode: 'INR',
                createdAt: DateTime(2026, 5, 13),
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: AddExpenseScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Budget tag'), findsOneWidget);
    expect(find.text('Recurring expense'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '850');
    await tester.enterText(find.byType(TextFormField).at(1), 'Dinner');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Choose a category'), findsOneWidget);
    expect(find.text('Choose who paid'), findsOneWidget);
  });

  testWidgets('prefills an expense from a quick-add draft', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AddExpenseScreen(
            initialDraft: QuickExpenseDraft(
              description: 'Netflix',
              amountCents: 64900,
              categoryId: 'shopping',
              budgetTag: 'Entertainment',
              isRecurring: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'Netflix'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '649.00'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Entertainment'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });
}

class _CapturingTransactionRepository implements TransactionRepository {
  Transaction? createdTransaction;

  @override
  Future<Result<Transaction>> create(Transaction transaction) async {
    createdTransaction = transaction;
    return (data: transaction, error: null);
  }

  @override
  Future<Result<void>> delete(String id) async => (data: null, error: null);

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
  Future<Result<Transaction>> findById(String id) async =>
      (data: null, error: 'not found');

  @override
  Future<Result<List<Transaction>>> findRecent({int limit = 10}) async =>
      (data: <Transaction>[], error: null);

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
  Future<Result<Transaction>> update(Transaction transaction) async =>
      (data: transaction, error: null);

  @override
  Stream<List<Transaction>> watchAll() => Stream.value(<Transaction>[]);

  @override
  Stream<List<Transaction>> watchByCategory(String categoryId) =>
      Stream.value(<Transaction>[]);

  @override
  Stream<List<Transaction>> watchByDate(DateTime date) =>
      Stream.value(<Transaction>[]);
}
