import 'package:core_device_identity/core_device_identity.dart';
import 'package:core_protocol/core_protocol.dart';
import 'package:equatable/equatable.dart';

const String kAiroPresenceSchemaVersion = '1.0.0';
const int kAiroPresenceProtocolVersion = 1;

enum AiroPresenceStatus {
  online('online'),
  available('available'),
  playing('playing'),
  paused('paused'),
  buffering('buffering'),
  busy('busy'),
  sleeping('sleeping'),
  backgrounded('backgrounded'),
  offline('offline'),
  unreachable('unreachable'),
  updateRequired('update_required');

  const AiroPresenceStatus(this.stableId);

  final String stableId;
}

enum AiroPresenceVisibility {
  hidden('hidden'),
  localNetwork('local_network'),
  trustedDevices('trusted_devices'),
  account('account'),
  cloudPrivate('cloud_private');

  const AiroPresenceVisibility(this.stableId);

  final String stableId;
}

enum AiroPresenceDecisionAction {
  accept('accept'),
  expire('expire'),
  deny('deny'),
  noOp('no_op');

  const AiroPresenceDecisionAction(this.stableId);

  final String stableId;
}

enum AiroPresenceCode {
  accepted('accepted'),
  schemaMismatch('schema_mismatch'),
  protocolTooOld('protocol_too_old'),
  protocolTooNew('protocol_too_new'),
  unsafeStableId('unsafe_stable_id'),
  unregisteredDevice('unregistered_device'),
  accountMismatch('account_mismatch'),
  deviceMismatch('device_mismatch'),
  registrationMismatch('registration_mismatch'),
  revokedDevice('revoked_device'),
  resetRequired('reset_required'),
  staleSequence('stale_sequence'),
  expiredLease('expired_lease'),
  heartbeatTooSoon('heartbeat_too_soon'),
  heartbeatTooLate('heartbeat_too_late'),
  leaseTooShort('lease_too_short'),
  leaseTooLong('lease_too_long'),
  visibilityDenied('visibility_denied'),
  storeUnavailable('store_unavailable');

  const AiroPresenceCode(this.stableId);

  final String stableId;
}

class AiroPresenceLease extends Equatable {
  AiroPresenceLease({
    required this.leaseId,
    required this.accountId,
    required this.deviceId,
    required this.registrationId,
    required this.status,
    required this.lifecycle,
    required this.visibility,
    required Set<AiroNodeCapability> visibleCapabilities,
    required this.sequence,
    required this.issuedAt,
    required this.lastHeartbeatAt,
    required this.expiresAt,
    required this.heartbeatInterval,
    this.schemaVersion = kAiroPresenceSchemaVersion,
    this.protocolVersion = kAiroPresenceProtocolVersion,
  }) : visibleCapabilities = Set.unmodifiable(visibleCapabilities);

  final String schemaVersion;
  final int protocolVersion;
  final AiroDeviceStableValue leaseId;
  final AiroDeviceStableValue accountId;
  final AiroDeviceStableValue deviceId;
  final AiroDeviceStableValue registrationId;
  final AiroPresenceStatus status;
  final AiroNodeLifecycleState lifecycle;
  final AiroPresenceVisibility visibility;
  final Set<AiroNodeCapability> visibleCapabilities;
  final int sequence;
  final DateTime issuedAt;
  final DateTime lastHeartbeatAt;
  final DateTime expiresAt;
  final Duration heartbeatInterval;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  Duration leaseDuration() => expiresAt.difference(issuedAt);

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'protocolVersion': protocolVersion,
      'leaseId': leaseId.value,
      'accountId': accountId.value,
      'deviceId': deviceId.value,
      'registrationId': registrationId.value,
      'status': status.stableId,
      'lifecycle': lifecycle.stableId,
      'visibility': visibility.stableId,
      'capabilities': visibleCapabilities
          .map((capability) => capability.stableId)
          .toList(growable: false),
      'sequence': sequence,
      'issuedAt': issuedAt.toIso8601String(),
      'lastHeartbeatAt': lastHeartbeatAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'heartbeatSeconds': heartbeatInterval.inSeconds,
    };
  }

  AiroPresenceLease copyWith({
    AiroPresenceStatus? status,
    AiroNodeLifecycleState? lifecycle,
    AiroPresenceVisibility? visibility,
    Set<AiroNodeCapability>? visibleCapabilities,
    int? sequence,
    DateTime? lastHeartbeatAt,
    DateTime? expiresAt,
    Duration? heartbeatInterval,
  }) {
    return AiroPresenceLease(
      schemaVersion: schemaVersion,
      protocolVersion: protocolVersion,
      leaseId: leaseId,
      accountId: accountId,
      deviceId: deviceId,
      registrationId: registrationId,
      status: status ?? this.status,
      lifecycle: lifecycle ?? this.lifecycle,
      visibility: visibility ?? this.visibility,
      visibleCapabilities: visibleCapabilities ?? this.visibleCapabilities,
      sequence: sequence ?? this.sequence,
      issuedAt: issuedAt,
      lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
      expiresAt: expiresAt ?? this.expiresAt,
      heartbeatInterval: heartbeatInterval ?? this.heartbeatInterval,
    );
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    leaseId,
    accountId,
    deviceId,
    registrationId,
    status,
    lifecycle,
    visibility,
    visibleCapabilities,
    sequence,
    issuedAt,
    lastHeartbeatAt,
    expiresAt,
    heartbeatInterval,
  ];
}

