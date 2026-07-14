import 'package:core_media_routing/core_media_routing.dart';
import 'package:core_pairing/core_pairing.dart';
import 'package:equatable/equatable.dart';

const String kAiroCloudOrchestrationSchemaVersion = '1.0.0';
const int kAiroCloudOrchestrationProtocolVersion = 1;
const int kAiroCloudOrchestrationDefaultMaxPayloadBytes = 32 * 1024;
const Duration kAiroCloudOrchestrationDefaultMaxRetention = Duration(
  minutes: 5,
);

enum AiroCloudOrchestrationMode {
  disabled('disabled'),
  localOnly('local_only'),
  discoveryOnly('discovery_only'),
  commandAndState('command_and_state'),
  continuity('continuity');

  const AiroCloudOrchestrationMode(this.stableId);

  final String stableId;

  bool get allowsPrivateCloud => this == commandAndState || this == continuity;
}

enum AiroCloudOrchestrationService {
  deviceRegistry('device_registry'),
  presence('presence'),
  commandRouting('command_routing'),
  stateDistribution('state_distribution'),
  playbackTicketBroker('playback_ticket_broker'),
  notificationWake('notification_wake'),
  recoveryCoordinator('recovery_coordinator'),
  progressSync('progress_sync');

  const AiroCloudOrchestrationService(this.stableId);

  final String stableId;
}

enum AiroCloudOrchestrationDecisionAction {
  allow('allow'),
  deny('deny'),
  localFallback('local_fallback'),
  noOp('no_op');

  const AiroCloudOrchestrationDecisionAction(this.stableId);

  final String stableId;
}

enum AiroCloudOrchestrationCode {
  accepted('accepted'),
  schemaMismatch('schema_mismatch'),
  protocolTooOld('protocol_too_old'),
  protocolTooNew('protocol_too_new'),
  cloudDisabled('cloud_disabled'),
  localOnlyMode('local_only_mode'),
  unsupportedService('unsupported_service'),
  discoveryOnlyMode('discovery_only_mode'),
  untrustedActor('untrusted_actor'),
  revokedActor('revoked_actor'),
  missingScope('missing_scope'),
  expiredRequest('expired_request'),
  unsafeStableId('unsafe_stable_id'),
  mediaProxyForbidden('media_proxy_forbidden'),
  retentionTooLong('retention_too_long'),
  payloadTooLarge('payload_too_large'),
  staleRevision('stale_revision'),
  duplicateCommand('duplicate_command'),
  providerUnavailable('provider_unavailable');

  const AiroCloudOrchestrationCode(this.stableId);

  final String stableId;
}

enum AiroCloudStableValueRejectionCode {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value'),
  invalidStableId('invalid_stable_id');

  const AiroCloudStableValueRejectionCode(this.stableId);

  final String stableId;
}

class AiroCloudStableValue extends Equatable {
  const AiroCloudStableValue._(this.value);

  factory AiroCloudStableValue.stable(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return AiroCloudStableValue._(value.trim());
  }

  final String value;

  static AiroCloudStableValueRejectionCode? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return AiroCloudStableValueRejectionCode.empty;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroCloudStableValueRejectionCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroCloudStableValueRejectionCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroCloudStableValueRejectionCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroCloudStableValueRejectionCode.credentialLikeValue;
    }
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_.-]*$').hasMatch(trimmed)) {
      return AiroCloudStableValueRejectionCode.invalidStableId;
    }
    return null;
  }

  @override
  String toString() => 'AiroCloudStableValue(redacted)';

  @override
  List<Object?> get props => [value];
}

class AiroCloudOrchestrationManifest extends Equatable {
  AiroCloudOrchestrationManifest({
    required this.manifestId,
    required this.mode,
    required Set<AiroCloudOrchestrationService> enabledServices,
    this.requiredTrustLevel = AiroTrustedDeviceTrustLevel.paired,
    this.maxPayloadBytes = kAiroCloudOrchestrationDefaultMaxPayloadBytes,
    this.maxRetention = kAiroCloudOrchestrationDefaultMaxRetention,
    this.mediaProxyAllowed = false,
    this.providerAvailable = true,
    this.schemaVersion = kAiroCloudOrchestrationSchemaVersion,
    this.protocolVersion = kAiroCloudOrchestrationProtocolVersion,
  }) : enabledServices = Set.unmodifiable(enabledServices);

