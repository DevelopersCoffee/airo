import 'package:core_pairing/core_pairing.dart';
import 'package:core_protocol/core_protocol.dart';
import 'package:equatable/equatable.dart';

const String kAiroDeviceIdentitySchemaVersion = '1.0.0';
const int kAiroDeviceIdentityProtocolVersion = 1;

enum AiroDeviceStableValueRejectionCode {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value'),
  invalidStableId('invalid_stable_id');

  const AiroDeviceStableValueRejectionCode(this.stableId);

  final String stableId;
}

enum AiroDeviceRegistrationChannel {
  localPairing('local_pairing'),
  cloudBootstrap('cloud_bootstrap'),
  accountRestore('account_restore'),
  factoryProvisioning('factory_provisioning');

  const AiroDeviceRegistrationChannel(this.stableId);

  final String stableId;
}

enum AiroDeviceRegistrationState {
  pending('pending'),
  active('active'),
  duplicate('duplicate'),
  revoked('revoked'),
  resetRequired('reset_required'),
  keyRotationRequired('key_rotation_required'),
  rejected('rejected');

  const AiroDeviceRegistrationState(this.stableId);

  final String stableId;
}

enum AiroDeviceRegistrationAction {
  register('register'),
  mergeExisting('merge_existing'),
  deny('deny'),
  noOp('no_op');

  const AiroDeviceRegistrationAction(this.stableId);

  final String stableId;
}

enum AiroDeviceRegistrationCode {
  accepted('accepted'),
  schemaMismatch('schema_mismatch'),
  protocolTooOld('protocol_too_old'),
  protocolTooNew('protocol_too_new'),
  unsafeStableId('unsafe_stable_id'),
  unsupportedRole('unsupported_role'),
  requiredScopeMissing('required_scope_missing'),
  keyMissing('key_missing'),
  keyUnsupported('key_unsupported'),
  keyNotYetValid('key_not_yet_valid'),
  keyExpired('key_expired'),
  keyRevoked('key_revoked'),
  keyRotationRequired('key_rotation_required'),
  expiredRequest('expired_request'),
  duplicateNodeIdentity('duplicate_node_identity'),
  duplicateKeyFingerprint('duplicate_key_fingerprint'),
  revokedDevice('revoked_device'),
  accountMismatch('account_mismatch'),
  resetRequired('reset_required'),
  registryUnavailable('registry_unavailable');

  const AiroDeviceRegistrationCode(this.stableId);

  final String stableId;
}

class AiroDeviceStableValue extends Equatable {
  const AiroDeviceStableValue._(this.value);

  factory AiroDeviceStableValue.stable(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return AiroDeviceStableValue._(value.trim());
  }

  final String value;

  static AiroDeviceStableValueRejectionCode? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return AiroDeviceStableValueRejectionCode.empty;
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroDeviceStableValueRejectionCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroDeviceStableValueRejectionCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroDeviceStableValueRejectionCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroDeviceStableValueRejectionCode.credentialLikeValue;
    }
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_.-]*$').hasMatch(trimmed)) {
      return AiroDeviceStableValueRejectionCode.invalidStableId;
    }
    return null;
  }

  @override
  String toString() => 'AiroDeviceStableValue(redacted)';

  @override
  List<Object?> get props => [value];
}

class AiroRegisteredDeviceRecord extends Equatable {
  AiroRegisteredDeviceRecord({
    required this.registrationId,
    required this.accountId,
    required this.deviceId,
    required this.nodeIdentity,
    required Set<AiroPairingScope> scopes,
    required this.registeredAt,
    this.keyDescriptor,
    this.trustLevel = AiroTrustedDeviceTrustLevel.paired,
    this.state = AiroDeviceRegistrationState.active,
    this.lastSeenAt,
    this.revokedAt,
    this.duplicateOfDeviceId,
    this.resetGeneration = 0,
    this.schemaVersion = kAiroDeviceIdentitySchemaVersion,
    this.protocolVersion = kAiroDeviceIdentityProtocolVersion,
  }) : scopes = Set.unmodifiable(scopes);

