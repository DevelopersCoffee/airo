import 'package:equatable/equatable.dart';

const String kAiroPairingSchemaVersion = '1.0.0';

enum AiroDeviceRole {
  tvReceiver('tv_receiver'),
  mobileController('mobile_controller'),
  desktopCompanion('desktop_companion'),
  homeNode('home_node'),
  cloudRelay('cloud_relay');

  const AiroDeviceRole(this.stableId);

  final String stableId;
}

enum AiroPairingScope {
  playbackControl('playback_control'),
  textInput('text_input'),
  sourceSelection('source_selection'),
  diagnostics('diagnostics'),
  companionSearch('companion_search'),
  playbackTicketIssue('playback_ticket_issue');

  const AiroPairingScope(this.stableId);

  final String stableId;
}

enum AiroPairingChallengeStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  expired('expired'),
  revoked('revoked');

  const AiroPairingChallengeStatus(this.stableId);

  final String stableId;
}

enum AiroTrustedDeviceAccessCode {
  accepted('accepted'),
  scopeMissing('scope_missing'),
  notYetValid('not_yet_valid'),
  expired('expired'),
  revoked('revoked');

  const AiroTrustedDeviceAccessCode(this.stableId);

  final String stableId;
}

enum AiroTrustedDeviceTrustLevel {
  restricted('restricted', 0),
  paired('paired', 1),
  trusted('trusted', 2),
  owner('owner', 3);

  const AiroTrustedDeviceTrustLevel(this.stableId, this.rank);

  final String stableId;
  final int rank;

  bool satisfies(AiroTrustedDeviceTrustLevel minimum) => rank >= minimum.rank;
}

enum AiroTrustedDeviceKeyAlgorithm {
  ed25519('ed25519'),
  p256('p256');

  const AiroTrustedDeviceKeyAlgorithm(this.stableId);

  final String stableId;
}

enum AiroTrustedDeviceKeyState {
  active('active'),
  rotationDue('rotation_due'),
  notYetValid('not_yet_valid'),
  expired('expired'),
  revoked('revoked');

  const AiroTrustedDeviceKeyState(this.stableId);

  final String stableId;
}

enum AiroTrustedDeviceSecurityCode {
  accepted('accepted'),
  accessDenied('access_denied'),
  trustLevelInsufficient('trust_level_insufficient'),
  keyMissing('key_missing'),
  keyUnsupported('key_unsupported'),
  keyNotYetValid('key_not_yet_valid'),
  keyExpired('key_expired'),
  keyRevoked('key_revoked'),
  keyRotationRequired('key_rotation_required');

  const AiroTrustedDeviceSecurityCode(this.stableId);

  final String stableId;
}

enum AiroPlaybackTicketValidationCode {
  accepted('accepted'),
  receiverMismatch('receiver_mismatch'),
  sessionMismatch('session_mismatch'),
  scopeMissing('scope_missing'),
  notYetValid('not_yet_valid'),
  expired('expired'),
  revoked('revoked'),
  alreadyUsed('already_used');

  const AiroPlaybackTicketValidationCode(this.stableId);

  final String stableId;
}

enum AiroPlaybackTicketServiceAction {
  issue('issue'),
  redeem('redeem'),
  deny('deny'),
  noOp('no_op');

  const AiroPlaybackTicketServiceAction(this.stableId);

  final String stableId;
}

enum AiroPlaybackTicketServiceCode {
  accepted('accepted'),
  invalidLifetime('invalid_lifetime'),
  receiverMismatch('receiver_mismatch'),
  sessionMismatch('session_mismatch'),
  sourceUnsafe('source_unsafe'),
  issuerAccessDenied('issuer_access_denied'),
  issuerTrustInsufficient('issuer_trust_insufficient'),
  issuerKeyMissing('issuer_key_missing'),
  issuerKeyUnsupported('issuer_key_unsupported'),
  issuerKeyNotYetValid('issuer_key_not_yet_valid'),
  issuerKeyExpired('issuer_key_expired'),
  issuerKeyRevoked('issuer_key_revoked'),
  issuerKeyRotationRequired('issuer_key_rotation_required'),
  scopeMissing('scope_missing'),
  notYetValid('not_yet_valid'),
  expired('expired'),
  revoked('revoked'),
  alreadyUsed('already_used'),
  serviceUnavailable('service_unavailable');

  const AiroPlaybackTicketServiceCode(this.stableId);

