import 'package:equatable/equatable.dart';

import 'connected_node_models.dart';

const String kAiroSecureTransportSchemaVersion = '1.0.0';
const int kAiroSecureTransportProtocolVersion = 1;
const int kAiroSecureTransportDefaultMaxFrameBytes = 64 * 1024;
const Duration kAiroSecureTransportDefaultClockSkew = Duration(seconds: 30);
const Duration kAiroSecureTransportDefaultHeartbeat = Duration(seconds: 15);
const Duration kAiroSecureTransportDefaultReconnectBaseDelay = Duration(
  milliseconds: 250,
);

enum AiroSecureTransportChannelKind {
  localWebSocket('local_websocket'),
  cloudWebSocket('cloud_websocket'),
  futureHttp3('future_http3'),
  inMemoryTest('in_memory_test');

  const AiroSecureTransportChannelKind(this.stableId);

  final String stableId;
}

enum AiroSecureTransportScheme {
  wss('wss'),
  httpsHttp3('https_http3'),
  ws('ws'),
  inMemory('in_memory');

  const AiroSecureTransportScheme(this.stableId);

  final String stableId;
}

enum AiroSecureTransportAuthMode {
  pairingProof('pairing_proof'),
  deviceSignature('device_signature'),
  sessionTicket('session_ticket'),
  cloudCredential('cloud_credential'),
  testHarness('test_harness');

  const AiroSecureTransportAuthMode(this.stableId);

  final String stableId;
}

enum AiroSecureTransportFrameKind {
  command('command'),
  playbackState('playback_state'),
  routeHealth('route_health'),
  epgSync('epg_sync'),
  acknowledgement('acknowledgement'),
  heartbeat('heartbeat'),
  snapshotRequest('snapshot_request'),
  snapshotResponse('snapshot_response');

  const AiroSecureTransportFrameKind(this.stableId);

  final String stableId;
}

enum AiroSecureTransportLifecycleState {
  idle('idle'),
  connecting('connecting'),
  open('open'),
  degraded('degraded'),
  reconnecting('reconnecting'),
  refreshingCredential('refreshing_credential'),
  suspended('suspended'),
  closed('closed'),
  failed('failed');

  const AiroSecureTransportLifecycleState(this.stableId);

  final String stableId;

  bool get allowsFrameSend =>
      this == open || this == degraded || this == reconnecting;
}

enum AiroSecureTransportBlockerCode {
  accepted('accepted'),
  schemaMismatch('schema_mismatch'),
  protocolTooOld('protocol_too_old'),
  protocolTooNew('protocol_too_new'),
  insecureScheme('insecure_scheme'),
  unsupportedAuthMode('unsupported_auth_mode'),
  missingAuthProof('missing_auth_proof'),
  expiredHandshake('expired_handshake'),
  expiredCredential('expired_credential'),
  untrustedPeer('untrusted_peer'),
  unsupportedFrameKind('unsupported_frame_kind'),
  oversizedFrame('oversized_frame'),
  nonPositiveSequence('non_positive_sequence'),
  replayedFrame('replayed_frame'),
  staleFrame('stale_frame'),
  futureFrame('future_frame'),
  unsafeStableId('unsafe_stable_id'),
  adapterUnavailable('adapter_unavailable'),
  notConnected('not_connected');

  const AiroSecureTransportBlockerCode(this.stableId);

  final String stableId;
}

enum AiroSecureTransportStableValueRejectionCode {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value'),
  invalidStableId('invalid_stable_id');

  const AiroSecureTransportStableValueRejectionCode(this.stableId);

  final String stableId;
}

class AiroSecureTransportStableValue extends Equatable {
  const AiroSecureTransportStableValue._(this.value);

  factory AiroSecureTransportStableValue.stable(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return AiroSecureTransportStableValue._(value.trim());
  }

  final String value;

  static AiroSecureTransportStableValueRejectionCode? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return AiroSecureTransportStableValueRejectionCode.empty;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroSecureTransportStableValueRejectionCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroSecureTransportStableValueRejectionCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroSecureTransportStableValueRejectionCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroSecureTransportStableValueRejectionCode.credentialLikeValue;
    }
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_.-]*$').hasMatch(trimmed)) {
      return AiroSecureTransportStableValueRejectionCode.invalidStableId;
    }
    return null;
  }

  @override
  String toString() => 'AiroSecureTransportStableValue(redacted)';

  @override
  List<Object?> get props => [value];
}

