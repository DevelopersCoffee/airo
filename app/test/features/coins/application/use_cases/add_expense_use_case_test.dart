import 'package:airo_app/features/coins/application/use_cases/add_expense_use_case.dart'
    hide Result;
import 'package:airo_app/features/coins/domain/entities/transaction.dart';
import 'package:airo_app/features/coins/domain/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores expenses as negative amounts so spending totals work', () async {
    final repository = _CapturingTransactionRepository();
    final useCase = AddExpenseUseCase(repository);

    final result = await useCase.execute(
      const AddExpenseParams(
        description: 'Lunch',
        amountCents: 1250,
        type: TransactionType.expense,
        categoryId: 'food',
        accountId: 'cash',
      ),
    );

    expect(result.error, isNull);
    expect(repository.createdTransaction?.amountCents, -1250);
    expect(repository.createdTransaction?.type, TransactionType.expense);
  });

  test('stores income as positive amounts', () async {
    final repository = _CapturingTransactionRepository();
    final useCase = AddExpenseUseCase(repository);

    final result = await useCase.execute(
      const AddExpenseParams(
        description: 'Salary',
        amountCents: 500000,
        type: TransactionType.income,
        categoryId: 'salary',
        accountId: 'bank',
      ),
    );

    expect(result.error, isNull);
    expect(repository.createdTransaction?.amountCents, 500000);
    expect(repository.createdTransaction?.type, TransactionType.income);
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