  final String stableId;
}

enum AiroPlaybackSourceHandleRejectionCode {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value');

  const AiroPlaybackSourceHandleRejectionCode(this.stableId);

  final String stableId;
}

class AiroPairingChallenge extends Equatable {
  AiroPairingChallenge({
    required this.challengeId,
    required this.receiverDeviceId,
    required this.receiverRole,
    required Set<AiroPairingScope> requestedScopes,
    required this.issuedAt,
    required this.expiresAt,
    this.status = AiroPairingChallengeStatus.pending,
    this.schemaVersion = kAiroPairingSchemaVersion,
  }) : requestedScopes = Set.unmodifiable(requestedScopes);

  final String schemaVersion;
  final String challengeId;
  final String receiverDeviceId;
  final AiroDeviceRole receiverRole;
  final Set<AiroPairingScope> requestedScopes;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final AiroPairingChallengeStatus status;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  AiroPairingChallengeStatus statusAt(DateTime now) {
    if (status == AiroPairingChallengeStatus.pending && isExpired(now)) {
      return AiroPairingChallengeStatus.expired;
    }
    return status;
  }

  bool canApproveAt(DateTime now) =>
      statusAt(now) == AiroPairingChallengeStatus.pending;

  @override
  List<Object?> get props => [
    schemaVersion,
    challengeId,
    receiverDeviceId,
    receiverRole,
    requestedScopes,
    issuedAt,
    expiresAt,
    status,
  ];
}

class AiroTrustedDeviceRecord extends Equatable {
  AiroTrustedDeviceRecord({
    required this.relationshipId,
    required this.controllerDeviceId,
    required this.receiverDeviceId,
    required this.controllerRole,
    required this.receiverRole,
    required Set<AiroPairingScope> scopes,
    required this.createdAt,
    this.notBefore,
    this.expiresAt,
    this.revokedAt,
    this.pairingChallengeId,
    this.trustLevel = AiroTrustedDeviceTrustLevel.paired,
    this.keyDescriptor,
    this.revokedByDeviceId,
    this.revocationReason,
    this.schemaVersion = kAiroPairingSchemaVersion,
  }) : scopes = Set.unmodifiable(scopes);

  final String schemaVersion;
  final String relationshipId;
  final String controllerDeviceId;
  final String receiverDeviceId;
  final AiroDeviceRole controllerRole;
  final AiroDeviceRole receiverRole;
  final Set<AiroPairingScope> scopes;
  final DateTime createdAt;
  final DateTime? notBefore;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final String? pairingChallengeId;
  final AiroTrustedDeviceTrustLevel trustLevel;
  final AiroTrustedDeviceKeyDescriptor? keyDescriptor;
  final String? revokedByDeviceId;
  final String? revocationReason;

  AiroTrustedDeviceAccessResult evaluateAccess({
    required AiroPairingScope requiredScope,
    required DateTime now,
  }) {
    if (revokedAt != null && !now.isBefore(revokedAt!)) {
      return const AiroTrustedDeviceAccessResult(
        code: AiroTrustedDeviceAccessCode.revoked,
      );
    }
    final startsAt = notBefore ?? createdAt;
    if (now.isBefore(startsAt)) {
      return const AiroTrustedDeviceAccessResult(
        code: AiroTrustedDeviceAccessCode.notYetValid,
      );
    }
    if (expiresAt != null && !now.isBefore(expiresAt!)) {
      return const AiroTrustedDeviceAccessResult(
        code: AiroTrustedDeviceAccessCode.expired,
      );
    }
    if (!scopes.contains(requiredScope)) {
      return const AiroTrustedDeviceAccessResult(
        code: AiroTrustedDeviceAccessCode.scopeMissing,
      );
    }
    return const AiroTrustedDeviceAccessResult(
      code: AiroTrustedDeviceAccessCode.accepted,
    );
  }

  bool allows({
    required AiroPairingScope requiredScope,
    required DateTime now,
  }) {
    return evaluateAccess(requiredScope: requiredScope, now: now).accepted;
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    relationshipId,
    controllerDeviceId,
    receiverDeviceId,
    controllerRole,
    receiverRole,
    scopes,
    createdAt,
    notBefore,
    expiresAt,
    revokedAt,
    pairingChallengeId,
    trustLevel,
    keyDescriptor,
    revokedByDeviceId,
    revocationReason,
  ];
}