class AiroSecureTransportEndpointDescriptor extends Equatable {
  AiroSecureTransportEndpointDescriptor({
    required this.endpointId,
    required this.channelKind,
    required this.scheme,
    required Set<AiroSecureTransportAuthMode> authModes,
    required Set<AiroSecureTransportFrameKind> frameKinds,
    this.requiresTrustedPeer = true,
    this.maxFrameBytes = kAiroSecureTransportDefaultMaxFrameBytes,
    this.heartbeatInterval = kAiroSecureTransportDefaultHeartbeat,
    this.reconnectBaseDelay = kAiroSecureTransportDefaultReconnectBaseDelay,
    this.schemaVersion = kAiroSecureTransportSchemaVersion,
    this.protocolVersion = kAiroSecureTransportProtocolVersion,
  }) : authModes = Set.unmodifiable(authModes),
       frameKinds = Set.unmodifiable(frameKinds);

  final String schemaVersion;
  final int protocolVersion;
  final AiroSecureTransportStableValue endpointId;
  final AiroSecureTransportChannelKind channelKind;
  final AiroSecureTransportScheme scheme;
  final Set<AiroSecureTransportAuthMode> authModes;
  final Set<AiroSecureTransportFrameKind> frameKinds;
  final bool requiresTrustedPeer;
  final int maxFrameBytes;
  final Duration heartbeatInterval;
  final Duration reconnectBaseDelay;

  bool supports(AiroSecureTransportFrameKind frameKind) {
    return frameKinds.contains(frameKind);
  }

  @override
  String toString() {
    return 'AiroSecureTransportEndpointDescriptor('
        'endpointId: ${endpointId.value}, '
        'channelKind: ${channelKind.stableId}, '
        'scheme: ${scheme.stableId}, '
        'authModes: ${authModes.map((mode) => mode.stableId).join(',')}, '
        'frameKinds: ${frameKinds.map((kind) => kind.stableId).join(',')}, '
        'requiresTrustedPeer: $requiresTrustedPeer'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    endpointId,
    channelKind,
    scheme,
    authModes,
    frameKinds,
    requiresTrustedPeer,
    maxFrameBytes,
    heartbeatInterval,
    reconnectBaseDelay,
  ];
}

class AiroSecureTransportHandshakeOffer extends Equatable {
  AiroSecureTransportHandshakeOffer({
    required this.endpoint,
    required this.peerNodeId,
    required this.peerTrustState,
    required this.authMode,
    required this.proofPresent,
    required this.issuedAt,
    required this.expiresAt,
    required Set<AiroSecureTransportFrameKind> requestedFrameKinds,
    this.credentialExpiresAt,
    this.schemaVersion = kAiroSecureTransportSchemaVersion,
    this.protocolVersion = kAiroSecureTransportProtocolVersion,
  }) : requestedFrameKinds = Set.unmodifiable(requestedFrameKinds);

  final String schemaVersion;
  final int protocolVersion;
  final AiroSecureTransportEndpointDescriptor endpoint;
  final AiroSecureTransportStableValue peerNodeId;
  final AiroNodeTrustState peerTrustState;
  final AiroSecureTransportAuthMode authMode;
  final bool proofPresent;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime? credentialExpiresAt;
  final Set<AiroSecureTransportFrameKind> requestedFrameKinds;

  @override
  String toString() {
    return 'AiroSecureTransportHandshakeOffer('
        'endpointId: ${endpoint.endpointId.value}, '
        'peerNodeId: ${peerNodeId.value}, '
        'peerTrustState: ${peerTrustState.stableId}, '
        'authMode: ${authMode.stableId}, '
        'proofPresent: $proofPresent, '
        'issuedAt: $issuedAt, '
        'expiresAt: $expiresAt'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    endpoint,
    peerNodeId,
    peerTrustState,
    authMode,
    proofPresent,
    issuedAt,
    expiresAt,
    credentialExpiresAt,
    requestedFrameKinds,
  ];
}

class AiroSecureTransportFrameProbe extends Equatable {
  const AiroSecureTransportFrameProbe({
    required this.frameId,
    required this.kind,
    required this.sequence,
    required this.issuedAt,
    required this.payloadBytes,
    this.proofPresent = true,
    this.diagnosticRef,
    this.schemaVersion = kAiroSecureTransportSchemaVersion,
    this.protocolVersion = kAiroSecureTransportProtocolVersion,
  });

