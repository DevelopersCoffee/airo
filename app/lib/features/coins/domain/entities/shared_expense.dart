import 'package:equatable/equatable.dart';
import 'split_entry.dart';

/// Shared expense entity for group expenses
///
/// Represents an expense shared among group members with split details.
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_2.md (COINS-021)
class SharedExpense extends Equatable {
  final String id;
  final String groupId;
  final String description;
  final int totalAmountCents;
  final String currencyCode;
  final String categoryId;
  final String paidByUserId;
  final SplitType splitType;
  final List<SplitEntry> splits;
  final String? notes;
  final String? receiptId;
  final DateTime expenseDate;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SharedExpense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.totalAmountCents,
    this.currencyCode = 'INR',
    required this.categoryId,
    required this.paidByUserId,
    this.splitType = SplitType.equal,
    required this.splits,
    this.notes,
    this.receiptId,
    required this.expenseDate,
    this.isDeleted = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// Get total in major currency unit
  double get totalAmount => totalAmountCents / 100;

  /// Validate that splits sum to total
  bool get areSplitsValid {
    final splitSum = splits.fold<int>(0, (sum, s) => sum + s.amountCents);
    return splitSum == totalAmountCents;
  }

  /// Get the payer's split entry
  SplitEntry? get payerSplit {
    try {
      return splits.firstWhere((s) => s.userId == paidByUserId);
    } catch (_) {
      return null;
    }
  }

  /// Create a copy with updated fields
  SharedExpense copyWith({
    String? id,
    String? groupId,
    String? description,
    int? totalAmountCents,
    String? currencyCode,
    String? categoryId,
    String? paidByUserId,
    SplitType? splitType,
    List<SplitEntry>? splits,
    String? notes,
    String? receiptId,
    DateTime? expenseDate,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SharedExpense(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      description: description ?? this.description,
      totalAmountCents: totalAmountCents ?? this.totalAmountCents,
      currencyCode: currencyCode ?? this.currencyCode,
      categoryId: categoryId ?? this.categoryId,
      paidByUserId: paidByUserId ?? this.paidByUserId,
      splitType: splitType ?? this.splitType,
      splits: splits ?? this.splits,
      notes: notes ?? this.notes,
      receiptId: receiptId ?? this.receiptId,
      expenseDate: expenseDate ?? this.expenseDate,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        groupId,
        description,
        totalAmountCents,
        currencyCode,
        categoryId,
        paidByUserId,
        splitType,
        splits,
        notes,
        receiptId,
        expenseDate,
        isDeleted,
        createdAt,
        updatedAt,
      ];
}

