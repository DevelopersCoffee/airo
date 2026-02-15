import 'dart:convert';
import '../../domain/entities/transaction.dart';
import '../datasources/coins_local_datasource.dart';

/// Mapper for Transaction entity <-> TransactionEntity conversion
///
/// Phase: 1 (Foundation)
class TransactionMapper {
  /// Convert database entity to domain entity
  Transaction toDomain(TransactionEntity entity) {
    return Transaction(
      id: entity.id,
      description: entity.description,
      amountCents: entity.amountCents,
      type: _parseTransactionType(entity.type),
      categoryId: entity.categoryId,
      accountId: entity.accountId,
      transactionDate: entity.transactionDate,
      notes: entity.notes,
      receiptId: entity.receiptId,
      tags: _parseTags(entity.tags),
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isDeleted: entity.isDeleted,
    );
  }

  /// Convert domain entity to database entity
  TransactionEntity toEntity(Transaction transaction) {
    return TransactionEntity(
      id: transaction.id,
      description: transaction.description,
      amountCents: transaction.amountCents,
      type: transaction.type.name,
      categoryId: transaction.categoryId,
      accountId: transaction.accountId,
      transactionDate: transaction.transactionDate,
      notes: transaction.notes,
      receiptId: transaction.receiptId,
      tags: jsonEncode(transaction.tags),
      createdAt: transaction.createdAt,
      updatedAt: transaction.updatedAt,
      isDeleted: transaction.isDeleted,
    );
  }

  TransactionType _parseTransactionType(String type) {
    return TransactionType.values.firstWhere(
      (t) => t.name == type,
      orElse: () => TransactionType.expense,
    );
  }

  List<String> _parseTags(String? tagsJson) {
    if (tagsJson == null || tagsJson.isEmpty) return [];
    try {
      final decoded = jsonDecode(tagsJson);
      return (decoded as List).cast<String>();
    } catch (_) {
      return [];
    }
  }
}

