import '../../domain/entities/settlement.dart';
import '../../domain/repositories/settlement_repository.dart';

/// Result type for use case operations
typedef Result<T> = ({T? data, String? error});

/// Use case for recording a settlement
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_2.md (COINS-029)
class RecordSettlementUseCase {
  final SettlementRepository _repository;

  RecordSettlementUseCase(this._repository);

  /// Record a new settlement
  Future<Result<Settlement>> execute(RecordSettlementParams params) async {
    // Validate
    if (params.groupId.isEmpty) {
      return (data: null, error: 'Group ID is required');
    }

    if (params.fromUserId.isEmpty) {
      return (data: null, error: 'Payer ID is required');
    }

    if (params.toUserId.isEmpty) {
      return (data: null, error: 'Recipient ID is required');
    }

    if (params.fromUserId == params.toUserId) {
      return (data: null, error: 'Cannot settle with yourself');
    }

    if (params.amountCents <= 0) {
      return (data: null, error: 'Amount must be greater than zero');
    }

    final now = DateTime.now();

    final settlement = Settlement(
      id: _generateId(),
      groupId: params.groupId,
      fromUserId: params.fromUserId,
      toUserId: params.toUserId,
      amountCents: params.amountCents,
      currencyCode: params.currencyCode,
      status: params.markAsCompleted
          ? SettlementStatus.completed
          : SettlementStatus.pending,
      paymentMethod: params.paymentMethod,
      paymentReference: params.paymentReference,
      notes: params.notes,
      createdAt: now,
      completedAt: params.markAsCompleted ? now : null,
    );

    return _repository.create(settlement);
  }

  /// Mark a settlement as completed
  Future<Result<Settlement>> complete(String settlementId) async {
    return _repository.complete(settlementId);
  }

  /// Cancel a pending settlement
  Future<Result<Settlement>> cancel(String settlementId) async {
    return _repository.cancel(settlementId);
  }

  String _generateId() {
    return 'settlement_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Parameters for recording a settlement
class RecordSettlementParams {
  final String groupId;
  final String fromUserId;
  final String toUserId;
  final int amountCents;
  final String currencyCode;
  final PaymentMethod? paymentMethod;
  final String? paymentReference;
  final String? notes;
  final bool markAsCompleted;

  const RecordSettlementParams({
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amountCents,
    this.currencyCode = 'INR',
    this.paymentMethod,
    this.paymentReference,
    this.notes,
    this.markAsCompleted = false,
  });
}

