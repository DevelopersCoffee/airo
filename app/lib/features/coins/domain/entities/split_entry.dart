import 'package:equatable/equatable.dart';

/// Split type options
enum SplitType {
  equal('Equal Split'),
  percentage('By Percentage'),
  exact('Exact Amounts'),
  shares('By Shares'),
  itemized('By Items');

  final String displayName;
  const SplitType(this.displayName);
}

/// Split entry representing a user's share of an expense
///
/// Contains the calculated amount each person owes for a shared expense.
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_2.md (COINS-022)
class SplitEntry extends Equatable {
  final String id;
  final String sharedExpenseId;
  final String userId;
  final int amountCents;
  final double? percentage; // Used for percentage split
  final int? shares; // Used for shares-based split
  final List<String>? itemIds; // Used for itemized split
  final bool isPaid; // Has this person settled their share?
  final DateTime? paidAt;
  final DateTime createdAt;

  const SplitEntry({
    required this.id,
    required this.sharedExpenseId,
    required this.userId,
    required this.amountCents,
    this.percentage,
    this.shares,
    this.itemIds,
    this.isPaid = false,
    this.paidAt,
    required this.createdAt,
  });

  /// Get amount in major currency unit
  double get amount => amountCents / 100;

  /// Create a copy with updated fields
  SplitEntry copyWith({
    String? id,
    String? sharedExpenseId,
    String? userId,
    int? amountCents,
    double? percentage,
    int? shares,
    List<String>? itemIds,
    bool? isPaid,
    DateTime? paidAt,
    DateTime? createdAt,
  }) {
    return SplitEntry(
      id: id ?? this.id,
      sharedExpenseId: sharedExpenseId ?? this.sharedExpenseId,
      userId: userId ?? this.userId,
      amountCents: amountCents ?? this.amountCents,
      percentage: percentage ?? this.percentage,
      shares: shares ?? this.shares,
      itemIds: itemIds ?? this.itemIds,
      isPaid: isPaid ?? this.isPaid,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        sharedExpenseId,
        userId,
        amountCents,
        percentage,
        shares,
        itemIds,
        isPaid,
        paidAt,
        createdAt,
      ];
}

