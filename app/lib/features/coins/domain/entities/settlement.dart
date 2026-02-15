import 'package:equatable/equatable.dart';

/// Settlement status
enum SettlementStatus {
  pending('Pending'),
  completed('Completed'),
  cancelled('Cancelled');

  final String displayName;
  const SettlementStatus(this.displayName);
}

/// Payment method for settlement
enum PaymentMethod {
  cash('Cash'),
  upi('UPI'),
  bankTransfer('Bank Transfer'),
  other('Other');

  final String displayName;
  const PaymentMethod(this.displayName);
}

/// Settlement entity for recording debt payments
///
/// Represents a payment between two group members to settle debts.
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_2.md (COINS-029)
class Settlement extends Equatable {
  final String id;
  final String groupId;
  final String fromUserId; // Who paid
  final String toUserId; // Who received
  final int amountCents;
  final String currencyCode;
  final PaymentMethod paymentMethod;
  final String? paymentReference; // UPI ID, transaction ID, etc.
  final String? notes;
  final SettlementStatus status;
  final DateTime settlementDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Settlement({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amountCents,
    this.currencyCode = 'INR',
    this.paymentMethod = PaymentMethod.cash,
    this.paymentReference,
    this.notes,
    this.status = SettlementStatus.pending,
    required this.settlementDate,
    required this.createdAt,
    this.updatedAt,
  });

  /// Get amount in major currency unit
  double get amount => amountCents / 100;

  /// Check if settlement is completed
  bool get isCompleted => status == SettlementStatus.completed;

  /// Create a copy with updated fields
  Settlement copyWith({
    String? id,
    String? groupId,
    String? fromUserId,
    String? toUserId,
    int? amountCents,
    String? currencyCode,
    PaymentMethod? paymentMethod,
    String? paymentReference,
    String? notes,
    SettlementStatus? status,
    DateTime? settlementDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Settlement(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      amountCents: amountCents ?? this.amountCents,
      currencyCode: currencyCode ?? this.currencyCode,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReference: paymentReference ?? this.paymentReference,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      settlementDate: settlementDate ?? this.settlementDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        groupId,
        fromUserId,
        toUserId,
        amountCents,
        currencyCode,
        paymentMethod,
        paymentReference,
        notes,
        status,
        settlementDate,
        createdAt,
        updatedAt,
      ];
}

