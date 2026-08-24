import 'dart:async';

import 'package:core_ai/core_ai.dart';

import '../agent_chat/data/connectors/life_track_confirmation_tokens.dart';
import '../agent_chat/data/repositories/chat_entity_graph_session.dart';
import '../agent_chat/domain/services/addon_permission_epoch.dart';
import '../agent_chat/domain/services/lifetrack_confirmation_token_service.dart';

/// Invalidates ephemeral graph and confirmation state on revoke/disable/quarantine.
class AddonLifecycleGate {
  AddonLifecycleGate({
    LifeTrackConfirmationTokenService? confirmationTokens,
    ChatEntityGraphSession? graphSession,
  }) : _confirmationTokens = confirmationTokens,
       _graphSession = graphSession;

  final LifeTrackConfirmationTokenService? _confirmationTokens;
  final ChatEntityGraphSession? _graphSession;

  void onEligibilityChanged(AddonEligibility eligibility) {
    if (eligibility.isEligible) return;
    AddonPermissionEpoch.instance.bump();
    unawaited(
      (_confirmationTokens ?? sharedLifeTrackConfirmationTokens).invalidateAll(),
    );
    (_graphSession ?? chatEntityGraphSession).invalidateAllEphemeralGraphs();
  }
}