class AiroTrustedDeviceAccessResult extends Equatable {
  const AiroTrustedDeviceAccessResult({required this.code});

  final AiroTrustedDeviceAccessCode code;

  bool get accepted => code == AiroTrustedDeviceAccessCode.accepted;

  @override
  List<Object?> get props => [code];
}

class AiroTrustedDeviceKeyDescriptor extends Equatable {
  const AiroTrustedDeviceKeyDescriptor({
    required this.keyId,
    required this.algorithm,
    required this.publicKeyFingerprint,
    required this.createdAt,
    required this.notBefore,
    required this.expiresAt,
    this.revokedAt,
    this.schemaVersion = kAiroPairingSchemaVersion,
  });

  final String schemaVersion;
  final String keyId;
  final AiroTrustedDeviceKeyAlgorithm algorithm;
  final String publicKeyFingerprint;
  final DateTime createdAt;
  final DateTime notBefore;
  final DateTime expiresAt;
  final DateTime? revokedAt;

  AiroTrustedDeviceKeyState stateAt({
    required DateTime now,
    Duration? rotationInterval,
  }) {
    if (revokedAt != null && !now.isBefore(revokedAt!)) {
      return AiroTrustedDeviceKeyState.revoked;
    }
    if (now.isBefore(notBefore)) {
      return AiroTrustedDeviceKeyState.notYetValid;
    }
    if (!now.isBefore(expiresAt)) {
      return AiroTrustedDeviceKeyState.expired;
    }
    if (rotationInterval != null &&
        !now.isBefore(createdAt.add(rotationInterval))) {
      return AiroTrustedDeviceKeyState.rotationDue;
    }
    return AiroTrustedDeviceKeyState.active;
  }

  @override
  String toString() {
    return 'AiroTrustedDeviceKeyDescriptor('
        'keyId: $keyId, '
        'algorithm: ${algorithm.stableId}, '
        'createdAt: $createdAt, '
        'notBefore: $notBefore, '
        'expiresAt: $expiresAt, '
        'revokedAt: $revokedAt'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    keyId,
    algorithm,
    publicKeyFingerprint,
    createdAt,
    notBefore,
    expiresAt,
    revokedAt,
  ];
}

class AiroTrustedDeviceSecurityPolicy extends Equatable {
  AiroTrustedDeviceSecurityPolicy({
    required this.requiredScope,
    this.minimumTrustLevel = AiroTrustedDeviceTrustLevel.paired,
    Set<AiroTrustedDeviceKeyAlgorithm> allowedKeyAlgorithms = const {
      AiroTrustedDeviceKeyAlgorithm.ed25519,
      AiroTrustedDeviceKeyAlgorithm.p256,
    },
    this.keyRotationInterval,
    this.requiresKeyDescriptor = true,
  }) : allowedKeyAlgorithms = Set.unmodifiable(allowedKeyAlgorithms);

  final AiroPairingScope requiredScope;
  final AiroTrustedDeviceTrustLevel minimumTrustLevel;
  final Set<AiroTrustedDeviceKeyAlgorithm> allowedKeyAlgorithms;
  final Duration? keyRotationInterval;
  final bool requiresKeyDescriptor;