  final String schemaVersion;
  final int protocolVersion;
  final AiroSecureTransportStableValue frameId;
  final AiroSecureTransportFrameKind kind;
  final int sequence;
  final DateTime issuedAt;
  final int payloadBytes;
  final bool proofPresent;
  final String? diagnosticRef;

  Map<String, Object?> toDiagnosticMap() {
    return {
      'schemaVersion': schemaVersion,
      'protocolVersion': protocolVersion,
      'frameId': frameId.value,
      'kind': kind.stableId,
      'sequence': sequence,
      'payloadBytes': payloadBytes,
      'proofPresent': proofPresent,
      'hasDiagnosticRef': diagnosticRef != null,
    };
  }

  @override
  String toString() {
    return 'AiroSecureTransportFrameProbe('
        'frameId: ${frameId.value}, '
        'kind: ${kind.stableId}, '
        'sequence: $sequence, '
        'payloadBytes: $payloadBytes, '
        'hasDiagnosticRef: ${diagnosticRef != null}'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    frameId,
    kind,
    sequence,
    issuedAt,
    payloadBytes,
    proofPresent,
    diagnosticRef,
  ];
}

class AiroSecureTransportValidationResult extends Equatable {
  AiroSecureTransportValidationResult({
    required this.endpointId,
    required Iterable<AiroSecureTransportBlockerCode> codes,
    this.peerNodeId,
    this.frameId,
    this.sequence,
  }) : codes = List.unmodifiable(codes);

  final AiroSecureTransportStableValue endpointId;
  final AiroSecureTransportStableValue? peerNodeId;
  final AiroSecureTransportStableValue? frameId;
  final int? sequence;
  final List<AiroSecureTransportBlockerCode> codes;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == AiroSecureTransportBlockerCode.accepted;

