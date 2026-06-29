import 'package:airo_app/features/coins/application/services/transaction_review_service.dart';
import 'package:airo_app/features/coins/domain/entities/transaction.dart';
import 'package:airo_app/features/coins/domain/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransactionReviewService', () {
    test('lists imported transactions that still need review', () async {
      final repository = _InMemoryTransactionRepository([
        _transaction(id: 'pending', tags: const ['review:pending']),
        _transaction(id: 'approved', tags: const ['review:approved']),
      ]);
      final service = TransactionReviewService(repository: repository);

      final pending = await service.pendingImportedTransactions();

      expect(pending.error, isNull);
      expect(pending.data, hasLength(1));
      expect(pending.data!.single.id, 'pending');
    });

    test(
      'approves a pending imported transaction without losing source metadata',
      () async {
        final repository = _InMemoryTransactionRepository([
          _transaction(
            tags: const [
              'review:pending',
              'source:chat_sms:abc123',
              'source:raw_text_b64:UkFXX1NNUw==',
            ],
          ),
        ]);
        final service = TransactionReviewService(repository: repository);

        final result = await service.approve('txn_1');

        expect(result.error, isNull);
        expect(result.data!.tags, contains('review:approved'));
        expect(result.data!.tags, isNot(contains('review:pending')));
        expect(result.data!.tags, contains('source:chat_sms:abc123'));
        expect(result.data!.tags, contains('source:raw_text_b64:UkFXX1NNUw=='));
        expect(repository.transactions.single.isDeleted, isFalse);
      },
    );

    test(
      'edits amount date merchant category and account while keeping review pending',
      () async {
        final repository = _InMemoryTransactionRepository([
          _transaction(
            tags: const ['review:pending', 'source:chat_sms:abc123'],
          ),
        ]);
        final service = TransactionReviewService(repository: repository);
        final newDate = DateTime(2026, 6, 21);

        final result = await service.edit(
          'txn_1',
          TransactionReviewEdit(
            amountCents: -42550,
            transactionDate: newDate,
            merchant: 'Big Basket',
            categoryId: 'food',
            accountId: 'hdfc_card',
          ),
        );

        expect(result.error, isNull);
        expect(result.data!.amountCents, -42550);
        expect(result.data!.transactionDate, newDate);
        expect(result.data!.description, 'Big Basket');
        expect(result.data!.categoryId, 'food');
        expect(result.data!.accountId, 'hdfc_card');
        expect(result.data!.tags, contains('review:pending'));
        expect(result.data!.tags, contains('source:chat_sms:abc123'));
      },
    );

    test(
      'rejects a pending imported transaction and removes it from active ledger',
      () async {
        final repository = _InMemoryTransactionRepository([
          _transaction(
            tags: const ['review:pending', 'source:chat_sms:abc123'],
          ),
        ]);
        final service = TransactionReviewService(repository: repository);

        final result = await service.reject('txn_1');

        expect(result.error, isNull);
        expect(result.data!.tags, contains('review:rejected'));
        expect(result.data!.tags, isNot(contains('review:pending')));
        expect(repository.transactions.single.isDeleted, isTrue);
        expect(
          repository.transactions.single.tags,
          contains('source:chat_sms:abc123'),
        );
      },
    );

    test(
      'marks duplicate imported transaction and removes it from active ledger',
      () async {
        final repository = _InMemoryTransactionRepository([
          _transaction(
            tags: const ['review:pending', 'source:chat_sms:abc123'],
          ),
        ]);
        final service = TransactionReviewService(repository: repository);

        final result = await service.markDuplicate('txn_1');

        expect(result.error, isNull);
        expect(result.data!.tags, contains('review:duplicate'));
        expect(result.data!.tags, isNot(contains('review:pending')));
        expect(repository.transactions.single.isDeleted, isTrue);
        expect(
          repository.transactions.single.tags,
          contains('source:chat_sms:abc123'),
        );
      },
    );
  });
}

Transaction _transaction({String id = 'txn_1', List<String> tags = const []}) {
  return Transaction(
    id: id,
    description: 'Zomato',
    amountCents: -29900,
    type: TransactionType.expense,
    categoryId: 'shopping',
    accountId: 'cash_default',
    transactionDate: DateTime(2026, 6, 20),
    tags: tags,
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
  Future<Result<List<Transaction>>> findByTag(String tag) async {
    return (
      data: transactions
          .where(
            (transaction) =>
                !transaction.isDeleted && transaction.tags.contains(tag),
          )
          .toList(),
      error: null,
    );
  }

  @override
  Future<Result<Transaction>> findById(String id) async {
    final matches = transactions.where((item) => item.id == id).toList();
    if (matches.isEmpty) return (data: null, error: 'not found');
    return (data: matches.single, error: null);
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
