import 'package:core_protocol/core_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo secure transport contract', () {
    final now = DateTime.utc(2026, 7, 14, 10);
    final endpoint = _endpoint();
    final policy = AiroSecureTransportPolicy(
      requiredFrameKinds: const {
        AiroSecureTransportFrameKind.command,
        AiroSecureTransportFrameKind.playbackState,
        AiroSecureTransportFrameKind.routeHealth,
      },
    );

    test('accepts paired WSS handshake and command frame', () {
      final handshake = policy.validateHandshake(
        offer: _offer(endpoint: endpoint, now: now),
        now: now,
      );
      final frame = policy.validateFrame(
        endpoint: endpoint,
        frame: _frame(now: now),
        now: now,
      );

      expect(handshake.accepted, isTrue);
      expect(frame.accepted, isTrue);
      expect(
        frame.toDiagnosticMap(),
        containsPair('codes', [
          AiroSecureTransportBlockerCode.accepted.stableId,
        ]),
      );
    });

    test('rejects insecure missing proof untrusted and expired handshakes', () {
      final insecureEndpoint = _endpoint(
        scheme: AiroSecureTransportScheme.ws,
        authModes: const {AiroSecureTransportAuthMode.deviceSignature},
      );
      final result = policy.validateHandshake(
        offer: _offer(
          endpoint: insecureEndpoint,
          now: now,
          authMode: AiroSecureTransportAuthMode.pairingProof,
          proofPresent: false,
          peerTrustState: AiroNodeTrustState.revoked,
          expiresAt: now.subtract(const Duration(seconds: 1)),
          credentialExpiresAt: now,
        ),
        now: now,
      );

      expect(
        result.codes,
        contains(AiroSecureTransportBlockerCode.insecureScheme),
      );
      expect(
        result.codes,
        contains(AiroSecureTransportBlockerCode.unsupportedAuthMode),
      );
      expect(
        result.codes,
        contains(AiroSecureTransportBlockerCode.missingAuthProof),
      );
      expect(
        result.codes,
        contains(AiroSecureTransportBlockerCode.expiredHandshake),
      );
      expect(
        result.codes,
        contains(AiroSecureTransportBlockerCode.expiredCredential),
      );
      expect(
        result.codes,
        contains(AiroSecureTransportBlockerCode.untrustedPeer),
      );
    });

    test('rejects unsupported handshake frame families', () {
      final result = policy.validateHandshake(
        offer: _offer(
          endpoint: endpoint,
          now: now,
          requestedFrameKinds: const {
            AiroSecureTransportFrameKind.command,
            AiroSecureTransportFrameKind.snapshotResponse,
          },
        ),
        now: now,
      );

      expect(
        result.codes,
        contains(AiroSecureTransportBlockerCode.unsupportedFrameKind),
      );
    });

    test('rejects frame replay size time proof and diagnostic failures', () {
      final result = policy.validateFrame(
        endpoint: endpoint,
        now: now,
        acceptedSequences: const {8},
        frame: _frame(
          now: now,
          kind: AiroSecureTransportFrameKind.epgSync,
          sequence: 8,
          payloadBytes: kAiroSecureTransportDefaultMaxFrameBytes + 1,
          proofPresent: false,
          issuedAt: now.subtract(const Duration(minutes: 2)),
          diagnosticRef: 'https://example.com/raw-diagnostic',
        ),
      );

      expect(
        result.codes,
        contains(AiroSecureTransportBlockerCode.unsupportedFrameKind),
      );
      expect(
        result.codes,
        contains(AiroSecureTransportBlockerCode.replayedFrame),
      );
      expect(
        result.codes,
        contains(AiroSecureTransportBlockerCode.oversizedFrame),
      );
      expect(
        result.codes,
        contains(AiroSecureTransportBlockerCode.missingAuthProof),
      );
      expect(result.codes, contains(AiroSecureTransportBlockerCode.staleFrame));
      expect(
        result.codes,
        contains(AiroSecureTransportBlockerCode.unsafeStableId),
      );
    });

    test('rejects non-positive and future frames', () {
      final result = policy.validateFrame(
        endpoint: endpoint,
        now: now,
        frame: _frame(
          now: now,
          sequence: 0,
          issuedAt: now.add(const Duration(minutes: 2)),
        ),
      );

      expect(
        result.codes,
        contains(AiroSecureTransportBlockerCode.nonPositiveSequence),
      );
      expect(
        result.codes,
        contains(AiroSecureTransportBlockerCode.futureFrame),
      );
    });

    test('stable value rejects raw network and credential material', () {
      expect(
        () =>
            AiroSecureTransportStableValue.stable('https://example.com/socket'),
        throwsArgumentError,
      );
      expect(
        () => AiroSecureTransportStableValue.stable('/Users/me/socket'),
        throwsArgumentError,
      );
      expect(
        () => AiroSecureTransportStableValue.stable('192.168.1.42'),
        throwsArgumentError,
      );
      expect(
        () => AiroSecureTransportStableValue.stable('Basic abc123'),
        throwsArgumentError,
      );
    });

    test('no-op adapter rejects without opening transport', () async {
      final adapter = AiroNoOpSecureTransportAdapter(endpoint);

      final connectResult = await adapter.connect(
        _offer(endpoint: endpoint, now: now),
        now: now,
      );
      final sendResult = await adapter.sendFrame(_frame(now: now), now: now);

      expect(adapter.state, AiroSecureTransportLifecycleState.closed);
      expect(
        connectResult.codes,
        contains(AiroSecureTransportBlockerCode.adapterUnavailable),
      );
      expect(
        sendResult.codes,
        contains(AiroSecureTransportBlockerCode.adapterUnavailable),
      );
    });

    test('fake adapter validates and records accepted frame probes', () async {
      final adapter = AiroFakeSecureTransportAdapter(
        endpoint: endpoint,
        policy: policy,
      );

      final beforeConnect = await adapter.sendFrame(_frame(now: now), now: now);
      final connectResult = await adapter.connect(
        _offer(endpoint: endpoint, now: now),
        now: now,
      );
      final firstSend = await adapter.sendFrame(_frame(now: now), now: now);
      final replaySend = await adapter.sendFrame(_frame(now: now), now: now);

      expect(
        beforeConnect.codes,
        contains(AiroSecureTransportBlockerCode.notConnected),
      );
      expect(connectResult.accepted, isTrue);
      expect(firstSend.accepted, isTrue);
      expect(
        replaySend.codes,
        contains(AiroSecureTransportBlockerCode.replayedFrame),
      );
      expect(adapter.sentFrames, hasLength(1));

      await adapter.close();
      expect(adapter.state, AiroSecureTransportLifecycleState.closed);
    });
  });
}

