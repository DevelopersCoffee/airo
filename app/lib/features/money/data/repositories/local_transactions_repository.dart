import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/money_models.dart';
import '../../domain/repositories/money_repositories.dart';

/// Local database implementation of TransactionsRepository
/// Supports offline-first with sync status tracking
class LocalTransactionsRepository implements TransactionsRepository {
  final AppDatabase _db;
  final Uuid _uuid;

  LocalTransactionsRepository(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  @override
  Future<Result<List<Transaction>>> fetch(FetchTransactionsQuery query) async {
    try {
      var selectQuery = _db.select(_db.transactionEntries);
      
      // Apply filters
      selectQuery = selectQuery..where((t) {
        Expression<bool>? condition;
        
        if (query.accountId != null) {
          condition = t.accountId.equals(query.accountId!);
        }
        if (query.category != null) {
          final catCondition = t.category.equals(query.category!);
          condition = condition == null ? catCondition : condition & catCondition;
        }
        if (query.startDate != null) {
          final startCondition = t.timestamp.isBiggerOrEqualValue(query.startDate!);
          condition = condition == null ? startCondition : condition & startCondition;
        }
        if (query.endDate != null) {
          final endCondition = t.timestamp.isSmallerOrEqualValue(query.endDate!);
          condition = condition == null ? endCondition : condition & endCondition;
        }
        
        return condition ?? const Constant(true);
      });

      // Order by timestamp descending (newest first)
      selectQuery = selectQuery..orderBy([
        (t) => OrderingTerm.desc(t.timestamp),
      ]);

      // Apply limit and offset
      if (query.limit != null) {
        selectQuery = selectQuery..limit(query.limit!, offset: query.offset ?? 0);
      }

      final results = await selectQuery.get();
      return Ok(results.map(_mapToTransaction).toList());
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<Transaction>> fetchById(String id) async {
    try {
      final result = await (_db.select(_db.transactionEntries)
        ..where((t) => t.uuid.equals(id)))
        .getSingleOrNull();
      
      if (result == null) {
        return Err(Exception('Transaction not found'), StackTrace.current);
      }
      return Ok(_mapToTransaction(result));
    } catch (e, s) {
      return Err(e, s);
    }
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
    try {
      final uuid = _uuid.v4();
      final now = DateTime.now();
      
      await _db.into(_db.transactionEntries).insert(
        TransactionEntriesCompanion.insert(
          uuid: uuid,
          accountId: accountId,
          timestamp: timestamp,
          amountCents: amountCents,
          description: description,
          category: category,
          tags: Value(jsonEncode(tags)),
          receiptUrl: Value(receiptUrl),
          syncStatus: const Value('pending'),
          createdAt: Value(now),
        ),
      );

      final transaction = Transaction(
        id: uuid,
        accountId: accountId,
        timestamp: timestamp,
        amountCents: amountCents,
        description: description,
        category: category,
        tags: tags,
        receiptUrl: receiptUrl,
        createdAt: now,
      );

      return Ok(transaction);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<Transaction>> update(Transaction transaction) async {
    try {
      final now = DateTime.now();
      await (_db.update(_db.transactionEntries)
        ..where((t) => t.uuid.equals(transaction.id)))
        .write(TransactionEntriesCompanion(
          accountId: Value(transaction.accountId),
          timestamp: Value(transaction.timestamp),
          amountCents: Value(transaction.amountCents),
          description: Value(transaction.description),
          category: Value(transaction.category),
          tags: Value(jsonEncode(transaction.tags)),
          receiptUrl: Value(transaction.receiptUrl),
          syncStatus: const Value('pending'),
          updatedAt: Value(now),
        ));

      return Ok(transaction);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await (_db.delete(_db.transactionEntries)
        ..where((t) => t.uuid.equals(id)))
        .go();
      return const Ok(null);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<List<Transaction>>> getForAccount(String accountId) async {
    return fetch(FetchTransactionsQuery(accountId: accountId));
  }

  @override
  Future<Result<List<Transaction>>> getByCategory(String category) async {
    return fetch(FetchTransactionsQuery(category: category));
  }

  @override
  Future<Result<List<Transaction>>> getByTag(String tag) async {
    try {
      final results = await _db.select(_db.transactionEntries).get();
      final filtered = results.where((t) {
        try {
          final tags = (jsonDecode(t.tags) as List).cast<String>();
          return tags.contains(tag);
        } catch (_) {
          return false;
        }
      }).toList();
      return Ok(filtered.map(_mapToTransaction).toList());
    } catch (e, s) {
      return Err(e, s);
    }
  }

  // CacheRepository methods
  @override
  Future<Transaction?> get(String id) async {
    final result = await fetchById(id);
    return result.getOrNull();
  }

  @override
  Future<void> put(String id, Transaction data) async {
    await update(data);
  }

  @override
  Future<List<Transaction>> getAll() async {
    final result = await fetch(const FetchTransactionsQuery());
    return result.getOrNull() ?? [];
  }

  @override
  Future<bool> exists(String id) async {
    final result = await fetchById(id);
    return result.isOk;
  }

  @override
  Future<void> clear() async {
    await _db.delete(_db.transactionEntries).go();
  }

  /// Get transactions with pending sync status (for offline-outbox)
  Future<List<Transaction>> getPendingSync() async {
    try {
      final results = await (_db.select(_db.transactionEntries)
        ..where((t) => t.syncStatus.equals('pending')))
        .get();
      return results.map(_mapToTransaction).toList();
    } catch (_) {
      return [];
    }
  }

  /// Mark transaction as synced
  Future<void> markSynced(String id) async {
    await (_db.update(_db.transactionEntries)
      ..where((t) => t.uuid.equals(id)))
      .write(TransactionEntriesCompanion(
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ));
  }

  /// Watch transactions stream for reactive UI
  Stream<List<Transaction>> watchTransactions({int? limit}) {
    var query = _db.select(_db.transactionEntries)
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]);

    if (limit != null) {
      query = query..limit(limit);
    }

    return query.watch().map(
      (entries) => entries.map(_mapToTransaction).toList(),
    );
  }

  Transaction _mapToTransaction(TransactionEntry entry) {
    List<String> tags = [];
    try {
      tags = (jsonDecode(entry.tags) as List).cast<String>();
    } catch (_) {}

    return Transaction(
      id: entry.uuid,
      accountId: entry.accountId,
      timestamp: entry.timestamp,
      amountCents: entry.amountCents,
      description: entry.description,
      category: entry.category,
      tags: tags,
      receiptUrl: entry.receiptUrl,
      createdAt: entry.createdAt,
    );
  }
}