class AiroPresenceHeartbeat extends Equatable {
  AiroPresenceHeartbeat({
    required this.leaseId,
    required this.accountId,
    required this.deviceId,
    required this.registrationId,
    required this.status,
    required this.lifecycle,
    required this.visibility,
    required Set<AiroNodeCapability> visibleCapabilities,
    required this.sequence,
    required this.observedAt,
    required this.expiresAt,
    required this.heartbeatInterval,
    this.schemaVersion = kAiroPresenceSchemaVersion,
    this.protocolVersion = kAiroPresenceProtocolVersion,
  }) : visibleCapabilities = Set.unmodifiable(visibleCapabilities);

  final String schemaVersion;
  final int protocolVersion;
  final AiroDeviceStableValue leaseId;
  final AiroDeviceStableValue accountId;
  final AiroDeviceStableValue deviceId;
  final AiroDeviceStableValue registrationId;
  final AiroPresenceStatus status;
  final AiroNodeLifecycleState lifecycle;
  final AiroPresenceVisibility visibility;
  final Set<AiroNodeCapability> visibleCapabilities;
  final int sequence;
  final DateTime observedAt;
  final DateTime expiresAt;
  final Duration heartbeatInterval;

  Duration leaseDuration() => expiresAt.difference(observedAt);

  AiroPresenceLease toLease() {
    return AiroPresenceLease(
      leaseId: leaseId,
      accountId: accountId,
      deviceId: deviceId,
      registrationId: registrationId,
      status: status,
      lifecycle: lifecycle,
      visibility: visibility,
      visibleCapabilities: visibleCapabilities,
      sequence: sequence,
      issuedAt: observedAt,
      lastHeartbeatAt: observedAt,
      expiresAt: expiresAt,
      heartbeatInterval: heartbeatInterval,
    );
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    leaseId,
    accountId,
    deviceId,
    registrationId,
    status,
    lifecycle,
    visibility,
    visibleCapabilities,
    sequence,
    observedAt,
    expiresAt,
    heartbeatInterval,
  ];
}

class AiroPresenceDecision extends Equatable {
  AiroPresenceDecision({
    required this.leaseId,
    required this.action,
    required Iterable<AiroPresenceCode> codes,
  }) : codes = List.unmodifiable(codes);

  final AiroDeviceStableValue leaseId;
  final AiroPresenceDecisionAction action;
  final List<AiroPresenceCode> codes;

  bool get accepted =>
      action == AiroPresenceDecisionAction.accept &&
      codes.length == 1 &&
      codes.single == AiroPresenceCode.accepted;