  AiroTrustedDeviceSecurityResult evaluate({
    required AiroTrustedDeviceRecord record,
    required DateTime now,
  }) {
    final blockers = <AiroTrustedDeviceSecurityBlocker>[];
    final access = record.evaluateAccess(
      requiredScope: requiredScope,
      now: now,
    );
    if (!access.accepted) {
      blockers.add(
        AiroTrustedDeviceSecurityBlocker(
          code: AiroTrustedDeviceSecurityCode.accessDenied,
          accessCode: access.code,
        ),
      );
    }
    if (!record.trustLevel.satisfies(minimumTrustLevel)) {
      blockers.add(
        AiroTrustedDeviceSecurityBlocker(
          code: AiroTrustedDeviceSecurityCode.trustLevelInsufficient,
          field: 'trustLevel',
        ),
      );
    }

    final keyDescriptor = record.keyDescriptor;
    if (keyDescriptor == null) {
      if (requiresKeyDescriptor) {
        blockers.add(
          const AiroTrustedDeviceSecurityBlocker(
            code: AiroTrustedDeviceSecurityCode.keyMissing,
            field: 'keyDescriptor',
          ),
        );
      }
    } else {
      if (!allowedKeyAlgorithms.contains(keyDescriptor.algorithm)) {
        blockers.add(
          AiroTrustedDeviceSecurityBlocker(
            code: AiroTrustedDeviceSecurityCode.keyUnsupported,
            field: keyDescriptor.algorithm.stableId,
          ),
        );
      }
      switch (keyDescriptor.stateAt(
        now: now,
        rotationInterval: keyRotationInterval,
      )) {
        case AiroTrustedDeviceKeyState.active:
          break;
        case AiroTrustedDeviceKeyState.rotationDue:
          blockers.add(
            const AiroTrustedDeviceSecurityBlocker(
              code: AiroTrustedDeviceSecurityCode.keyRotationRequired,
              field: 'keyDescriptor',
            ),
          );
        case AiroTrustedDeviceKeyState.notYetValid:
          blockers.add(
            const AiroTrustedDeviceSecurityBlocker(
              code: AiroTrustedDeviceSecurityCode.keyNotYetValid,
              field: 'keyDescriptor',
            ),
          );
        case AiroTrustedDeviceKeyState.expired:
          blockers.add(
            const AiroTrustedDeviceSecurityBlocker(
              code: AiroTrustedDeviceSecurityCode.keyExpired,
              field: 'keyDescriptor',
            ),
          );
        case AiroTrustedDeviceKeyState.revoked:
          blockers.add(
            const AiroTrustedDeviceSecurityBlocker(
              code: AiroTrustedDeviceSecurityCode.keyRevoked,
              field: 'keyDescriptor',
            ),
          );
      }
    }

    return AiroTrustedDeviceSecurityResult(blockers: blockers);
  }

  @override
  List<Object?> get props => [
    requiredScope,
    minimumTrustLevel,
    allowedKeyAlgorithms,
    keyRotationInterval,
    requiresKeyDescriptor,
  ];
}

class AiroTrustedDeviceSecurityBlocker extends Equatable {
  const AiroTrustedDeviceSecurityBlocker({
    required this.code,
    this.accessCode,
    this.field,
  });

  final AiroTrustedDeviceSecurityCode code;
  final AiroTrustedDeviceAccessCode? accessCode;
  final String? field;

  @override
  List<Object?> get props => [code, accessCode, field];
}

class AiroTrustedDeviceSecurityResult extends Equatable {
  AiroTrustedDeviceSecurityResult({
    required List<AiroTrustedDeviceSecurityBlocker> blockers,
  }) : blockers = List.unmodifiable(blockers);

  final List<AiroTrustedDeviceSecurityBlocker> blockers;

  bool get accepted => blockers.isEmpty;

  bool has(AiroTrustedDeviceSecurityCode code) {
    return blockers.any((blocker) => blocker.code == code);
  }

  @override
  List<Object?> get props => [blockers];
}

class AiroPlaybackSourceHandle extends Equatable {
  const AiroPlaybackSourceHandle._(this.value);

  factory AiroPlaybackSourceHandle.redacted(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return AiroPlaybackSourceHandle._(value.trim());
  }

  final String value;

  static AiroPlaybackSourceHandleRejectionCode? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return AiroPlaybackSourceHandleRejectionCode.empty;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroPlaybackSourceHandleRejectionCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroPlaybackSourceHandleRejectionCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroPlaybackSourceHandleRejectionCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroPlaybackSourceHandleRejectionCode.credentialLikeValue;
    }

    return null;
  }

  @override
  String toString() => 'AiroPlaybackSourceHandle(redacted)';

  @override
  List<Object?> get props => [value];
}

class AiroPlaybackTicket extends Equatable {
  AiroPlaybackTicket({
    required this.ticketId,
    required this.receiverDeviceId,
    required this.sessionId,
    required this.sourceHandle,
    required Set<AiroPairingScope> scopes,
    required this.issuedAt,
    required this.notBefore,
    required this.expiresAt,
    this.revokedAt,
    this.usedAt,
    this.schemaVersion = kAiroPairingSchemaVersion,
  }) : scopes = Set.unmodifiable(scopes);

  final String schemaVersion;
  final String ticketId;
  final String receiverDeviceId;
  final String sessionId;
  final AiroPlaybackSourceHandle sourceHandle;
  final Set<AiroPairingScope> scopes;
  final DateTime issuedAt;
  final DateTime notBefore;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final DateTime? usedAt;