  final String schemaVersion;
  final int protocolVersion;
  final AiroDeviceStableValue registrationId;
  final AiroDeviceStableValue accountId;
  final AiroDeviceStableValue deviceId;
  final AiroNodeIdentity nodeIdentity;
  final AiroTrustedDeviceKeyDescriptor? keyDescriptor;
  final AiroTrustedDeviceTrustLevel trustLevel;
  final Set<AiroPairingScope> scopes;
  final AiroDeviceRegistrationState state;
  final DateTime registeredAt;
  final DateTime? lastSeenAt;
  final DateTime? revokedAt;
  final AiroDeviceStableValue? duplicateOfDeviceId;
  final int resetGeneration;

  bool get isActive =>
      state == AiroDeviceRegistrationState.active && revokedAt == null;

  bool isRevokedAt(DateTime now) {
    return state == AiroDeviceRegistrationState.revoked ||
        (revokedAt != null && !now.isBefore(revokedAt!));
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'protocolVersion': protocolVersion,
      'registrationId': registrationId.value,
      'accountId': accountId.value,
      'deviceId': deviceId.value,
      'nodeId': nodeIdentity.nodeId,
      'role': nodeIdentity.role.stableId,
      'productProfile': nodeIdentity.productProfile.stableId,
      'platformCategory': nodeIdentity.platformCategory.stableId,
      'trustLevel': trustLevel.stableId,
      'scopes': scopes.map((scope) => scope.stableId).toList(growable: false),
      'state': state.stableId,
      'registeredAt': registeredAt.toIso8601String(),
      'lastSeenAt': lastSeenAt?.toIso8601String(),
      'revokedAt': revokedAt?.toIso8601String(),
      'resetGeneration': resetGeneration,
    };
  }

  AiroRegisteredDeviceRecord copyWith({
    AiroDeviceRegistrationState? state,
    DateTime? lastSeenAt,
    DateTime? revokedAt,
    AiroDeviceStableValue? duplicateOfDeviceId,
    int? resetGeneration,
  }) {
    return AiroRegisteredDeviceRecord(
      schemaVersion: schemaVersion,
      protocolVersion: protocolVersion,
      registrationId: registrationId,
      accountId: accountId,
      deviceId: deviceId,
      nodeIdentity: nodeIdentity,
      keyDescriptor: keyDescriptor,
      trustLevel: trustLevel,
      scopes: scopes,
      state: state ?? this.state,
      registeredAt: registeredAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      revokedAt: revokedAt ?? this.revokedAt,
      duplicateOfDeviceId: duplicateOfDeviceId ?? this.duplicateOfDeviceId,
      resetGeneration: resetGeneration ?? this.resetGeneration,
    );
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    registrationId,
    accountId,
    deviceId,
    nodeIdentity,
    keyDescriptor,
    trustLevel,
    scopes,
    state,
    registeredAt,
    lastSeenAt,
    revokedAt,
    duplicateOfDeviceId,
    resetGeneration,
  ];
}

class AiroDeviceRegistrationRequest extends Equatable {
  AiroDeviceRegistrationRequest({
    required this.requestId,
    required this.registrationId,
    required this.accountId,
    required this.deviceId,
    required this.nodeIdentity,
    required Set<AiroPairingScope> requestedScopes,
    required this.channel,
    required this.issuedAt,
    required this.expiresAt,
    this.keyDescriptor,
    this.trustLevel = AiroTrustedDeviceTrustLevel.paired,
    this.resetGeneration = 0,
    this.schemaVersion = kAiroDeviceIdentitySchemaVersion,
    this.protocolVersion = kAiroDeviceIdentityProtocolVersion,
  }) : requestedScopes = Set.unmodifiable(requestedScopes);

  final String schemaVersion;
  final int protocolVersion;
  final AiroDeviceStableValue requestId;
  final AiroDeviceStableValue registrationId;
  final AiroDeviceStableValue accountId;
  final AiroDeviceStableValue deviceId;
  final AiroNodeIdentity nodeIdentity;
  final AiroTrustedDeviceKeyDescriptor? keyDescriptor;
  final AiroTrustedDeviceTrustLevel trustLevel;
  final Set<AiroPairingScope> requestedScopes;
  final AiroDeviceRegistrationChannel channel;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final int resetGeneration;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  AiroRegisteredDeviceRecord toRecord() {
    return AiroRegisteredDeviceRecord(
      registrationId: registrationId,
      accountId: accountId,
      deviceId: deviceId,
      nodeIdentity: nodeIdentity,
      keyDescriptor: keyDescriptor,
      trustLevel: trustLevel,
      scopes: requestedScopes,
      registeredAt: issuedAt,
      resetGeneration: resetGeneration,
    );
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    requestId,
    registrationId,
    accountId,
    deviceId,
    nodeIdentity,
    keyDescriptor,
    trustLevel,
    requestedScopes,
    channel,
    issuedAt,
    expiresAt,
    resetGeneration,
  ];
}

