import 'package:meta/meta.dart';

import '../result/result.dart';

/// Lifecycle for a confirmed destination write tied to one idempotency key.
enum IdempotentEffectState {
  pending,
  committed,
  failed,
  reconciling;

  static IdempotentEffectState fromJson(String value) =>
      IdempotentEffectState.values.firstWhere((item) => item.name == value);

  String toJson() => name;
}

@immutable
class IdempotentEffectRecord {
  const IdempotentEffectRecord({
    required this.idempotencyKey,
    required this.confirmationHash,
    required this.state,
    required this.resourceId,
    required this.createdAt,
    required this.updatedAt,
    this.destinationReceipt,
  });

  final String idempotencyKey;
  final String confirmationHash;
  final IdempotentEffectState state;
  final String resourceId;
  final String? destinationReceipt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory IdempotentEffectRecord.fromJson(Map<String, dynamic> json) =>
      IdempotentEffectRecord(
        idempotencyKey: json['idempotency_key'] as String,
        confirmationHash: json['confirmation_hash'] as String,
        state: IdempotentEffectState.fromJson(json['state'] as String),
        resourceId: json['resource_id'] as String,
        destinationReceipt: json['destination_receipt'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['created_at'] as int,
          isUtc: true,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          json['updated_at'] as int,
          isUtc: true,
        ),
      );

  Map<String, dynamic> toJson() => {
    'idempotency_key': idempotencyKey,
    'confirmation_hash': confirmationHash,
    'state': state.toJson(),
    'resource_id': resourceId,
    if (destinationReceipt != null)
      'destination_receipt': destinationReceipt,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };
}

/// Destination port for atomically recording confirmed writes.
abstract interface class IdempotentEffectPort {
  Future<Result<IdempotentEffectRecord?>> findByKey(String idempotencyKey);

  Future<Result<IdempotentEffectRecord>> beginEffect({
    required String idempotencyKey,
    required String confirmationHash,
    required String resourceId,
  });

  Future<Result<void>> commitEffect({
    required String idempotencyKey,
    required String destinationReceipt,
  });

  Future<Result<void>> markFailed(String idempotencyKey);
}