  AiroPlaybackTicketValidationResult validate({
    required String receiverDeviceId,
    required String sessionId,
    required AiroPairingScope requiredScope,
    required DateTime now,
  }) {
    if (this.receiverDeviceId != receiverDeviceId) {
      return const AiroPlaybackTicketValidationResult(
        code: AiroPlaybackTicketValidationCode.receiverMismatch,
      );
    }
    if (this.sessionId != sessionId) {
      return const AiroPlaybackTicketValidationResult(
        code: AiroPlaybackTicketValidationCode.sessionMismatch,
      );
    }
    if (revokedAt != null && !now.isBefore(revokedAt!)) {
      return const AiroPlaybackTicketValidationResult(
        code: AiroPlaybackTicketValidationCode.revoked,
      );
    }
    if (usedAt != null && !now.isBefore(usedAt!)) {
      return const AiroPlaybackTicketValidationResult(
        code: AiroPlaybackTicketValidationCode.alreadyUsed,
      );
    }
    if (!scopes.contains(requiredScope)) {
      return const AiroPlaybackTicketValidationResult(
        code: AiroPlaybackTicketValidationCode.scopeMissing,
      );
    }
    if (now.isBefore(notBefore)) {
      return const AiroPlaybackTicketValidationResult(
        code: AiroPlaybackTicketValidationCode.notYetValid,
      );
    }
    if (!now.isBefore(expiresAt)) {
      return const AiroPlaybackTicketValidationResult(
        code: AiroPlaybackTicketValidationCode.expired,
      );
    }
    return const AiroPlaybackTicketValidationResult(
      code: AiroPlaybackTicketValidationCode.accepted,
    );
  }

  bool allows({
    required String receiverDeviceId,
    required String sessionId,
    required AiroPairingScope requiredScope,
    required DateTime now,
  }) {
    return validate(
      receiverDeviceId: receiverDeviceId,
      sessionId: sessionId,
      requiredScope: requiredScope,
      now: now,
    ).accepted;
  }

  AiroPlaybackTicket copyWith({DateTime? revokedAt, DateTime? usedAt}) {
    return AiroPlaybackTicket(
      schemaVersion: schemaVersion,
      ticketId: ticketId,
      receiverDeviceId: receiverDeviceId,
      sessionId: sessionId,
      sourceHandle: sourceHandle,
      scopes: scopes,
      issuedAt: issuedAt,
      notBefore: notBefore,
      expiresAt: expiresAt,
      revokedAt: revokedAt ?? this.revokedAt,
      usedAt: usedAt ?? this.usedAt,
    );
  }

  @override
  String toString() {
    return 'AiroPlaybackTicket('
        'ticketId: $ticketId, '
        'receiverDeviceId: $receiverDeviceId, '
        'sessionId: $sessionId, '
        'sourceHandle: redacted, '
        'scopes: ${scopes.map((scope) => scope.stableId).join(',')}, '
        'issuedAt: $issuedAt, '
        'notBefore: $notBefore, '
        'expiresAt: $expiresAt, '
        'revokedAt: $revokedAt, '
        'usedAt: $usedAt'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    ticketId,
    receiverDeviceId,
    sessionId,
    sourceHandle,
    scopes,
    issuedAt,
    notBefore,
    expiresAt,
    revokedAt,
    usedAt,
  ];
}

class AiroPlaybackTicketValidationResult extends Equatable {
  const AiroPlaybackTicketValidationResult({required this.code});

  final AiroPlaybackTicketValidationCode code;

  bool get accepted => code == AiroPlaybackTicketValidationCode.accepted;

  @override
  List<Object?> get props => [code];
}

class AiroPlaybackTicketIssueRequest extends Equatable {
  AiroPlaybackTicketIssueRequest({
    required this.requestId,
    required this.ticketId,
    required this.receiverDeviceId,
    required this.sessionId,
    required this.sourceHandle,
    required Set<AiroPairingScope> scopes,
    required this.issuerDeviceId,
    required this.issuedAt,
    required this.notBefore,
    required this.expiresAt,
    this.schemaVersion = kAiroPairingSchemaVersion,
  }) : scopes = Set.unmodifiable(scopes);

  final String schemaVersion;
  final String requestId;
  final String ticketId;
  final String receiverDeviceId;
  final String sessionId;
  final AiroPlaybackSourceHandle sourceHandle;
  final Set<AiroPairingScope> scopes;
  final String issuerDeviceId;
  final DateTime issuedAt;
  final DateTime notBefore;
  final DateTime expiresAt;

