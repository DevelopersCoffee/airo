import 'package:equatable/equatable.dart';

/// Transaction types supported by Coins
enum TransactionType {
  expense('Expense'),
  income('Income'),
  transfer('Transfer');

  final String displayName;
  const TransactionType(this.displayName);
}

/// Transaction entity representing a financial transaction
///
/// Core business entity for expense tracking in Coins feature.
/// All amounts are stored in smallest currency unit (paise/cents).
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/DOMAIN_API_CONTRACTS.md
class Transaction extends Equatable {
  final String id;
  final String description;
  final int amountCents; // Always stored in smallest currency unit
  final TransactionType type;
  final String categoryId;
  final String accountId;
  final DateTime transactionDate;
  final String? notes;
  final String? receiptId;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted; // Soft delete for undo support

  const Transaction({
    required this.id,
    required this.description,
    required this.amountCents,
    required this.type,
    required this.categoryId,
    required this.accountId,
    required this.transactionDate,
    this.notes,
    this.receiptId,
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  });

  /// Get amount in major currency unit (rupees/dollars)
  double get amount => amountCents / 100;

  /// Create a copy with updated fields
  Transaction copyWith({
    String? id,
    String? description,
    int? amountCents,
    TransactionType? type,
    String? categoryId,
    String? accountId,
    DateTime? transactionDate,
    String? notes,
    String? receiptId,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Transaction(
      id: id ?? this.id,
      description: description ?? this.description,
      amountCents: amountCents ?? this.amountCents,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      transactionDate: transactionDate ?? this.transactionDate,
      notes: notes ?? this.notes,
      receiptId: receiptId ?? this.receiptId,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        description,
        amountCents,
        type,
        categoryId,
        accountId,
        transactionDate,
        notes,
        receiptId,
        tags,
        createdAt,
        updatedAt,
        isDeleted,
      ];
}

