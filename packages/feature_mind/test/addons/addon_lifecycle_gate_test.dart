import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/addons/addon_lifecycle_gate.dart';
import 'package:feature_mind/src/agent_chat/data/repositories/chat_entity_graph_session.dart';
import 'package:feature_mind/src/agent_chat/domain/services/confirmation_token_store.dart';
import 'package:feature_mind/src/agent_chat/domain/services/lifetrack_confirmation_token_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('revoke clears ephemeral graph and invalidates tokens', () async {
    final tokens = LifeTrackConfirmationTokenService(
      store: InMemoryConfirmationTokenStore(),
    );
    final graphSession = ChatEntityGraphSession();
    final gate = AddonLifecycleGate(
      confirmationTokens: tokens,
      graphSession: graphSession,
    );

    graphSession.bindConversation('chat-1');
    await graphSession.ingest('Niva claim ABC123');
    final token = await tokens.issue(
      destinationTool: 'record_lifetrack_facts',
      payload: {
        'title': 'Claim',
        'template_id': 'insurance_claim_v1',
        'facts': {'Claim ID': '1'},
      },
    );

    gate.onEligibilityChanged(
      const AddonEligibility(enabled: false),
    );

    graphSession.bindConversation('chat-1');
    expect((await graphSession.ensureLoaded()).nodes, isEmpty);
    expect(
      await tokens.validateAndConsume(
        token: token,
        destinationTool: 'record_lifetrack_facts',
        payload: {
          'title': 'Claim',
          'template_id': 'insurance_claim_v1',
          'facts': {'Claim ID': '1'},
        },
      ),
      isNotNull,
    );
  });
}
