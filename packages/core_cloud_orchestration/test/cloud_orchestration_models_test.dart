import 'package:core_cloud_orchestration/core_cloud_orchestration.dart';
import 'package:core_media_routing/core_media_routing.dart';
import 'package:core_pairing/core_pairing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 14, 8);
  const policy = AiroCloudOrchestrationPolicy();

  group('AiroCloudOrchestrationPolicy', () {
    test('accepts scoped command and state coordination', () {
      final decision = policy.evaluate(
        manifest: _manifest(),
        request: _request(now),
        now: now,
      );

      expect(decision.accepted, isTrue);
      expect(decision.toDiagnosticMap(), {
        'requestId': 'request-1',
        'action': 'allow',
        'codes': ['accepted'],
      });
    });

    test('falls back locally when cloud is disabled or local-only', () {
      final disabled = policy.evaluate(
        manifest: _manifest(mode: AiroCloudOrchestrationMode.disabled),
        request: _request(now),
        now: now,
      );
      final localOnly = policy.evaluate(
        manifest: _manifest(mode: AiroCloudOrchestrationMode.localOnly),
        request: _request(now),
        now: now,
      );

      expect(
        disabled.action,
        AiroCloudOrchestrationDecisionAction.localFallback,
      );
      expect(disabled.codes, [AiroCloudOrchestrationCode.cloudDisabled]);
      expect(
        localOnly.action,
        AiroCloudOrchestrationDecisionAction.localFallback,
      );
      expect(localOnly.codes, [AiroCloudOrchestrationCode.localOnlyMode]);
    });

    test('denies media proxy attempts and provider proxy opt-in', () {
      final proxyRequest = policy.evaluate(
        manifest: _manifest(),
        request: _request(now, proxiesMedia: true),
        now: now,
      );
      final proxyManifest = policy.evaluate(
        manifest: _manifest(mediaProxyAllowed: true),
        request: _request(now),
        now: now,
      );

      expect(proxyRequest.action, AiroCloudOrchestrationDecisionAction.deny);
      expect(proxyRequest.codes, [
        AiroCloudOrchestrationCode.mediaProxyForbidden,
      ]);
      expect(proxyManifest.action, AiroCloudOrchestrationDecisionAction.deny);
      expect(proxyManifest.codes, [
        AiroCloudOrchestrationCode.mediaProxyForbidden,
      ]);
    });

    test('denies revoked, untrusted, missing-scope, and expired actors', () {
      final decision = policy.evaluate(
        manifest: _manifest(
          requiredTrustLevel: AiroTrustedDeviceTrustLevel.owner,
        ),
        request: _request(
          now,
          actorRevoked: true,
          actorTrustLevel: AiroTrustedDeviceTrustLevel.restricted,
          grantedScopes: const {},
          expiresAt: now.subtract(const Duration(seconds: 1)),
        ),
        now: now,
      );

      expect(decision.action, AiroCloudOrchestrationDecisionAction.deny);
      expect(decision.codes, [
        AiroCloudOrchestrationCode.revokedActor,
        AiroCloudOrchestrationCode.untrustedActor,
        AiroCloudOrchestrationCode.missingScope,
        AiroCloudOrchestrationCode.expiredRequest,
      ]);
    });

    test('denies oversized, over-retained, stale, and duplicate requests', () {
      final decision = policy.evaluate(
        manifest: _manifest(maxPayloadBytes: 10),
        request: _request(
          now,
          payloadBytes: 11,
          requestedRetention: const Duration(minutes: 6),
          baseRevision: 1,
          currentRevision: 2,
        ),
        now: now,
        acceptedCommandIds: {AiroCloudStableValue.stable('command-1')},
      );

      expect(decision.action, AiroCloudOrchestrationDecisionAction.deny);
      expect(decision.codes, [
        AiroCloudOrchestrationCode.payloadTooLarge,
        AiroCloudOrchestrationCode.retentionTooLong,
        AiroCloudOrchestrationCode.staleRevision,
        AiroCloudOrchestrationCode.duplicateCommand,
      ]);
    });

    test('falls back only when no hard denial is present', () {
      final decision = policy.evaluate(
        manifest: _manifest(mode: AiroCloudOrchestrationMode.localOnly),
        request: _request(now, proxiesMedia: true),
        now: now,
      );

      expect(decision.action, AiroCloudOrchestrationDecisionAction.deny);
      expect(decision.codes, [
        AiroCloudOrchestrationCode.localOnlyMode,
        AiroCloudOrchestrationCode.mediaProxyForbidden,
      ]);
    });
  });

  group('AiroCloudStableValue', () {
    test('rejects raw private data', () {
      expect(
        AiroCloudStableValue.validate('https://example.test/playlist.m3u'),
        AiroCloudStableValueRejectionCode.urlValue,
      );
      expect(
        AiroCloudStableValue.validate('/Users/dev/media/movie.mp4'),
        AiroCloudStableValueRejectionCode.localPathValue,
      );
      expect(
        AiroCloudStableValue.validate('receiver-192.168.1.20'),
        AiroCloudStableValueRejectionCode.localIpValue,
      );
      expect(
        AiroCloudStableValue.validate('Bearer abc123'),
        AiroCloudStableValueRejectionCode.credentialLikeValue,
      );
      expect(
        AiroCloudStableValue.validate('receiver 1'),
        AiroCloudStableValueRejectionCode.invalidStableId,
      );
    });
  });

  group('AiroCloudOrchestrator implementations', () {
    test('no-op coordinator never connects to a provider', () async {
      final orchestrator = AiroNoOpCloudOrchestrator(_manifest());

      final decision = await orchestrator.coordinate(
        request: _request(now),
        now: now,
      );

      expect(decision.action, AiroCloudOrchestrationDecisionAction.noOp);
      expect(decision.codes, [AiroCloudOrchestrationCode.providerUnavailable]);
    });

    test(
      'fake coordinator records accepted requests and blocks duplicates',
      () async {
        final orchestrator = AiroFakeCloudOrchestrator(
          manifest: _manifest(),
          policy: policy,
        );

        final first = await orchestrator.coordinate(
          request: _request(now),
          now: now,
        );
        final duplicate = await orchestrator.coordinate(
          request: _request(now, requestId: 'request-2'),
          now: now,
        );

        expect(first.accepted, isTrue);
        expect(duplicate.action, AiroCloudOrchestrationDecisionAction.deny);
        expect(duplicate.codes, [AiroCloudOrchestrationCode.duplicateCommand]);
        expect(orchestrator.acceptedRequests, hasLength(1));
        expect(
          orchestrator.acceptedCommandIds,
          contains(AiroCloudStableValue.stable('command-1')),
        );
      },
    );
  });
}

