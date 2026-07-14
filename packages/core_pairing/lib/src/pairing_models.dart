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
  ];
}

class AiroTrustedDeviceAccessResult extends Equatable {
  const AiroTrustedDeviceAccessResult({required this.code});

  final AiroTrustedDeviceAccessCode code;

  bool get accepted => code == AiroTrustedDeviceAccessCode.accepted;

  @override
  List<Object?> get props => [code];
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
