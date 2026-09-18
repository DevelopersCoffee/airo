import 'package:equatable/equatable.dart';

enum PushWakeOutcome {
  send('send'),
  visibleNotification('visible_notification'),
  localReconnect('local_reconnect'),
  userActionRequired('user_action_required'),
  deny('deny'),
  noOp('no_op');

  const PushWakeOutcome(this.stableId);
  final String stableId;

  static PushWakeOutcome parse(String value) {
    return PushWakeOutcome.values.firstWhere(
      (e) => e.stableId == value,
      orElse: () => PushWakeOutcome.noOp,
    );
  }
}

class PushWakeRequest extends Equatable {
  const PushWakeRequest({
    required this.requestId,
    required this.targetDeviceId,
    required this.isTvProfile,
    required this.isLocalOnlyMode,
    required this.isExpired,
    required this.isHomeNodeAvailable,
    required this.hasPushProviderAvailable,
    this.payloadSizeBytes = 0,
    this.maxPayloadSizeBytes = 4096,
  });

  final String requestId;
  final String targetDeviceId;
  final bool isTvProfile;
  final bool isLocalOnlyMode;
  final bool isExpired;
  final bool isHomeNodeAvailable;
  final bool hasPushProviderAvailable;
  final int payloadSizeBytes;
  final int maxPayloadSizeBytes;

  @override
  List<Object?> get props => [
        requestId,
        targetDeviceId,
        isTvProfile,
        isLocalOnlyMode,
        isExpired,
        isHomeNodeAvailable,
        hasPushProviderAvailable,
        payloadSizeBytes,
        maxPayloadSizeBytes,
      ];
}

class PushWakePolicyEngine {
  const PushWakePolicyEngine();

  PushWakeOutcome evaluate(PushWakeRequest request) {
    if (request.requestId.trim().isEmpty || request.targetDeviceId.trim().isEmpty) {
      return PushWakeOutcome.deny;
    }

    if (request.isExpired || request.payloadSizeBytes > request.maxPayloadSizeBytes) {
      return PushWakeOutcome.deny;
    }

    // Local-only privacy rule: hard block cloud push wake
    if (request.isLocalOnlyMode) {
      if (request.isHomeNodeAvailable) {
        return PushWakeOutcome.localReconnect;
      }
      return PushWakeOutcome.deny;
    }

    // Home-node available -> prefer local reconnect
    if (request.isHomeNodeAvailable) {
      return PushWakeOutcome.localReconnect;
    }

    // TV profiles (Android TV, Fire TV) must not assume silent push wake
    if (request.isTvProfile) {
      if (request.hasPushProviderAvailable) {
        return PushWakeOutcome.visibleNotification;
      }
      return PushWakeOutcome.userActionRequired;
    }

    // Mobile / Desktop profiles with push provider
    if (request.hasPushProviderAvailable) {
      return PushWakeOutcome.send;
    }

    return PushWakeOutcome.userActionRequired;
  }
}