  Duration get lifetime => expiresAt.difference(notBefore);

  AiroPlaybackTicket toTicket() {
    return AiroPlaybackTicket(
      ticketId: ticketId,
      receiverDeviceId: receiverDeviceId,
      sessionId: sessionId,
      sourceHandle: sourceHandle,
      scopes: scopes,
      issuedAt: issuedAt,
      notBefore: notBefore,
      expiresAt: expiresAt,
      schemaVersion: schemaVersion,
    );
  }

  @override
  String toString() {
    return 'AiroPlaybackTicketIssueRequest('
        'requestId: $requestId, '
        'ticketId: $ticketId, '
        'receiverDeviceId: $receiverDeviceId, '
        'sessionId: $sessionId, '
        'sourceHandle: redacted, '
        'scopes: ${scopes.map((scope) => scope.stableId).join(',')}, '
        'issuerDeviceId: $issuerDeviceId, '
        'notBefore: $notBefore, '
        'expiresAt: $expiresAt'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    requestId,
    ticketId,
    receiverDeviceId,
    sessionId,
    sourceHandle,
    scopes,
    issuerDeviceId,
    issuedAt,
    notBefore,
    expiresAt,
  ];
}

class AiroPlaybackTicketRedeemRequest extends Equatable {
  const AiroPlaybackTicketRedeemRequest({
    required this.requestId,
    required this.ticketId,
    required this.receiverDeviceId,
    required this.sessionId,
    required this.requiredScope,
    required this.redeemedAt,
    this.schemaVersion = kAiroPairingSchemaVersion,
  });

  final String schemaVersion;
  final String requestId;
  final String ticketId;
  final String receiverDeviceId;
  final String sessionId;
  final AiroPairingScope requiredScope;
  final DateTime redeemedAt;

  @override
  List<Object?> get props => [
    schemaVersion,
    requestId,
    ticketId,
    receiverDeviceId,
    sessionId,
    requiredScope,
    redeemedAt,
  ];
}

class AiroPlaybackTicketServiceDecision extends Equatable {
  AiroPlaybackTicketServiceDecision({
    required this.action,
    required Iterable<AiroPlaybackTicketServiceCode> codes,
    this.ticket,
  }) : codes = List.unmodifiable(codes);

  final AiroPlaybackTicketServiceAction action;
  final List<AiroPlaybackTicketServiceCode> codes;
  final AiroPlaybackTicket? ticket;

  bool get accepted =>
      (action == AiroPlaybackTicketServiceAction.issue ||
          action == AiroPlaybackTicketServiceAction.redeem) &&
      codes.length == 1 &&
      codes.single == AiroPlaybackTicketServiceCode.accepted;

  Map<String, Object?> toDiagnosticMap() {
    return {
      'action': action.stableId,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
      'ticketId': ticket?.ticketId,
      'receiverDeviceId': ticket?.receiverDeviceId,
      'sessionId': ticket?.sessionId,
    };
  }

  @override
  List<Object?> get props => [action, codes, ticket];
}

class AiroPlaybackTicketServicePolicy extends Equatable {
  AiroPlaybackTicketServicePolicy({
    this.requiredIssueScope = AiroPairingScope.playbackTicketIssue,
    this.minimumTrustLevel = AiroTrustedDeviceTrustLevel.paired,
    this.minLifetime = const Duration(seconds: 5),
    this.maxLifetime = const Duration(minutes: 5),
    Set<AiroTrustedDeviceKeyAlgorithm> allowedKeyAlgorithms = const {
      AiroTrustedDeviceKeyAlgorithm.ed25519,
      AiroTrustedDeviceKeyAlgorithm.p256,
    },
    this.keyRotationInterval,
  }) : allowedKeyAlgorithms = Set.unmodifiable(allowedKeyAlgorithms);

  final AiroPairingScope requiredIssueScope;
  final AiroTrustedDeviceTrustLevel minimumTrustLevel;
  final Duration minLifetime;
  final Duration maxLifetime;
  final Set<AiroTrustedDeviceKeyAlgorithm> allowedKeyAlgorithms;
  final Duration? keyRotationInterval;