class AiroDeviceRegistrationDecision extends Equatable {
  AiroDeviceRegistrationDecision({
    required this.requestId,
    required this.action,
    required Iterable<AiroDeviceRegistrationCode> codes,
    this.existingDeviceId,
  }) : codes = List.unmodifiable(codes);

  final AiroDeviceStableValue requestId;
  final AiroDeviceRegistrationAction action;
  final List<AiroDeviceRegistrationCode> codes;
  final AiroDeviceStableValue? existingDeviceId;

  bool get accepted =>
      (action == AiroDeviceRegistrationAction.register ||
          action == AiroDeviceRegistrationAction.mergeExisting) &&
      codes.length == 1 &&
      codes.single == AiroDeviceRegistrationCode.accepted;

  Map<String, Object?> toDiagnosticMap() {
    return {
      'requestId': requestId.value,
      'action': action.stableId,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
      'existingDeviceId': existingDeviceId?.value,
    };
  }

  @override
  List<Object?> get props => [requestId, action, codes, existingDeviceId];
}

class AiroDeviceRegistrationPolicy extends Equatable {
  AiroDeviceRegistrationPolicy({
    Set<AiroNodeRole> allowedRoles = const {
      AiroNodeRole.tvReceiver,
      AiroNodeRole.mobileCompanion,
      AiroNodeRole.desktopCompanion,
      AiroNodeRole.homeNode,
    },
    Set<AiroPairingScope> requiredScopes = const {
      AiroPairingScope.playbackControl,
    },
    Set<AiroTrustedDeviceKeyAlgorithm> allowedKeyAlgorithms = const {
      AiroTrustedDeviceKeyAlgorithm.ed25519,
      AiroTrustedDeviceKeyAlgorithm.p256,
    },
    this.keyRotationInterval,
    this.acceptedSchemaVersion = kAiroDeviceIdentitySchemaVersion,
    this.minProtocolVersion = kAiroDeviceIdentityProtocolVersion,
    this.maxProtocolVersion = kAiroDeviceIdentityProtocolVersion,
  }) : allowedRoles = Set.unmodifiable(allowedRoles),
       requiredScopes = Set.unmodifiable(requiredScopes),
       allowedKeyAlgorithms = Set.unmodifiable(allowedKeyAlgorithms);

  final String acceptedSchemaVersion;
  final int minProtocolVersion;
  final int maxProtocolVersion;
  final Set<AiroNodeRole> allowedRoles;
  final Set<AiroPairingScope> requiredScopes;
  final Set<AiroTrustedDeviceKeyAlgorithm> allowedKeyAlgorithms;
  final Duration? keyRotationInterval;

  AiroDeviceRegistrationDecision evaluate({
    required AiroDeviceRegistrationRequest request,
    required DateTime now,
    Iterable<AiroRegisteredDeviceRecord> existingDevices = const [],
  }) {
    final codes = <AiroDeviceRegistrationCode>[];
    _addVersionCodes(request, codes);
    _addStableValueCodes(request, codes);
    _addRoleScopeCodes(request, codes);
    _addKeyCodes(request, now, codes);
    _addRegistrationWindowCodes(request, now, codes);

    final existing = _matchingExisting(request, existingDevices);
    final existingDeviceId = existing?.deviceId;
    if (existing != null) {
      _addExistingRecordCodes(request, existing, now, codes);
    }
    _addDuplicateCodes(request, existingDevices, existing, codes);

    final action = _actionFor(codes, existing);
    return AiroDeviceRegistrationDecision(
      requestId: request.requestId,
      action: action,
      existingDeviceId: existingDeviceId,
      codes: codes.isEmpty
          ? const [AiroDeviceRegistrationCode.accepted]
          : codes,
    );
  }