AiroSecureTransportEndpointDescriptor _endpoint({
  AiroSecureTransportScheme scheme = AiroSecureTransportScheme.wss,
  Set<AiroSecureTransportAuthMode> authModes = const {
    AiroSecureTransportAuthMode.deviceSignature,
    AiroSecureTransportAuthMode.pairingProof,
  },
}) {
  return AiroSecureTransportEndpointDescriptor(
    endpointId: AiroSecureTransportStableValue.stable('receiver-wss-primary'),
    channelKind: AiroSecureTransportChannelKind.localWebSocket,
    scheme: scheme,
    authModes: authModes,
    frameKinds: const {
      AiroSecureTransportFrameKind.command,
      AiroSecureTransportFrameKind.playbackState,
      AiroSecureTransportFrameKind.routeHealth,
      AiroSecureTransportFrameKind.acknowledgement,
      AiroSecureTransportFrameKind.heartbeat,
      AiroSecureTransportFrameKind.snapshotRequest,
    },
  );
}

AiroSecureTransportHandshakeOffer _offer({
  required AiroSecureTransportEndpointDescriptor endpoint,
  required DateTime now,
  AiroSecureTransportAuthMode authMode =
      AiroSecureTransportAuthMode.deviceSignature,
  bool proofPresent = true,
  AiroNodeTrustState peerTrustState = AiroNodeTrustState.paired,
  DateTime? expiresAt,
  DateTime? credentialExpiresAt,
  Set<AiroSecureTransportFrameKind> requestedFrameKinds = const {
    AiroSecureTransportFrameKind.command,
    AiroSecureTransportFrameKind.playbackState,
    AiroSecureTransportFrameKind.routeHealth,
  },
}) {
  return AiroSecureTransportHandshakeOffer(
    endpoint: endpoint,
    peerNodeId: AiroSecureTransportStableValue.stable('phone-controller-1'),
    peerTrustState: peerTrustState,
    authMode: authMode,
    proofPresent: proofPresent,
    issuedAt: now,
    expiresAt: expiresAt ?? now.add(const Duration(minutes: 1)),
    credentialExpiresAt:
        credentialExpiresAt ?? now.add(const Duration(minutes: 5)),
    requestedFrameKinds: requestedFrameKinds,
  );
}

AiroSecureTransportFrameProbe _frame({
  required DateTime now,
  AiroSecureTransportFrameKind kind = AiroSecureTransportFrameKind.command,
  int sequence = 8,
  int payloadBytes = 512,
  bool proofPresent = true,
  DateTime? issuedAt,
  String? diagnosticRef,
}) {
  return AiroSecureTransportFrameProbe(
    frameId: AiroSecureTransportStableValue.stable('frame-$sequence'),
    kind: kind,
    sequence: sequence,
    issuedAt: issuedAt ?? now,
    payloadBytes: payloadBytes,
    proofPresent: proofPresent,
    diagnosticRef: diagnosticRef,
  );
}