  AiroPlaybackTicketServiceDecision evaluateIssue({
    required AiroPlaybackTicketIssueRequest request,
    required AiroTrustedDeviceRecord issuer,
    required DateTime now,
  }) {
    final codes = <AiroPlaybackTicketServiceCode>[];
    final access = issuer.evaluateAccess(
      requiredScope: requiredIssueScope,
      now: now,
    );
    if (!access.accepted) {
      codes.add(AiroPlaybackTicketServiceCode.issuerAccessDenied);
    }
    if (!issuer.trustLevel.satisfies(minimumTrustLevel)) {
      codes.add(AiroPlaybackTicketServiceCode.issuerTrustInsufficient);
    }
    if (issuer.controllerDeviceId != request.issuerDeviceId) {
      codes.add(AiroPlaybackTicketServiceCode.issuerAccessDenied);
    }
    if (issuer.receiverDeviceId != request.receiverDeviceId) {
      codes.add(AiroPlaybackTicketServiceCode.receiverMismatch);
    }
    if (!request.scopes.contains(AiroPairingScope.playbackControl)) {
      codes.add(AiroPlaybackTicketServiceCode.scopeMissing);
    }
    final lifetime = request.lifetime;
    if (lifetime < minLifetime ||
        lifetime > maxLifetime ||
        !request.notBefore.isBefore(request.expiresAt)) {
      codes.add(AiroPlaybackTicketServiceCode.invalidLifetime);
    }
    if (AiroPlaybackSourceHandle.validate(request.sourceHandle.value) != null) {
      codes.add(AiroPlaybackTicketServiceCode.sourceUnsafe);
    }
    _addKeyCodes(issuer.keyDescriptor, now, codes);

    return AiroPlaybackTicketServiceDecision(
      action: codes.isEmpty
          ? AiroPlaybackTicketServiceAction.issue
          : AiroPlaybackTicketServiceAction.deny,
      codes: codes.isEmpty
          ? const [AiroPlaybackTicketServiceCode.accepted]
          : codes,
      ticket: codes.isEmpty ? request.toTicket() : null,
    );
  }

  AiroPlaybackTicketServiceDecision evaluateRedeem({
    required AiroPlaybackTicket ticket,
    required AiroPlaybackTicketRedeemRequest request,
  }) {
    final result = ticket.validate(
      receiverDeviceId: request.receiverDeviceId,
      sessionId: request.sessionId,
      requiredScope: request.requiredScope,
      now: request.redeemedAt,
    );
    final code = switch (result.code) {
      AiroPlaybackTicketValidationCode.accepted =>
        AiroPlaybackTicketServiceCode.accepted,
      AiroPlaybackTicketValidationCode.receiverMismatch =>
        AiroPlaybackTicketServiceCode.receiverMismatch,
      AiroPlaybackTicketValidationCode.sessionMismatch =>
        AiroPlaybackTicketServiceCode.sessionMismatch,
      AiroPlaybackTicketValidationCode.scopeMissing =>
        AiroPlaybackTicketServiceCode.scopeMissing,
      AiroPlaybackTicketValidationCode.notYetValid =>
        AiroPlaybackTicketServiceCode.notYetValid,
      AiroPlaybackTicketValidationCode.expired =>
        AiroPlaybackTicketServiceCode.expired,
      AiroPlaybackTicketValidationCode.revoked =>
        AiroPlaybackTicketServiceCode.revoked,
      AiroPlaybackTicketValidationCode.alreadyUsed =>
        AiroPlaybackTicketServiceCode.alreadyUsed,
    };

    return AiroPlaybackTicketServiceDecision(
      action: result.accepted
          ? AiroPlaybackTicketServiceAction.redeem
          : AiroPlaybackTicketServiceAction.deny,
      codes: [code],
      ticket: result.accepted
          ? ticket.copyWith(usedAt: request.redeemedAt)
          : ticket,
    );
  }

  void _addKeyCodes(
    AiroTrustedDeviceKeyDescriptor? key,
    DateTime now,
    List<AiroPlaybackTicketServiceCode> codes,
  ) {
    if (key == null) {
      codes.add(AiroPlaybackTicketServiceCode.issuerKeyMissing);
      return;
    }
    if (!allowedKeyAlgorithms.contains(key.algorithm)) {
      codes.add(AiroPlaybackTicketServiceCode.issuerKeyUnsupported);
    }
    switch (key.stateAt(now: now, rotationInterval: keyRotationInterval)) {
      case AiroTrustedDeviceKeyState.active:
        break;
      case AiroTrustedDeviceKeyState.notYetValid:
        codes.add(AiroPlaybackTicketServiceCode.issuerKeyNotYetValid);
      case AiroTrustedDeviceKeyState.expired:
        codes.add(AiroPlaybackTicketServiceCode.issuerKeyExpired);
      case AiroTrustedDeviceKeyState.revoked:
        codes.add(AiroPlaybackTicketServiceCode.issuerKeyRevoked);
      case AiroTrustedDeviceKeyState.rotationDue:
        codes.add(AiroPlaybackTicketServiceCode.issuerKeyRotationRequired);
    }
  }

