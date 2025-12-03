/// Stub for LocalTransactionsRepository on web platform
/// Web uses FakeTransactionsRepository from money_provider.dart instead

import '../../domain/models/money_models.dart';
import '../../domain/repositories/money_repositories.dart';
import '../../../../core/utils/result.dart';

/// Stub class - not actually used on web, but needed for type compatibility
class LocalTransactionsRepository implements TransactionsRepository {
  LocalTransactionsRepository(dynamic db);

  @override
  Future<Result<List<Transaction>>> fetch(FetchTransactionsQuery query) async {
    return const Ok([]);
  }

  @override
  Future<Result<Transaction>> fetchById(String id) async {
    return Err(Exception('Not implemented on web'), StackTrace.current);
  }

  @override
  Future<Result<Transaction>> create({
    required String accountId,
    required DateTime timestamp,
    required int amountCents,
    required String description,
    required String category,
    List<String> tags = const [],
    String? receiptUrl,
  }) async {
    return Err(Exception('Not implemented on web'), StackTrace.current);
  }

  @override
  Future<Result<Transaction>> update(Transaction transaction) async {
    return Err(Exception('Not implemented on web'), StackTrace.current);
  }

  @override
  Future<Result<void>> delete(String id) async {
    return const Ok(null);
  }

  @override
  Future<Result<List<Transaction>>> getForAccount(String accountId) async {
    return const Ok([]);
  }

  @override
  Future<Transaction?> get(String id) async => null;

  @override
  Future<void> put(String id, Transaction data) async {}

  @override
  Future<List<Transaction>> getAll() async => [];

  @override
  Future<bool> exists(String id) async => false;

  @override
  Future<void> clear() async {}

  /// Watch transactions stream - returns empty stream on web
  Stream<List<Transaction>> watchTransactions({int? limit}) {
    return Stream.value([]);
  }

  @override
  Future<Result<List<Transaction>>> getByCategory(String category) async {
    return const Ok([]);
  }

  @override
  Future<Result<List<Transaction>>> getByTag(String tag) async {
    return const Ok([]);
  }
}