  Map<String, Object?> toDiagnosticMap() {
    return {
      'endpointId': endpointId.value,
      'peerNodeId': peerNodeId?.value,
      'frameId': frameId?.value,
      'sequence': sequence,
      'accepted': accepted,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [endpointId, peerNodeId, frameId, sequence, codes];
}

class AiroSecureTransportPolicy extends Equatable {
  AiroSecureTransportPolicy({
    Set<AiroSecureTransportFrameKind> requiredFrameKinds = const {},
    Set<AiroNodeTrustState> trustedPeerStates = const {
      AiroNodeTrustState.paired,
      AiroNodeTrustState.trusted,
    },
    this.acceptedSchemaVersion = kAiroSecureTransportSchemaVersion,
    this.minProtocolVersion = kAiroSecureTransportProtocolVersion,
    this.maxProtocolVersion = kAiroSecureTransportProtocolVersion,
    this.maxFrameBytes = kAiroSecureTransportDefaultMaxFrameBytes,
    this.maxClockSkew = kAiroSecureTransportDefaultClockSkew,
  }) : requiredFrameKinds = Set.unmodifiable(requiredFrameKinds),
       trustedPeerStates = Set.unmodifiable(trustedPeerStates);

  final String acceptedSchemaVersion;
  final int minProtocolVersion;
  final int maxProtocolVersion;
  final int maxFrameBytes;
  final Duration maxClockSkew;
  final Set<AiroSecureTransportFrameKind> requiredFrameKinds;
  final Set<AiroNodeTrustState> trustedPeerStates;

  AiroSecureTransportValidationResult validateHandshake({
    required AiroSecureTransportHandshakeOffer offer,
    required DateTime now,
  }) {
    final codes = <AiroSecureTransportBlockerCode>[];
    final endpoint = offer.endpoint;
    _addVersionCodes(
      schemaVersion: offer.schemaVersion,
      protocolVersion: offer.protocolVersion,
      codes: codes,
    );
    _addVersionCodes(
      schemaVersion: endpoint.schemaVersion,
      protocolVersion: endpoint.protocolVersion,
      codes: codes,
    );

    if (!_schemeMatchesChannel(endpoint.channelKind, endpoint.scheme)) {
      codes.add(AiroSecureTransportBlockerCode.insecureScheme);
    }
    if (!endpoint.authModes.contains(offer.authMode)) {
      codes.add(AiroSecureTransportBlockerCode.unsupportedAuthMode);
    }
    if (!offer.proofPresent) {
      codes.add(AiroSecureTransportBlockerCode.missingAuthProof);
    }
    if (!now.isBefore(offer.expiresAt)) {
      codes.add(AiroSecureTransportBlockerCode.expiredHandshake);
    }
    final credentialExpiresAt = offer.credentialExpiresAt;
    if (credentialExpiresAt != null && !now.isBefore(credentialExpiresAt)) {
      codes.add(AiroSecureTransportBlockerCode.expiredCredential);
    }
    if (endpoint.requiresTrustedPeer &&
        !trustedPeerStates.contains(offer.peerTrustState)) {
      codes.add(AiroSecureTransportBlockerCode.untrustedPeer);
    }
    if (!endpoint.frameKinds.containsAll(requiredFrameKinds) ||
        !offer.requestedFrameKinds.containsAll(requiredFrameKinds) ||
        !endpoint.frameKinds.containsAll(offer.requestedFrameKinds)) {
      codes.add(AiroSecureTransportBlockerCode.unsupportedFrameKind);
    }

    return AiroSecureTransportValidationResult(
      endpointId: endpoint.endpointId,
      peerNodeId: offer.peerNodeId,
      codes: codes.isEmpty
          ? const [AiroSecureTransportBlockerCode.accepted]
          : codes,
    );
  }

  AiroSecureTransportValidationResult validateFrame({
    required AiroSecureTransportEndpointDescriptor endpoint,
    required AiroSecureTransportFrameProbe frame,
    required DateTime now,
    Set<int> acceptedSequences = const {},
  }) {
    final codes = <AiroSecureTransportBlockerCode>[];
    _addVersionCodes(
      schemaVersion: frame.schemaVersion,
      protocolVersion: frame.protocolVersion,
      codes: codes,
    );
    _addVersionCodes(
      schemaVersion: endpoint.schemaVersion,
      protocolVersion: endpoint.protocolVersion,
      codes: codes,
    );

    if (!endpoint.supports(frame.kind)) {
      codes.add(AiroSecureTransportBlockerCode.unsupportedFrameKind);
    }
    if (frame.sequence <= 0) {
      codes.add(AiroSecureTransportBlockerCode.nonPositiveSequence);
    }
    if (acceptedSequences.contains(frame.sequence)) {
      codes.add(AiroSecureTransportBlockerCode.replayedFrame);
    }
    if (frame.payloadBytes > maxFrameBytes ||
        frame.payloadBytes > endpoint.maxFrameBytes) {
      codes.add(AiroSecureTransportBlockerCode.oversizedFrame);
    }
    if (!frame.proofPresent &&
        frame.kind != AiroSecureTransportFrameKind.heartbeat) {
      codes.add(AiroSecureTransportBlockerCode.missingAuthProof);
    }
    if (frame.issuedAt.isBefore(now.subtract(maxClockSkew))) {
      codes.add(AiroSecureTransportBlockerCode.staleFrame);
    }
    if (frame.issuedAt.isAfter(now.add(maxClockSkew))) {
      codes.add(AiroSecureTransportBlockerCode.futureFrame);
    }
    final diagnosticRef = frame.diagnosticRef;
    if (diagnosticRef != null &&
        AiroSecureTransportStableValue.validate(diagnosticRef) != null) {
      codes.add(AiroSecureTransportBlockerCode.unsafeStableId);
    }

    return AiroSecureTransportValidationResult(
      endpointId: endpoint.endpointId,
      frameId: frame.frameId,
      sequence: frame.sequence,
      codes: codes.isEmpty
          ? const [AiroSecureTransportBlockerCode.accepted]
          : codes,
    );
  }

  void _addVersionCodes({
    required String schemaVersion,
    required int protocolVersion,
    required List<AiroSecureTransportBlockerCode> codes,
  }) {
    if (schemaVersion != acceptedSchemaVersion) {
      codes.add(AiroSecureTransportBlockerCode.schemaMismatch);
    }
    if (protocolVersion < minProtocolVersion) {
      codes.add(AiroSecureTransportBlockerCode.protocolTooOld);
    }
    if (protocolVersion > maxProtocolVersion) {
      codes.add(AiroSecureTransportBlockerCode.protocolTooNew);
    }
  }

  bool _schemeMatchesChannel(
    AiroSecureTransportChannelKind channelKind,
    AiroSecureTransportScheme scheme,
  ) {
    switch (channelKind) {
      case AiroSecureTransportChannelKind.localWebSocket:
      case AiroSecureTransportChannelKind.cloudWebSocket:
        return scheme == AiroSecureTransportScheme.wss;
      case AiroSecureTransportChannelKind.futureHttp3:
        return scheme == AiroSecureTransportScheme.httpsHttp3;
      case AiroSecureTransportChannelKind.inMemoryTest:
        return scheme == AiroSecureTransportScheme.inMemory;
    }
  }

  @override
  List<Object?> get props => [
    acceptedSchemaVersion,
    minProtocolVersion,
    maxProtocolVersion,
    maxFrameBytes,
    maxClockSkew,
    requiredFrameKinds,
    trustedPeerStates,
  ];
}

abstract interface class AiroSecureTransportAdapter {
  AiroSecureTransportLifecycleState get state;

  Future<AiroSecureTransportValidationResult> connect(
    AiroSecureTransportHandshakeOffer offer, {
    required DateTime now,
  });

  Future<AiroSecureTransportValidationResult> sendFrame(
    AiroSecureTransportFrameProbe frame, {
    required DateTime now,
  });

  Future<void> close();
}

class AiroNoOpSecureTransportAdapter implements AiroSecureTransportAdapter {
  const AiroNoOpSecureTransportAdapter(this.endpoint);

  final AiroSecureTransportEndpointDescriptor endpoint;

  @override
  AiroSecureTransportLifecycleState get state =>
      AiroSecureTransportLifecycleState.closed;

  @override
  Future<AiroSecureTransportValidationResult> connect(
    AiroSecureTransportHandshakeOffer offer, {
    required DateTime now,
  }) async {
    return AiroSecureTransportValidationResult(
      endpointId: endpoint.endpointId,
      peerNodeId: offer.peerNodeId,
      codes: const [AiroSecureTransportBlockerCode.adapterUnavailable],
    );
  }

  @override
  Future<AiroSecureTransportValidationResult> sendFrame(
    AiroSecureTransportFrameProbe frame, {
    required DateTime now,
  }) async {
    return AiroSecureTransportValidationResult(
      endpointId: endpoint.endpointId,
      frameId: frame.frameId,
      sequence: frame.sequence,
      codes: const [AiroSecureTransportBlockerCode.adapterUnavailable],
    );
  }

  @override
  Future<void> close() async {}
}

class AiroFakeSecureTransportAdapter implements AiroSecureTransportAdapter {
  AiroFakeSecureTransportAdapter({
    required this.endpoint,
    required this.policy,
  });

  final AiroSecureTransportEndpointDescriptor endpoint;
  final AiroSecureTransportPolicy policy;
  final List<AiroSecureTransportFrameProbe> sentFrames = [];
  final Set<int> _acceptedSequences = {};
  AiroSecureTransportLifecycleState _state =
      AiroSecureTransportLifecycleState.idle;

  @override
  AiroSecureTransportLifecycleState get state => _state;

  @override
  Future<AiroSecureTransportValidationResult> connect(
    AiroSecureTransportHandshakeOffer offer, {
    required DateTime now,
  }) async {
    _state = AiroSecureTransportLifecycleState.connecting;
    final result = policy.validateHandshake(offer: offer, now: now);
    _state = result.accepted
        ? AiroSecureTransportLifecycleState.open
        : AiroSecureTransportLifecycleState.failed;
    return result;
  }

  @override
  Future<AiroSecureTransportValidationResult> sendFrame(
    AiroSecureTransportFrameProbe frame, {
    required DateTime now,
  }) async {
    if (!state.allowsFrameSend) {
      return AiroSecureTransportValidationResult(
        endpointId: endpoint.endpointId,
        frameId: frame.frameId,
        sequence: frame.sequence,
        codes: const [AiroSecureTransportBlockerCode.notConnected],
      );
    }
    final result = policy.validateFrame(
      endpoint: endpoint,
      frame: frame,
      now: now,
      acceptedSequences: _acceptedSequences,
    );
    if (result.accepted) {
      _acceptedSequences.add(frame.sequence);
      sentFrames.add(frame);
    }
    return result;
  }

  @override
  Future<void> close() async {
    _state = AiroSecureTransportLifecycleState.closed;
  }
}