AiroCloudOrchestrationManifest _manifest({
  AiroCloudOrchestrationMode mode = AiroCloudOrchestrationMode.commandAndState,
  AiroTrustedDeviceTrustLevel requiredTrustLevel =
      AiroTrustedDeviceTrustLevel.paired,
  int maxPayloadBytes = 1024,
  bool mediaProxyAllowed = false,
}) {
  return AiroCloudOrchestrationManifest(
    manifestId: AiroCloudStableValue.stable('manifest-1'),
    mode: mode,
    enabledServices: const {
      AiroCloudOrchestrationService.deviceRegistry,
      AiroCloudOrchestrationService.presence,
      AiroCloudOrchestrationService.commandRouting,
      AiroCloudOrchestrationService.stateDistribution,
      AiroCloudOrchestrationService.playbackTicketBroker,
      AiroCloudOrchestrationService.notificationWake,
      AiroCloudOrchestrationService.recoveryCoordinator,
      AiroCloudOrchestrationService.progressSync,
    },
    requiredTrustLevel: requiredTrustLevel,
    maxPayloadBytes: maxPayloadBytes,
    maxRetention: const Duration(minutes: 5),
    mediaProxyAllowed: mediaProxyAllowed,
  );
}

AiroCloudOrchestrationRequest _request(
  DateTime now, {
  String requestId = 'request-1',
  bool proxiesMedia = false,
  bool actorRevoked = false,
  AiroTrustedDeviceTrustLevel actorTrustLevel =
      AiroTrustedDeviceTrustLevel.paired,
  Set<AiroPairingScope> grantedScopes = const {
    AiroPairingScope.playbackControl,
  },
  DateTime? expiresAt,
  int payloadBytes = 512,
  Duration requestedRetention = const Duration(minutes: 1),
  int? baseRevision,
  int? currentRevision,
}) {
  return AiroCloudOrchestrationRequest(
    requestId: AiroCloudStableValue.stable(requestId),
    service: AiroCloudOrchestrationService.commandRouting,
    actorNodeId: AiroCloudStableValue.stable('actor-node-1'),
    targetNodeId: AiroCloudStableValue.stable('target-node-1'),
    actorTrustLevel: actorTrustLevel,
    grantedScopes: grantedScopes,
    requiredScope: AiroPairingScope.playbackControl,
    sessionId: AiroCloudStableValue.stable('session-1'),
    commandId: AiroCloudStableValue.stable('command-1'),
    routeKind: AiroMediaRouteKind.cloudCommandOnly,
    proxiesMedia: proxiesMedia,
    payloadBytes: payloadBytes,
    requestedRetention: requestedRetention,
    baseRevision: baseRevision,
    currentRevision: currentRevision,
    issuedAt: now,
    expiresAt: expiresAt ?? now.add(const Duration(minutes: 1)),
    actorRevoked: actorRevoked,
  );
}
