import '../../domain/entities/settlement.dart';
import '../datasources/coins_local_datasource.dart';

/// Mapper for Settlement entity <-> SettlementEntity conversion
///
/// Phase: 2 (Split Engine)
class SettlementMapper {
  /// Convert database entity to domain entity
  Settlement toDomain(SettlementEntity entity) {
    return Settlement(
      id: entity.id,
      groupId: entity.groupId,
      fromUserId: entity.fromUserId,
      toUserId: entity.toUserId,
      amountCents: entity.amountCents,
      currencyCode: entity.currencyCode,
      status: _parseSettlementStatus(entity.status),
      paymentMethod:
          _parsePaymentMethod(entity.paymentMethod) ?? PaymentMethod.cash,
      paymentReference: entity.paymentReference,
      notes: entity.notes,
      settlementDate: entity.completedAt ?? entity.createdAt,
      createdAt: entity.createdAt,
      updatedAt: entity.completedAt,
    );
  }

  /// Convert domain entity to database entity
  SettlementEntity toEntity(Settlement settlement) {
    return SettlementEntity(
      id: settlement.id,
      groupId: settlement.groupId,
      fromUserId: settlement.fromUserId,
      toUserId: settlement.toUserId,
      amountCents: settlement.amountCents,
      currencyCode: settlement.currencyCode,
      status: settlement.status.name,
      paymentMethod: settlement.paymentMethod.name,
      paymentReference: settlement.paymentReference,
      notes: settlement.notes,
      createdAt: settlement.createdAt,
      completedAt: settlement.updatedAt,
    );
  }

  SettlementStatus _parseSettlementStatus(String status) {
    return SettlementStatus.values.firstWhere(
      (s) => s.name == status,
      orElse: () => SettlementStatus.pending,
    );
  }

  PaymentMethod? _parsePaymentMethod(String? method) {
    if (method == null) return null;
    return PaymentMethod.values.firstWhere(
      (m) => m.name == method,
      orElse: () => PaymentMethod.other,
    );
  }
}
