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

  test('expiry boundary rejects redemption after ttl', () async {
    final now = DateTime.utc(2026, 8, 22, 12, 0);
    final sharedStore = InMemoryConfirmationTokenStore();
    final issuer = LifeTrackConfirmationTokenService(
      store: sharedStore,
      now: () => now,
      ttl: const Duration(minutes: 15),
    );
    final edgeToken = await issuer.issue(
      destinationTool: 'record_lifetrack_facts',
      payload: payload,
    );
    final redeemer = LifeTrackConfirmationTokenService(
      store: sharedStore,
      now: () => now.add(const Duration(minutes: 15, seconds: 1)),
      ttl: const Duration(minutes: 15),
    );
    expect(
      await redeemer.validateAndConsume(
        token: edgeToken,
        destinationTool: 'record_lifetrack_facts',
        payload: payload,
      ),
      'confirmation_expired',
    );
  });

  test('concurrent redemption allows only one success', () async {
    final token = await service.issue(
      destinationTool: 'record_lifetrack_facts',
      payload: payload,
    );
    final results = await Future.wait([
      service.validateAndConsume(
        token: token,
        destinationTool: 'record_lifetrack_facts',
        payload: payload,
      ),
      service.validateAndConsume(
        token: token,
        destinationTool: 'record_lifetrack_facts',
        payload: payload,
      ),
    ]);
    expect(results.where((code) => code == null).length, 1);
    expect(
      results.where((code) => code == 'confirmation_consumed').length,
      1,
    );
  });
}
