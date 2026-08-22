import 'package:feature_mind/src/agent_chat/domain/services/lifetrack_confirmation_token_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('token is one-use and rejects payload mutation', () {
    final service = LifeTrackConfirmationTokenService(
      now: () => DateTime.utc(2026, 8, 22, 12),
    );
    final payload = {
      'title': 'Niva claim',
      'template_id': 'insurance_claim_v1',
      'facts': {'Claim ID': '9001001'},
    };
    final token = service.issue(
      destinationTool: 'record_lifetrack_facts',
      payload: payload,
    );

    expect(
      service.validateAndConsume(
        token: token,
        destinationTool: 'record_lifetrack_facts',
        payload: payload,
      ),
      isNull,
    );
    expect(
      service.validateAndConsume(
        token: token,
        destinationTool: 'record_lifetrack_facts',
        payload: payload,
      ),
      'confirmation_consumed',
    );

    final token2 = service.issue(
      destinationTool: 'record_lifetrack_facts',
      payload: payload,
    );
    final mutated = {
      'title': 'Niva claim',
      'template_id': 'insurance_claim_v1',
      'facts': {'Claim ID': '9001002'},
    };
    expect(
      service.validateAndConsume(
        token: token2,
        destinationTool: 'record_lifetrack_facts',
        payload: mutated,
      ),
      'confirmation_invalid',
    );
  });

  test('token expires after ttl', () {
    var now = DateTime.utc(2026, 8, 22, 12);
    final service = LifeTrackConfirmationTokenService(
      now: () => now,
      ttl: const Duration(minutes: 1),
    );
    final payload = {
      'title': 'Test',
      'template_id': 'insurance_claim_v1',
      'facts': {'Claim ID': 'A'},
    };
    final token = service.issue(
      destinationTool: 'record_lifetrack_facts',
      payload: payload,
    );
    now = now.add(const Duration(minutes: 2));
    expect(
      service.validateAndConsume(
        token: token,
        destinationTool: 'record_lifetrack_facts',
        payload: payload,
      ),
      'confirmation_expired',
    );
  });
}