  Map<String, Object?> toDiagnosticMap() {
    return {
      'leaseId': leaseId.value,
      'action': action.stableId,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [leaseId, action, codes];
}

class AiroPresencePolicy extends Equatable {
  AiroPresencePolicy({
    Set<AiroPresenceVisibility> allowedVisibility = const {
      AiroPresenceVisibility.hidden,
      AiroPresenceVisibility.localNetwork,
      AiroPresenceVisibility.trustedDevices,
      AiroPresenceVisibility.account,
      AiroPresenceVisibility.cloudPrivate,
    },
    this.minHeartbeatInterval = const Duration(seconds: 5),
    this.maxHeartbeatInterval = const Duration(minutes: 5),
    this.minLeaseDuration = const Duration(seconds: 15),
    this.maxLeaseDuration = const Duration(minutes: 10),
    this.acceptedSchemaVersion = kAiroPresenceSchemaVersion,
    this.minProtocolVersion = kAiroPresenceProtocolVersion,
    this.maxProtocolVersion = kAiroPresenceProtocolVersion,
  }) : allowedVisibility = Set.unmodifiable(allowedVisibility);

  final String acceptedSchemaVersion;
  final int minProtocolVersion;
  final int maxProtocolVersion;
  final Set<AiroPresenceVisibility> allowedVisibility;
  final Duration minHeartbeatInterval;
  final Duration maxHeartbeatInterval;
  final Duration minLeaseDuration;
  final Duration maxLeaseDuration;

  AiroPresenceDecision evaluate({
    required AiroPresenceHeartbeat heartbeat,
    required DateTime now,
    AiroPresenceLease? currentLease,
    AiroRegisteredDeviceRecord? deviceRecord,
  }) {
    final codes = <AiroPresenceCode>[];
    _addVersionCodes(heartbeat, codes);
    _addStableValueCodes(heartbeat, codes);
    _addDeviceCodes(heartbeat, deviceRecord, now, codes);
    _addLeaseCodes(heartbeat, currentLease, now, codes);
    _addCadenceCodes(heartbeat, codes);

    return AiroPresenceDecision(
      leaseId: heartbeat.leaseId,
      action: _actionFor(codes),
      codes: codes.isEmpty ? const [AiroPresenceCode.accepted] : codes,
    );
  }

  void _addVersionCodes(
    AiroPresenceHeartbeat heartbeat,
    List<AiroPresenceCode> codes,
  ) {
    if (heartbeat.schemaVersion != acceptedSchemaVersion) {
      codes.add(AiroPresenceCode.schemaMismatch);
    }
    if (heartbeat.protocolVersion < minProtocolVersion) {
      codes.add(AiroPresenceCode.protocolTooOld);
    }
    if (heartbeat.protocolVersion > maxProtocolVersion) {
      codes.add(AiroPresenceCode.protocolTooNew);
    }
  }

  void _addStableValueCodes(
    AiroPresenceHeartbeat heartbeat,
    List<AiroPresenceCode> codes,
  ) {
    final values = [
      heartbeat.leaseId.value,
      heartbeat.accountId.value,
      heartbeat.deviceId.value,
      heartbeat.registrationId.value,
    ];
    if (values.any((value) => AiroDeviceStableValue.validate(value) != null)) {
      codes.add(AiroPresenceCode.unsafeStableId);
    }
  }

  void _addDeviceCodes(
    AiroPresenceHeartbeat heartbeat,
    AiroRegisteredDeviceRecord? deviceRecord,
    DateTime now,
    List<AiroPresenceCode> codes,
  ) {
    if (deviceRecord == null) {
      codes.add(AiroPresenceCode.unregisteredDevice);
      return;
    }
    if (deviceRecord.accountId != heartbeat.accountId) {
      codes.add(AiroPresenceCode.accountMismatch);
    }
    if (deviceRecord.deviceId != heartbeat.deviceId) {
      codes.add(AiroPresenceCode.deviceMismatch);
    }
    if (deviceRecord.registrationId != heartbeat.registrationId) {
      codes.add(AiroPresenceCode.registrationMismatch);
    }
    if (deviceRecord.isRevokedAt(now)) {
      codes.add(AiroPresenceCode.revokedDevice);
    }
    if (deviceRecord.state == AiroDeviceRegistrationState.resetRequired) {
      codes.add(AiroPresenceCode.resetRequired);
    }
  }

  void _addLeaseCodes(
    AiroPresenceHeartbeat heartbeat,
    AiroPresenceLease? currentLease,
    DateTime now,
    List<AiroPresenceCode> codes,
  ) {
    if (currentLease == null) return;
    if (currentLease.leaseId != heartbeat.leaseId) {
      codes.add(AiroPresenceCode.registrationMismatch);
    }
    if (currentLease.isExpired(now)) {
      codes.add(AiroPresenceCode.expiredLease);
    }
    if (heartbeat.sequence <= currentLease.sequence) {
      codes.add(AiroPresenceCode.staleSequence);
    }
    final sinceLast = heartbeat.observedAt.difference(
      currentLease.lastHeartbeatAt,
    );
    if (sinceLast < minHeartbeatInterval) {
      codes.add(AiroPresenceCode.heartbeatTooSoon);
    }
    if (sinceLast > maxHeartbeatInterval) {
      codes.add(AiroPresenceCode.heartbeatTooLate);
    }
  }

  void _addCadenceCodes(
    AiroPresenceHeartbeat heartbeat,
    List<AiroPresenceCode> codes,
  ) {
    if (!allowedVisibility.contains(heartbeat.visibility)) {
      codes.add(AiroPresenceCode.visibilityDenied);
    }
    if (heartbeat.heartbeatInterval < minHeartbeatInterval) {
      codes.add(AiroPresenceCode.heartbeatTooSoon);
    }
    if (heartbeat.heartbeatInterval > maxHeartbeatInterval) {
      codes.add(AiroPresenceCode.heartbeatTooLate);
    }
    final leaseDuration = heartbeat.leaseDuration();
    if (leaseDuration < minLeaseDuration) {
      codes.add(AiroPresenceCode.leaseTooShort);
    }
    if (leaseDuration > maxLeaseDuration) {
      codes.add(AiroPresenceCode.leaseTooLong);
    }
  }

  AiroPresenceDecisionAction _actionFor(List<AiroPresenceCode> codes) {
    if (codes.isEmpty) return AiroPresenceDecisionAction.accept;
    if (codes.length == 1 && codes.single == AiroPresenceCode.expiredLease) {
      return AiroPresenceDecisionAction.expire;
    }
    return AiroPresenceDecisionAction.deny;
  }

  @override
  List<Object?> get props => [
    acceptedSchemaVersion,
    minProtocolVersion,
    maxProtocolVersion,
    allowedVisibility,
    minHeartbeatInterval,
    maxHeartbeatInterval,
    minLeaseDuration,
    maxLeaseDuration,
  ];
}

abstract interface class AiroPresenceStore {
  Future<AiroPresenceDecision> recordHeartbeat({
    required AiroPresenceHeartbeat heartbeat,
    required DateTime now,
  });

  Future<List<AiroPresenceLease>> activeLeases({required DateTime now});

  Future<AiroPresenceLease?> expireLease({
    required AiroDeviceStableValue leaseId,
    required DateTime now,
  });
}

class AiroNoOpPresenceStore implements AiroPresenceStore {
  const AiroNoOpPresenceStore();

  @override
  Future<List<AiroPresenceLease>> activeLeases({required DateTime now}) async {
    return const [];
  }

  @override
  Future<AiroPresenceLease?> expireLease({
    required AiroDeviceStableValue leaseId,
    required DateTime now,
  }) async {
    return null;
  }

  @override
  Future<AiroPresenceDecision> recordHeartbeat({
    required AiroPresenceHeartbeat heartbeat,
    required DateTime now,
  }) async {
    return AiroPresenceDecision(
      leaseId: heartbeat.leaseId,
      action: AiroPresenceDecisionAction.noOp,
      codes: const [AiroPresenceCode.storeUnavailable],
    );
  }
}

class AiroFakePresenceStore implements AiroPresenceStore {
  AiroFakePresenceStore({
    required this.policy,
    Iterable<AiroRegisteredDeviceRecord> devices = const [],
    Iterable<AiroPresenceLease> leases = const [],
  }) : _devices = List.of(devices),
       _leases = List.of(leases);

  final AiroPresencePolicy policy;
  final List<AiroRegisteredDeviceRecord> _devices;
  final List<AiroPresenceLease> _leases;

  @override
  Future<List<AiroPresenceLease>> activeLeases({required DateTime now}) async {
    return List.unmodifiable(
      _leases.where((lease) => !lease.isExpired(now)).toList(),
    );
  }

  @override
  Future<AiroPresenceLease?> expireLease({
    required AiroDeviceStableValue leaseId,
    required DateTime now,
  }) async {
    final index = _leases.indexWhere((lease) => lease.leaseId == leaseId);
    if (index < 0) return null;
    final expired = _leases[index].copyWith(
      status: AiroPresenceStatus.offline,
      lifecycle: AiroNodeLifecycleState.offline,
      expiresAt: now,
    );
    _leases[index] = expired;
    return expired;
  }

  @override
  Future<AiroPresenceDecision> recordHeartbeat({
    required AiroPresenceHeartbeat heartbeat,
    required DateTime now,
  }) async {
    final leaseIndex = _leases.indexWhere(
      (lease) => lease.leaseId == heartbeat.leaseId,
    );
    final deviceRecord = _devices.where(
      (device) => device.deviceId == heartbeat.deviceId,
    );
    final decision = policy.evaluate(
      heartbeat: heartbeat,
      now: now,
      currentLease: leaseIndex >= 0 ? _leases[leaseIndex] : null,
      deviceRecord: deviceRecord.isEmpty ? null : deviceRecord.first,
    );
    if (decision.accepted) {
      if (leaseIndex >= 0) {
        _leases[leaseIndex] = heartbeat.toLease();
      } else {
        _leases.add(heartbeat.toLease());
      }
    }
    return decision;
  }
}