  final String schemaVersion;
  final int protocolVersion;
  final AiroCloudStableValue manifestId;
  final AiroCloudOrchestrationMode mode;
  final Set<AiroCloudOrchestrationService> enabledServices;
  final AiroTrustedDeviceTrustLevel requiredTrustLevel;
  final int maxPayloadBytes;
  final Duration maxRetention;
  final bool mediaProxyAllowed;
  final bool providerAvailable;

  bool supports(AiroCloudOrchestrationService service) {
    return enabledServices.contains(service);
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    manifestId,
    mode,
    enabledServices,
    requiredTrustLevel,
    maxPayloadBytes,
    maxRetention,
    mediaProxyAllowed,
    providerAvailable,
  ];
}

class AiroCloudOrchestrationRequest extends Equatable {
  AiroCloudOrchestrationRequest({
    required this.requestId,
    required this.service,
    required this.actorNodeId,
    required this.targetNodeId,
    required this.actorTrustLevel,
    required Set<AiroPairingScope> grantedScopes,
    required this.issuedAt,
    required this.expiresAt,
    this.requiredScope,
    this.sessionId,
    this.commandId,
    this.routeKind = AiroMediaRouteKind.cloudCommandOnly,
    this.proxiesMedia = false,
    this.payloadBytes = 0,
    this.requestedRetention = Duration.zero,
    this.baseRevision,
    this.currentRevision,
    this.actorRevoked = false,
    this.schemaVersion = kAiroCloudOrchestrationSchemaVersion,
    this.protocolVersion = kAiroCloudOrchestrationProtocolVersion,
  }) : grantedScopes = Set.unmodifiable(grantedScopes);

  final String schemaVersion;
  final int protocolVersion;
  final AiroCloudStableValue requestId;
  final AiroCloudOrchestrationService service;
  final AiroCloudStableValue actorNodeId;
  final AiroCloudStableValue targetNodeId;
  final AiroTrustedDeviceTrustLevel actorTrustLevel;
  final Set<AiroPairingScope> grantedScopes;
  final AiroPairingScope? requiredScope;
  final AiroCloudStableValue? sessionId;
  final AiroCloudStableValue? commandId;
  final AiroMediaRouteKind routeKind;
  final bool proxiesMedia;
  final int payloadBytes;
  final Duration requestedRetention;
  final int? baseRevision;
  final int? currentRevision;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final bool actorRevoked;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  bool get hasStaleRevision {
    final base = baseRevision;
    final current = currentRevision;
    return base != null && current != null && base < current;
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    requestId,
    service,
    actorNodeId,
    targetNodeId,
    actorTrustLevel,
    grantedScopes,
    requiredScope,
    sessionId,
    commandId,
    routeKind,
    proxiesMedia,
    payloadBytes,
    requestedRetention,
    baseRevision,
    currentRevision,
    issuedAt,
    expiresAt,
    actorRevoked,
  ];
}

class AiroCloudOrchestrationDecision extends Equatable {
  AiroCloudOrchestrationDecision({
    required this.requestId,
    required this.action,
    required Iterable<AiroCloudOrchestrationCode> codes,
  }) : codes = List.unmodifiable(codes);

  final AiroCloudStableValue requestId;
  final AiroCloudOrchestrationDecisionAction action;
  final List<AiroCloudOrchestrationCode> codes;

  bool get accepted =>
      action == AiroCloudOrchestrationDecisionAction.allow &&
      codes.length == 1 &&
      codes.single == AiroCloudOrchestrationCode.accepted;

