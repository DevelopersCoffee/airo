import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/agent_chat/domain/services/addon_permission_epoch.dart';
import 'package:feature_mind/src/agent_chat/domain/services/confirmation_token_store.dart';
import 'package:feature_mind/src/agent_chat/domain/services/lifetrack_confirmation_token_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LifeTrackConfirmationTokenService service;
  final payload = {
    'title': 'Niva claim',
    'template_id': 'insurance_claim_v1',
    'facts': {'Claim ID': '9001001'},
  };

  setUp(() {
    AddonInvocationEpoch.instance.resetForTesting();
    service = LifeTrackConfirmationTokenService(
      store: InMemoryConfirmationTokenStore(),
    );
  });

  test('equivalent map key ordering yields the same payload hash', () {
    final a = {
      'title': 'Niva claim',
      'template_id': 'insurance_claim_v1',
      'facts': {'Claim ID': '9001001', 'Policy Number': 'P1'},
    };
    final b = {
      'facts': {'Policy Number': 'P1', 'Claim ID': '9001001'},
      'template_id': 'insurance_claim_v1',
      'title': 'Niva claim',
    };
    expect(
      service.confirmationHashFor(
        destinationTool: 'record_lifetrack_facts',
        payload: a,
      ),
      service.confirmationHashFor(
        destinationTool: 'record_lifetrack_facts',
        payload: b,
      ),
    );
  });

  test('destination tool mismatch rejects redemption', () async {
    final token = await service.issue(
      destinationTool: 'record_lifetrack_facts',
      payload: payload,
    );
    expect(
      await service.validateAndConsume(
        token: token,
        destinationTool: 'other_tool',
        payload: payload,
      ),
      'confirmation_invalid',
    );
  });

  test('replay after successful redemption fails', () async {
    final token = await service.issue(
      destinationTool: 'record_lifetrack_facts',
      payload: payload,
    );
    expect(
      await service.validateAndConsume(
        token: token,
        destinationTool: 'record_lifetrack_facts',
        payload: payload,
      ),
      isNull,
    );
    expect(
      await service.validateAndConsume(
        token: token,
        destinationTool: 'record_lifetrack_facts',
        payload: payload,
      ),
      'confirmation_consumed',
    );
  });

  test('nested facts mutation invalidates token', () async {
    final token = await service.issue(
      destinationTool: 'record_lifetrack_facts',
      payload: payload,
    );
    final mutated = {
      'title': 'Niva claim',
      'template_id': 'insurance_claim_v1',
      'facts': {'Claim ID': '9001002'},
    };
    expect(
      await service.validateAndConsume(
        token: token,
        destinationTool: 'record_lifetrack_facts',
        payload: mutated,
      ),
      'confirmation_invalid',
    );
  });

  test('permission epoch bump after issue rejects redemption', () async {
    final token = await service.issue(
      destinationTool: 'record_lifetrack_facts',
      payload: payload,
    );
    AddonPermissionEpoch.instance.bump();
    expect(
      await service.validateAndConsume(
        token: token,
        destinationTool: 'record_lifetrack_facts',
        payload: payload,
      ),
      'confirmation_permission_changed',
    );
  });

  test('invocation epoch bump after issue rejects redemption', () async {
    final token = await service.issue(
      destinationTool: 'record_lifetrack_facts',
      payload: payload,
    );
    AddonInvocationEpoch.instance.bump();
    expect(
      await service.validateAndConsume(
        token: token,
        destinationTool: 'record_lifetrack_facts',
        payload: payload,
      ),
      AddonInvocationEpoch.cancelledCode,
    );
  });
}
