import 'package:airo_app/core/utils/currency_formatter.dart';
import 'package:airo_app/core/utils/locale_settings.dart';
import 'package:airo_app/features/agent_chat/application/assistant_model_preferences.dart';
import 'package:airo_app/features/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:airo_app/features/agent_chat/presentation/screens/chat_screen.dart';
import 'package:airo_app/features/coins/application/providers/expense_providers.dart';
import 'package:airo_app/features/coins/domain/entities/account.dart';
import 'package:airo_app/features/coins/domain/entities/transaction.dart';
import 'package:airo_app/features/coins/domain/repositories/transaction_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('pasted finance SMS is added to Coins from chat', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    SharedPreferences.setMockInitialValues({
      'selected_assistant_model_id': geminiNanoAssistantModelId,
    });

    final repository = _InMemoryTransactionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyFormatterProvider.overrideWithValue(
            CurrencyFormatter.fromCode('INR'),
          ),
          selectedAssistantModelIdProvider.overrideWith(
            (ref) => _SelectedAssistantModelNotifier(),
          ),
          transactionRepositoryProvider.overrideWithValue(repository),
          expenseAccountOptionsProvider.overrideWith(
            (ref) async => [
              Account(
                id: 'cash_default',
                name: 'Cash',
                type: AccountType.cash,
                balanceCents: 0,
                currencyCode: 'INR',
                isDefault: true,
                createdAt: DateTime(2026, 6, 20),
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('agent_chat_input')),
      'INR 450.00 spent on your HDFC Bank Credit Card at Swiggy on 20-06-26.',
    );
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(repository.transactions, hasLength(1));
    expect(repository.transactions.single.description, 'Swiggy');
    expect(repository.transactions.single.amountCents, -45000);
    expect(repository.transactions.single.categoryId, 'food');
    expect(repository.transactions.single.tags, contains('review:pending'));
    expect(
      find.textContaining('Queued for Coins review: Swiggy'),
      findsOneWidget,
    );
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.transactions, isEmpty);
    expect(find.textContaining('Removed Swiggy from Coins.'), findsOneWidget);
  });

  testWidgets('low-confidence finance text is still queued for Coins review', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    SharedPreferences.setMockInitialValues({
      'selected_assistant_model_id': geminiNanoAssistantModelId,
    });

    final repository = _InMemoryTransactionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyFormatterProvider.overrideWithValue(
            CurrencyFormatter.fromCode('INR'),
          ),
          selectedAssistantModelIdProvider.overrideWith(
            (ref) => _SelectedAssistantModelNotifier(),
          ),
          transactionRepositoryProvider.overrideWithValue(repository),
          expenseAccountOptionsProvider.overrideWith(
            (ref) async => [
              Account(
                id: 'cash_default',
                name: 'Cash',
                type: AccountType.cash,
                balanceCents: 0,
                currencyCode: 'INR',
                isDefault: true,
                createdAt: DateTime(2026, 6, 20),
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('agent_chat_input')),
      'Rs 299 spent',
    );
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(repository.transactions, hasLength(1));
    expect(
      repository.transactions.single.description,
      'Finance SMS transaction',
    );
    expect(repository.transactions.single.amountCents, -29900);
    expect(repository.transactions.single.tags, contains('review:pending'));
    expect(
      find.textContaining('Queued for Coins review: Finance SMS transaction'),
      findsOneWidget,
    );
    expect(find.text('Undo'), findsOneWidget);
  });
}

class _SelectedAssistantModelNotifier extends SelectedAssistantModelNotifier {
  _SelectedAssistantModelNotifier() {
    state = geminiNanoAssistantModelId;
  }
}

class _InMemoryTransactionRepository implements TransactionRepository {
  final List<Transaction> transactions = [];

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
  Future<Result<List<Transaction>>> findByTag(String tag) async {
    return (
      data: transactions
          .where((transaction) => transaction.tags.contains(tag))
          .toList(),
      error: null,
    );
  }

  @override
  Future<Result<void>> delete(String id) async {
    transactions.removeWhere((transaction) => transaction.id == id);
    return (data: null, error: null);
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
  Future<Result<Transaction>> findById(String id) async =>
      (data: null, error: 'not found');

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
