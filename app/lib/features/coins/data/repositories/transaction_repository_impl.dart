import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/coins_local_datasource.dart';
import '../mappers/transaction_mapper.dart';

/// Implementation of TransactionRepository
///
/// Uses local datasource for offline-first storage.
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/PROJECT_STRUCTURE.md
class TransactionRepositoryImpl implements TransactionRepository {
  final CoinsLocalDatasource _localDatasource;
  final TransactionMapper _mapper;

  TransactionRepositoryImpl(this._localDatasource, this._mapper);

  @override
  Future<Result<Transaction>> findById(String id) async {
    try {
      final entity = await _localDatasource.getTransactionById(id);
      if (entity == null) {
        return (data: null, error: 'Transaction not found');
      }
      return (data: _mapper.toDomain(entity), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch transaction: $e');
    }
  }

  @override
  Future<Result<List<Transaction>>> findByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final entities = await _localDatasource.getTransactionsByDateRange(
        start,
        end,
      );
      return (data: entities.map(_mapper.toDomain).toList(), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch transactions: $e');
    }
  }

  @override
  Future<Result<List<Transaction>>> findByCategory(String categoryId) async {
    try {
      final entities =
          await _localDatasource.getTransactionsByCategory(categoryId);
      return (data: entities.map(_mapper.toDomain).toList(), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch transactions: $e');
    }
  }

  @override
  Future<Result<List<Transaction>>> findByAccount(String accountId) async {
    try {
      final entities =
          await _localDatasource.getTransactionsByAccount(accountId);
      return (data: entities.map(_mapper.toDomain).toList(), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch transactions: $e');
    }
  }

  @override
  Future<Result<List<Transaction>>> findRecent({int limit = 10}) async {
    try {
      final entities = await _localDatasource.getRecentTransactions(limit);
      return (data: entities.map(_mapper.toDomain).toList(), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch transactions: $e');
    }
  }

  @override
  Future<Result<Transaction>> create(Transaction transaction) async {
    try {
      final entity = _mapper.toEntity(transaction);
      await _localDatasource.insertTransaction(entity);
      return (data: transaction, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to create transaction: $e');
    }
  }

  @override
  Future<Result<Transaction>> update(Transaction transaction) async {
    try {
      final entity = _mapper.toEntity(transaction);
      await _localDatasource.updateTransaction(entity);
      return (data: transaction, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to update transaction: $e');
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _localDatasource.softDeleteTransaction(id);
      return (data: null, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to delete transaction: $e');
    }
  }

  @override
  Future<Result<void>> hardDelete(String id) async {
    try {
      await _localDatasource.hardDeleteTransaction(id);
      return (data: null, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to delete transaction: $e');
    }
  }

  @override
  Future<Result<Transaction>> restore(String id) async {
    try {
      await _localDatasource.restoreTransaction(id);
      final entity = await _localDatasource.getTransactionById(id);
      if (entity == null) {
        return (data: null, error: 'Transaction not found after restore');
      }
      return (data: _mapper.toDomain(entity), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to restore transaction: $e');
    }
  }

  @override
  Stream<List<Transaction>> watchAll() {
    return _localDatasource
        .watchAllTransactions()
        .map((entities) => entities.map(_mapper.toDomain).toList());
  }

  @override
  Stream<List<Transaction>> watchByCategory(String categoryId) {
    return _localDatasource
        .watchTransactionsByCategory(categoryId)
        .map((entities) => entities.map(_mapper.toDomain).toList());
  }

  @override
  Stream<List<Transaction>> watchByDate(DateTime date) {
    return _localDatasource
        .watchTransactionsByDate(date)
        .map((entities) => entities.map(_mapper.toDomain).toList());
  }

  @override
  Future<Result<int>> getTotalSpent(DateTime start, DateTime end) async {
    try {
      final total = await _localDatasource.getTotalSpent(start, end);
      return (data: total, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to calculate total: $e');
    }
  }

  @override
  Future<Result<Map<String, int>>> getSpentByCategory(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final totals = await _localDatasource.getSpentByCategory(start, end);
      return (data: totals, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to calculate totals: $e');
    }
  }

  @override
  Future<Result<List<Transaction>>> search(String query) async {
    try {
      final entities = await _localDatasource.searchTransactions(query);
      return (data: entities.map(_mapper.toDomain).toList(), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to search transactions: $e');
    }
  }
}

