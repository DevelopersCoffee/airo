import 'package:airo_app/features/coins/application/services/finance_chat_ingestion_service.dart';
import 'package:airo_app/features/coins/domain/entities/transaction.dart';
import 'package:airo_app/features/coins/domain/repositories/transaction_repository.dart';
import 'package:airo_app/features/coins/domain/services/finance_message_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinanceChatIngestionService', () {
    test(
      'queues transaction from high-confidence finance SMS for review',
      () async {
        final repository = _InMemoryTransactionRepository();
        final service = FinanceChatIngestionService(
          parser: FinanceMessageParser(now: () => DateTime(2026, 6, 20)),
          repository: repository,
        );

        final result = await service.ingest(
          'INR 299.00 spent on your card at Zomato on 20-06-26.',
          accountId: 'cash_default',
        );

        expect(result.status, FinanceChatIngestionStatus.needsReview);
        expect(repository.transactions, hasLength(1));
        expect(result.transaction, repository.transactions.single);
        expect(repository.transactions.single.amountCents, -29900);
        expect(repository.transactions.single.description, 'Zomato');
        expect(repository.transactions.single.tags, contains('source:chat'));
        expect(repository.transactions.single.tags, contains('review:pending'));
        expect(
          repository.transactions.single.tags,
          contains('source:parser:finance_message_parser'),
        );
        expect(
          repository.transactions.single.tags,
          contains('parser_version:v1'),
        );
        expect(
          repository.transactions.single.tags.any(
            (tag) => tag.startsWith('source:chat_sms:'),
          ),
          isTrue,
        );
        expect(
          repository.transactions.single.tags.any(
            (tag) => tag.startsWith('source:raw_text_b64:'),
          ),
          isTrue,
        );
      },
    );

    test('updates existing transaction for the same SMS source tag', () async {
      final repository = _InMemoryTransactionRepository();
      final service = FinanceChatIngestionService(
        parser: FinanceMessageParser(now: () => DateTime(2026, 6, 20)),
        repository: repository,
      );
      const sms =
          'INR 650.00 debited from A/c XX1234 to Uber on 20-06-26 via UPI.';

      final first = await service.ingest(sms, accountId: 'cash_default');
      final second = await service.ingest(sms, accountId: 'bank_default');

      expect(first.status, FinanceChatIngestionStatus.needsReview);
      expect(second.status, FinanceChatIngestionStatus.needsReview);
      expect(repository.transactions, hasLength(1));
      expect(repository.transactions.single.accountId, 'bank_default');
      expect(repository.transactions.single.categoryId, 'transport');
      expect(repository.transactions.single.tags, contains('review:pending'));
    });

    test('ignores unrelated chat text', () async {
      final repository = _InMemoryTransactionRepository();
      final service = FinanceChatIngestionService(
        parser: FinanceMessageParser(now: () => DateTime(2026, 6, 20)),
        repository: repository,
      );

      final result = await service.ingest(
        'open chess please',
        accountId: 'cash_default',
      );

      expect(result.status, FinanceChatIngestionStatus.ignored);
      expect(repository.transactions, isEmpty);
    });

    test(
      'queues low-confidence finance text for review instead of dropping it',
      () async {
        final repository = _InMemoryTransactionRepository();
        final service = FinanceChatIngestionService(
          parser: FinanceMessageParser(now: () => DateTime(2026, 6, 20)),
          repository: repository,
        );

        final result = await service.ingest(
          'Rs 299 spent',
          accountId: 'cash_default',
        );

        expect(result.status, FinanceChatIngestionStatus.needsReview);
        expect(result.transaction, isNotNull);
        expect(repository.transactions, hasLength(1));
        expect(
          repository.transactions.single.description,
          'Finance SMS transaction',
        );
        expect(repository.transactions.single.amountCents, -29900);
        expect(repository.transactions.single.tags, contains('review:pending'));
        expect(
          repository.transactions.single.tags,
          contains('confidence:0.55'),
        );
      },
    );
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