  void _addVersionCodes(
    AiroDeviceRegistrationRequest request,
    List<AiroDeviceRegistrationCode> codes,
  ) {
    if (request.schemaVersion != acceptedSchemaVersion ||
        request.nodeIdentity.schemaVersion != kAiroNodeProtocolSchemaVersion) {
      codes.add(AiroDeviceRegistrationCode.schemaMismatch);
    }
    if (request.protocolVersion < minProtocolVersion ||
        request.nodeIdentity.protocolVersion < kAiroNodeProtocolVersion) {
      codes.add(AiroDeviceRegistrationCode.protocolTooOld);
    }
    if (request.protocolVersion > maxProtocolVersion ||
        request.nodeIdentity.protocolVersion > kAiroNodeProtocolVersion) {
      codes.add(AiroDeviceRegistrationCode.protocolTooNew);
    }
  }

  void _addStableValueCodes(
    AiroDeviceRegistrationRequest request,
    List<AiroDeviceRegistrationCode> codes,
  ) {
    final values = [
      request.requestId.value,
      request.registrationId.value,
      request.accountId.value,
      request.deviceId.value,
      request.nodeIdentity.nodeId,
    ];
    if (values.any((value) => AiroDeviceStableValue.validate(value) != null)) {
      codes.add(AiroDeviceRegistrationCode.unsafeStableId);
    }
  }

  void _addRoleScopeCodes(
    AiroDeviceRegistrationRequest request,
    List<AiroDeviceRegistrationCode> codes,
  ) {
    if (!allowedRoles.contains(request.nodeIdentity.role)) {
      codes.add(AiroDeviceRegistrationCode.unsupportedRole);
    }
    if (!request.requestedScopes.containsAll(requiredScopes)) {
      codes.add(AiroDeviceRegistrationCode.requiredScopeMissing);
    }
  }

  void _addKeyCodes(
    AiroDeviceRegistrationRequest request,
    DateTime now,
    List<AiroDeviceRegistrationCode> codes,
  ) {
    final key = request.keyDescriptor;
    if (key == null) {
      codes.add(AiroDeviceRegistrationCode.keyMissing);
      return;
    }
    if (!allowedKeyAlgorithms.contains(key.algorithm)) {
      codes.add(AiroDeviceRegistrationCode.keyUnsupported);
    }
    switch (key.stateAt(now: now, rotationInterval: keyRotationInterval)) {
      case AiroTrustedDeviceKeyState.active:
        break;
      case AiroTrustedDeviceKeyState.notYetValid:
        codes.add(AiroDeviceRegistrationCode.keyNotYetValid);
      case AiroTrustedDeviceKeyState.expired:
        codes.add(AiroDeviceRegistrationCode.keyExpired);
      case AiroTrustedDeviceKeyState.revoked:
        codes.add(AiroDeviceRegistrationCode.keyRevoked);
      case AiroTrustedDeviceKeyState.rotationDue:
        codes.add(AiroDeviceRegistrationCode.keyRotationRequired);
    }
  }

  void _addRegistrationWindowCodes(
    AiroDeviceRegistrationRequest request,
    DateTime now,
    List<AiroDeviceRegistrationCode> codes,
  ) {
    if (request.isExpired(now)) {
      codes.add(AiroDeviceRegistrationCode.expiredRequest);
    }
  }

  void _addExistingRecordCodes(
    AiroDeviceRegistrationRequest request,
    AiroRegisteredDeviceRecord existing,
    DateTime now,
    List<AiroDeviceRegistrationCode> codes,
  ) {
    if (existing.accountId != request.accountId) {
      codes.add(AiroDeviceRegistrationCode.accountMismatch);
    }
    if (existing.isRevokedAt(now)) {
      codes.add(AiroDeviceRegistrationCode.revokedDevice);
    }
    if (existing.state == AiroDeviceRegistrationState.resetRequired ||
        existing.resetGeneration > request.resetGeneration) {
      codes.add(AiroDeviceRegistrationCode.resetRequired);
    }
  }