  Map<String, Object?> toDiagnosticMap() {
    return {
      'requestId': requestId.value,
      'action': action.stableId,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [requestId, action, codes];
}

class AiroCloudOrchestrationPolicy extends Equatable {
  const AiroCloudOrchestrationPolicy({
    this.acceptedSchemaVersion = kAiroCloudOrchestrationSchemaVersion,
    this.minProtocolVersion = kAiroCloudOrchestrationProtocolVersion,
    this.maxProtocolVersion = kAiroCloudOrchestrationProtocolVersion,
  });

  final String acceptedSchemaVersion;
  final int minProtocolVersion;
  final int maxProtocolVersion;

  AiroCloudOrchestrationDecision evaluate({
    required AiroCloudOrchestrationManifest manifest,
    required AiroCloudOrchestrationRequest request,
    required DateTime now,
    Set<AiroCloudStableValue> acceptedCommandIds = const {},
  }) {
    final codes = <AiroCloudOrchestrationCode>[];
    _addVersionCodes(
      schemaVersion: manifest.schemaVersion,
      protocolVersion: manifest.protocolVersion,
      codes: codes,
    );
    _addVersionCodes(
      schemaVersion: request.schemaVersion,
      protocolVersion: request.protocolVersion,
      codes: codes,
    );

    _addModeCodes(manifest, request, codes);
    _addSecurityCodes(manifest, request, now, codes);
    _addBoundaryCodes(manifest, request, acceptedCommandIds, codes);

    return AiroCloudOrchestrationDecision(
      requestId: request.requestId,
      action: _actionFor(codes),
      codes: codes.isEmpty
          ? const [AiroCloudOrchestrationCode.accepted]
          : codes,
    );
  }

  void _addVersionCodes({
    required String schemaVersion,
    required int protocolVersion,
    required List<AiroCloudOrchestrationCode> codes,
  }) {
    if (schemaVersion != acceptedSchemaVersion) {
      codes.add(AiroCloudOrchestrationCode.schemaMismatch);
    }
    if (protocolVersion < minProtocolVersion) {
      codes.add(AiroCloudOrchestrationCode.protocolTooOld);
    }
    if (protocolVersion > maxProtocolVersion) {
      codes.add(AiroCloudOrchestrationCode.protocolTooNew);
    }
  }

  void _addModeCodes(
    AiroCloudOrchestrationManifest manifest,
    AiroCloudOrchestrationRequest request,
    List<AiroCloudOrchestrationCode> codes,
  ) {
    if (manifest.mode == AiroCloudOrchestrationMode.disabled) {
      codes.add(AiroCloudOrchestrationCode.cloudDisabled);
    }
    if (manifest.mode == AiroCloudOrchestrationMode.localOnly) {
      codes.add(AiroCloudOrchestrationCode.localOnlyMode);
    }
    if (manifest.mode == AiroCloudOrchestrationMode.discoveryOnly &&
        request.service != AiroCloudOrchestrationService.deviceRegistry &&
        request.service != AiroCloudOrchestrationService.presence) {
      codes.add(AiroCloudOrchestrationCode.discoveryOnlyMode);
    }
    if (!manifest.supports(request.service)) {
      codes.add(AiroCloudOrchestrationCode.unsupportedService);
    }
    if (!manifest.providerAvailable) {
      codes.add(AiroCloudOrchestrationCode.providerUnavailable);
    }
  }

  void _addSecurityCodes(
    AiroCloudOrchestrationManifest manifest,
    AiroCloudOrchestrationRequest request,
    DateTime now,
    List<AiroCloudOrchestrationCode> codes,
  ) {
    if (request.actorRevoked) {
      codes.add(AiroCloudOrchestrationCode.revokedActor);
    }
    if (!request.actorTrustLevel.satisfies(manifest.requiredTrustLevel)) {
      codes.add(AiroCloudOrchestrationCode.untrustedActor);
    }
    final requiredScope = request.requiredScope;
    if (requiredScope != null &&
        !request.grantedScopes.contains(requiredScope)) {
      codes.add(AiroCloudOrchestrationCode.missingScope);
    }
    if (request.isExpired(now)) {
      codes.add(AiroCloudOrchestrationCode.expiredRequest);
    }
    for (final value in [
      request.requestId,
      request.actorNodeId,
      request.targetNodeId,
      ?request.sessionId,
      ?request.commandId,
    ]) {
      if (AiroCloudStableValue.validate(value.value) != null) {
        codes.add(AiroCloudOrchestrationCode.unsafeStableId);
        break;
      }
    }
  }

  void _addBoundaryCodes(
    AiroCloudOrchestrationManifest manifest,
    AiroCloudOrchestrationRequest request,
    Set<AiroCloudStableValue> acceptedCommandIds,
    List<AiroCloudOrchestrationCode> codes,
  ) {
    if (request.proxiesMedia || manifest.mediaProxyAllowed) {
      codes.add(AiroCloudOrchestrationCode.mediaProxyForbidden);
    }
    if (request.payloadBytes > manifest.maxPayloadBytes) {
      codes.add(AiroCloudOrchestrationCode.payloadTooLarge);
    }
    if (request.requestedRetention > manifest.maxRetention) {
      codes.add(AiroCloudOrchestrationCode.retentionTooLong);
    }
    if (request.hasStaleRevision) {
      codes.add(AiroCloudOrchestrationCode.staleRevision);
    }
    final commandId = request.commandId;
    if (commandId != null && acceptedCommandIds.contains(commandId)) {
      codes.add(AiroCloudOrchestrationCode.duplicateCommand);
    }
  }

  AiroCloudOrchestrationDecisionAction _actionFor(
    List<AiroCloudOrchestrationCode> codes,
  ) {
    if (codes.isEmpty) return AiroCloudOrchestrationDecisionAction.allow;
    if (codes.any(_isHardDeny)) {
      return AiroCloudOrchestrationDecisionAction.deny;
    }
    if (codes.contains(AiroCloudOrchestrationCode.cloudDisabled) ||
        codes.contains(AiroCloudOrchestrationCode.localOnlyMode) ||
        codes.contains(AiroCloudOrchestrationCode.providerUnavailable)) {
      return AiroCloudOrchestrationDecisionAction.localFallback;
    }
    return AiroCloudOrchestrationDecisionAction.deny;
  }

  bool _isHardDeny(AiroCloudOrchestrationCode code) {
    return switch (code) {
      AiroCloudOrchestrationCode.accepted ||
      AiroCloudOrchestrationCode.cloudDisabled ||
      AiroCloudOrchestrationCode.localOnlyMode ||
      AiroCloudOrchestrationCode.providerUnavailable => false,
      AiroCloudOrchestrationCode.schemaMismatch ||
      AiroCloudOrchestrationCode.protocolTooOld ||
      AiroCloudOrchestrationCode.protocolTooNew ||
      AiroCloudOrchestrationCode.unsupportedService ||
      AiroCloudOrchestrationCode.discoveryOnlyMode ||
      AiroCloudOrchestrationCode.untrustedActor ||
      AiroCloudOrchestrationCode.revokedActor ||
      AiroCloudOrchestrationCode.missingScope ||
      AiroCloudOrchestrationCode.expiredRequest ||
      AiroCloudOrchestrationCode.unsafeStableId ||
      AiroCloudOrchestrationCode.mediaProxyForbidden ||
      AiroCloudOrchestrationCode.retentionTooLong ||
      AiroCloudOrchestrationCode.payloadTooLarge ||
      AiroCloudOrchestrationCode.staleRevision ||
      AiroCloudOrchestrationCode.duplicateCommand => true,
    };
  }

  @override
  List<Object?> get props => [
    acceptedSchemaVersion,
    minProtocolVersion,
    maxProtocolVersion,
  ];
}

abstract interface class AiroCloudOrchestrator {
  Future<AiroCloudOrchestrationDecision> coordinate({
    required AiroCloudOrchestrationRequest request,
    required DateTime now,
  });
}

class AiroNoOpCloudOrchestrator implements AiroCloudOrchestrator {
  const AiroNoOpCloudOrchestrator(this.manifest);

  final AiroCloudOrchestrationManifest manifest;

  @override
  Future<AiroCloudOrchestrationDecision> coordinate({
    required AiroCloudOrchestrationRequest request,
    required DateTime now,
  }) async {
    return AiroCloudOrchestrationDecision(
      requestId: request.requestId,
      action: AiroCloudOrchestrationDecisionAction.noOp,
      codes: const [AiroCloudOrchestrationCode.providerUnavailable],
    );
  }
}

class AiroFakeCloudOrchestrator implements AiroCloudOrchestrator {
  AiroFakeCloudOrchestrator({
    required this.manifest,
    required this.policy,
    Set<AiroCloudStableValue> acceptedCommandIds = const {},
  }) : acceptedCommandIds = Set.of(acceptedCommandIds);

  final AiroCloudOrchestrationManifest manifest;
  final AiroCloudOrchestrationPolicy policy;
  final Set<AiroCloudStableValue> acceptedCommandIds;
  final List<AiroCloudOrchestrationRequest> acceptedRequests = [];

  @override
  Future<AiroCloudOrchestrationDecision> coordinate({
    required AiroCloudOrchestrationRequest request,
    required DateTime now,
  }) async {
    final decision = policy.evaluate(
      manifest: manifest,
      request: request,
      now: now,
      acceptedCommandIds: acceptedCommandIds,
    );
    if (decision.accepted) {
      acceptedRequests.add(request);
      final commandId = request.commandId;
      if (commandId != null) acceptedCommandIds.add(commandId);
    }
    return decision;
  }
}