  @override
  List<Object?> get props => [
    requiredIssueScope,
    minimumTrustLevel,
    minLifetime,
    maxLifetime,
    allowedKeyAlgorithms,
    keyRotationInterval,
  ];
}

abstract interface class AiroPlaybackTicketService {
  Future<AiroPlaybackTicketServiceDecision> issue({
    required AiroPlaybackTicketIssueRequest request,
    required AiroTrustedDeviceRecord issuer,
    required DateTime now,
  });

  Future<AiroPlaybackTicketServiceDecision> redeem({
    required AiroPlaybackTicketRedeemRequest request,
  });

  Future<AiroPlaybackTicket?> revoke({
    required String ticketId,
    required DateTime revokedAt,
  });
}

class AiroNoOpPlaybackTicketService implements AiroPlaybackTicketService {
  const AiroNoOpPlaybackTicketService();

  @override
  Future<AiroPlaybackTicketServiceDecision> issue({
    required AiroPlaybackTicketIssueRequest request,
    required AiroTrustedDeviceRecord issuer,
    required DateTime now,
  }) async {
    return AiroPlaybackTicketServiceDecision(
      action: AiroPlaybackTicketServiceAction.noOp,
      codes: const [AiroPlaybackTicketServiceCode.serviceUnavailable],
    );
  }

  @override
  Future<AiroPlaybackTicketServiceDecision> redeem({
    required AiroPlaybackTicketRedeemRequest request,
  }) async {
    return AiroPlaybackTicketServiceDecision(
      action: AiroPlaybackTicketServiceAction.noOp,
      codes: const [AiroPlaybackTicketServiceCode.serviceUnavailable],
    );
  }

  @override
  Future<AiroPlaybackTicket?> revoke({
    required String ticketId,
    required DateTime revokedAt,
  }) async {
    return null;
  }
}

class AiroFakePlaybackTicketService implements AiroPlaybackTicketService {
  AiroFakePlaybackTicketService({
    AiroPlaybackTicketServicePolicy? policy,
    Iterable<AiroPlaybackTicket> tickets = const [],
  }) : policy = policy ?? AiroPlaybackTicketServicePolicy(),
       _tickets = {for (final ticket in tickets) ticket.ticketId: ticket};

  final AiroPlaybackTicketServicePolicy policy;
  final Map<String, AiroPlaybackTicket> _tickets;

  @override
  Future<AiroPlaybackTicketServiceDecision> issue({
    required AiroPlaybackTicketIssueRequest request,
    required AiroTrustedDeviceRecord issuer,
    required DateTime now,
  }) async {
    final decision = policy.evaluateIssue(
      request: request,
      issuer: issuer,
      now: now,
    );
    final ticket = decision.ticket;
    if (decision.accepted && ticket != null) {
      _tickets[ticket.ticketId] = ticket;
    }
    return decision;
  }

  @override
  Future<AiroPlaybackTicketServiceDecision> redeem({
    required AiroPlaybackTicketRedeemRequest request,
  }) async {
    final ticket = _tickets[request.ticketId];
    if (ticket == null) {
      return AiroPlaybackTicketServiceDecision(
        action: AiroPlaybackTicketServiceAction.deny,
        codes: const [AiroPlaybackTicketServiceCode.revoked],
      );
    }
    final decision = policy.evaluateRedeem(ticket: ticket, request: request);
    final redeemed = decision.ticket;
    if (decision.accepted && redeemed != null) {
      _tickets[redeemed.ticketId] = redeemed;
    }
    return decision;
  }

  @override
  Future<AiroPlaybackTicket?> revoke({
    required String ticketId,
    required DateTime revokedAt,
  }) async {
    final ticket = _tickets[ticketId];
    if (ticket == null) return null;
    final revoked = ticket.copyWith(revokedAt: revokedAt);
    _tickets[ticketId] = revoked;
    return revoked;
  }
}