  void _addDuplicateCodes(
    AiroDeviceRegistrationRequest request,
    Iterable<AiroRegisteredDeviceRecord> existingDevices,
    AiroRegisteredDeviceRecord? matchingExisting,
    List<AiroDeviceRegistrationCode> codes,
  ) {
    for (final existing in existingDevices) {
      if (matchingExisting == existing) continue;
      if (existing.nodeIdentity.nodeId == request.nodeIdentity.nodeId) {
        codes.add(AiroDeviceRegistrationCode.duplicateNodeIdentity);
      }
      final requestKey = request.keyDescriptor;
      final existingKey = existing.keyDescriptor;
      if (requestKey != null &&
          existingKey != null &&
          existingKey.publicKeyFingerprint == requestKey.publicKeyFingerprint) {
        codes.add(AiroDeviceRegistrationCode.duplicateKeyFingerprint);
      }
    }
  }

  AiroRegisteredDeviceRecord? _matchingExisting(
    AiroDeviceRegistrationRequest request,
    Iterable<AiroRegisteredDeviceRecord> existingDevices,
  ) {
    for (final existing in existingDevices) {
      if (existing.deviceId == request.deviceId ||
          existing.registrationId == request.registrationId) {
        return existing;
      }
    }
    return null;
  }

  AiroDeviceRegistrationAction _actionFor(
    List<AiroDeviceRegistrationCode> codes,
    AiroRegisteredDeviceRecord? existing,
  ) {
    if (codes.isNotEmpty) return AiroDeviceRegistrationAction.deny;
    if (existing != null) return AiroDeviceRegistrationAction.mergeExisting;
    return AiroDeviceRegistrationAction.register;
  }

  @override
  List<Object?> get props => [
    acceptedSchemaVersion,
    minProtocolVersion,
    maxProtocolVersion,
    allowedRoles,
    requiredScopes,
    allowedKeyAlgorithms,
    keyRotationInterval,
  ];
}

abstract interface class AiroDeviceIdentityRegistry {
  Future<AiroDeviceRegistrationDecision> register({
    required AiroDeviceRegistrationRequest request,
    required DateTime now,
  });

  Future<AiroRegisteredDeviceRecord?> revoke({
    required AiroDeviceStableValue deviceId,
    required DateTime now,
  });

  Future<List<AiroRegisteredDeviceRecord>> list();
}

class AiroNoOpDeviceIdentityRegistry implements AiroDeviceIdentityRegistry {
  const AiroNoOpDeviceIdentityRegistry();

  @override
  Future<List<AiroRegisteredDeviceRecord>> list() async => const [];

  @override
  Future<AiroDeviceRegistrationDecision> register({
    required AiroDeviceRegistrationRequest request,
    required DateTime now,
  }) async {
    return AiroDeviceRegistrationDecision(
      requestId: request.requestId,
      action: AiroDeviceRegistrationAction.noOp,
      codes: const [AiroDeviceRegistrationCode.registryUnavailable],
    );
  }

  @override
  Future<AiroRegisteredDeviceRecord?> revoke({
    required AiroDeviceStableValue deviceId,
    required DateTime now,
  }) async {
    return null;
  }
}

class AiroFakeDeviceIdentityRegistry implements AiroDeviceIdentityRegistry {
  AiroFakeDeviceIdentityRegistry({
    required this.policy,
    Iterable<AiroRegisteredDeviceRecord> seedDevices = const [],
  }) : _records = List.of(seedDevices);

  final AiroDeviceRegistrationPolicy policy;
  final List<AiroRegisteredDeviceRecord> _records;

  @override
  Future<List<AiroRegisteredDeviceRecord>> list() async {
    return List.unmodifiable(_records);
  }

  @override
  Future<AiroDeviceRegistrationDecision> register({
    required AiroDeviceRegistrationRequest request,
    required DateTime now,
  }) async {
    final decision = policy.evaluate(
      request: request,
      now: now,
      existingDevices: _records,
    );
    if (decision.action == AiroDeviceRegistrationAction.register) {
      _records.add(request.toRecord());
    }
    return decision;
  }

  @override
  Future<AiroRegisteredDeviceRecord?> revoke({
    required AiroDeviceStableValue deviceId,
    required DateTime now,
  }) async {
    final index = _records.indexWhere((record) => record.deviceId == deviceId);
    if (index < 0) return null;
    final revoked = _records[index].copyWith(
      state: AiroDeviceRegistrationState.revoked,
      revokedAt: now,
    );
    _records[index] = revoked;
    return revoked;
  }
}
