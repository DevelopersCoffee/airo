import 'package:equatable/equatable.dart';

/// Debt entry representing who owes whom
///
/// Used in balance calculation to track individual debts between members.
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_2.md (COINS-026)
class DebtEntry extends Equatable {
  final String fromUserId; // Who owes
  final String toUserId; // Who is owed
  final int amountCents;
  final String currencyCode;

  const DebtEntry({
    required this.fromUserId,
    required this.toUserId,
    required this.amountCents,
    this.currencyCode = 'INR',
  });

  /// Get amount in major currency unit
  double get amount => amountCents / 100;

  /// Check if this debt involves a specific user
  bool involvesUser(String userId) =>
      fromUserId == userId || toUserId == userId;

  /// Get the counterpart user for a given user
  String? getCounterpart(String userId) {
    if (fromUserId == userId) return toUserId;
    if (toUserId == userId) return fromUserId;
    return null;
  }

  /// Create a reversed debt (swap from/to)
  DebtEntry reversed() {
    return DebtEntry(
      fromUserId: toUserId,
      toUserId: fromUserId,
      amountCents: amountCents,
      currencyCode: currencyCode,
    );
  }

  /// Create a copy with updated fields
  DebtEntry copyWith({
    String? fromUserId,
    String? toUserId,
    int? amountCents,
    String? currencyCode,
  }) {
    return DebtEntry(
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      amountCents: amountCents ?? this.amountCents,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }

  @override
  List<Object?> get props => [
        fromUserId,
        toUserId,
        amountCents,
        currencyCode,
      ];
}

