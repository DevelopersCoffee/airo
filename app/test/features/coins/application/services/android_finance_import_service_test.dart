import 'package:airo_app/features/coins/application/services/android_finance_import_service.dart';
import 'package:airo_app/features/coins/application/services/finance_chat_ingestion_service.dart';
import 'package:airo_app/features/coins/domain/entities/transaction.dart';
import 'package:airo_app/features/coins/domain/repositories/transaction_repository.dart';
import 'package:airo_app/features/coins/domain/services/finance_message_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AndroidFinanceImportService', () {
    test('does not import SMS text when permission is disabled', () async {
      final repository = _InMemoryTransactionRepository();
      final service = AndroidFinanceImportService(
        ingestionService: FinanceChatIngestionService(
          parser: const FinanceMessageParser(),
          repository: repository,
        ),
        permissionReader: () async => AndroidFinanceImportPermission.disabled,
      );

      final result = await service.importText(
        'INR 450.00 spent on your HDFC Bank Credit Card at Swiggy on 20-06-26.',
        accountId: 'cash_default',
      );

      expect(result.status, AndroidFinanceImportStatus.permissionDisabled);
      expect(repository.transactions, isEmpty);
      expect(
        result.message,
        contains('Enable Android SMS or notification import'),
      );
    });

    test('imports allowed financial SMS locally into the review queue', () async {
      final repository = _InMemoryTransactionRepository();
      final service = AndroidFinanceImportService(
        ingestionService: FinanceChatIngestionService(
          parser: FinanceMessageParser(now: () => DateTime(2026, 6, 20)),
          repository: repository,
        ),
        permissionReader: () async => AndroidFinanceImportPermission.enabled,
      );

      final result = await service.importText(
        'INR 450.00 spent on your HDFC Bank Credit Card at Swiggy on 20-06-26.',
        accountId: 'cash_default',
      );

      expect(result.status, AndroidFinanceImportStatus.queuedForReview);
      expect(repository.transactions, hasLength(1));
      expect(repository.transactions.single.description, 'Swiggy');
      expect(repository.transactions.single.tags, contains('review:pending'));
      expect(
        repository.transactions.single.tags,
        contains('source:android_import'),
      );
    });

    test('ignores OTP/auth messages without writing a transaction', () async {
      final repository = _InMemoryTransactionRepository();
      final service = AndroidFinanceImportService(
        ingestionService: FinanceChatIngestionService(
          parser: const FinanceMessageParser(),
          repository: repository,
        ),
        permissionReader: () async => AndroidFinanceImportPermission.enabled,
      );

      final result = await service.importText(
        'OTP 123456 for INR 1.00 card verification at HDFC Bank. Do not share.',
        accountId: 'cash_default',
      );

      expect(result.status, AndroidFinanceImportStatus.ignored);
      expect(repository.transactions, isEmpty);
    });
  });
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
