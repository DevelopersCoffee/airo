import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SecureDestinationUnavailableError uses stable code', () {
    final error = SecureDestinationUnavailableError('blocked');
    expect(error.code, 'secure_destination_unavailable');
    expect(error.statusCode, 503);
  });

  test('IdempotentEffectRecord round-trips JSON', () {
    final record = IdempotentEffectRecord(
      idempotencyKey: 'idem-1',
      confirmationHash: 'hash',
      state: IdempotentEffectState.pending,
      resourceId: 'track-1',
      createdAt: DateTime.utc(2026, 8, 22),
      updatedAt: DateTime.utc(2026, 8, 22),
    );
    final restored = IdempotentEffectRecord.fromJson(record.toJson());
    expect(restored.idempotencyKey, 'idem-1');
    expect(restored.state, IdempotentEffectState.pending);
  });
}
