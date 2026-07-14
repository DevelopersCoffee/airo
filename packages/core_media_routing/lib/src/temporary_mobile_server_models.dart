import 'dart:async';

import 'package:equatable/equatable.dart';

import 'media_location_models.dart';

const String kAiroTemporaryMobileServerSchemaVersion = '1.0.0';

enum AiroTemporaryMobileServerCapability {
  lanOnly('lan_only'),
  rangeRequests('range_requests'),
  probeRequests('head_probe_requests'),
  entityValidation('entity_validation'),
  autoShutdownOnExpiry('auto_shutdown_on_expiry'),
  idleShutdown('idle_shutdown');

  const AiroTemporaryMobileServerCapability(this.stableId);

  final String stableId;
}

enum AiroTemporaryMobileThermalState {
  normal('normal'),
  warm('warm'),
  hot('hot'),
  critical('critical');

  const AiroTemporaryMobileThermalState(this.stableId);

  final String stableId;
}

enum AiroTemporaryMobileServerValidationCode {
  accepted('accepted'),
  serverUnavailable('server_unavailable'),
  expired('expired'),
  idleTimeoutExceeded('idle_timeout_exceeded'),
  localNetworkRequired('local_network_required'),
  trustedReceiverRequired('trusted_receiver_required'),
  receiverNotAllowed('receiver_not_allowed'),
  grantAudienceMismatch('grant_audience_mismatch'),
  grantExpired('grant_expired'),
  grantScopeMissing('grant_scope_missing'),
  rangeRequestsRequired('range_requests_required'),
  probeRequestsRequired('head_probe_requests_required'),
  entityValidationRequired('entity_validation_required'),
  autoShutdownRequired('auto_shutdown_required'),
  idleShutdownRequired('idle_shutdown_required'),
  batteryTooLow('battery_too_low'),
  thermalTooHigh('thermal_too_high'),
  concurrentReceiverLimitExceeded('concurrent_receiver_limit_exceeded');

  const AiroTemporaryMobileServerValidationCode(this.stableId);

  final String stableId;
}

class AiroTemporaryMobileServerSnapshot extends Equatable {
  AiroTemporaryMobileServerSnapshot({
    required this.serverId,
    required this.hostNodeId,
    required this.locationId,
    required this.mediaId,
    required this.accessGrant,
    required this.startedAt,
    required this.expiresAt,
    required this.batteryPercent,
    required this.thermalState,
    required Set<String> allowedReceiverNodeIds,
    required Set<AiroTemporaryMobileServerCapability> capabilities,
    this.lastActivityAt,
    this.idleTimeout = const Duration(minutes: 2),
    this.requiresTrustedReceiverScope = true,
    this.isCharging = false,
    this.activeReceiverCount = 0,
    this.schemaVersion = kAiroTemporaryMobileServerSchemaVersion,
  }) : allowedReceiverNodeIds = Set.unmodifiable(allowedReceiverNodeIds),
       capabilities = Set.unmodifiable(capabilities),
       assert(batteryPercent >= 0 && batteryPercent <= 100),
       assert(activeReceiverCount >= 0);

  final String schemaVersion;
  final String serverId;
  final String hostNodeId;
  final String locationId;
  final String mediaId;
  final AiroRouteAccessGrant accessGrant;
  final DateTime startedAt;
  final DateTime expiresAt;
  final DateTime? lastActivityAt;
  final Duration idleTimeout;
  final Set<String> allowedReceiverNodeIds;
  final Set<AiroTemporaryMobileServerCapability> capabilities;
  final bool requiresTrustedReceiverScope;
  final int batteryPercent;
  final bool isCharging;
  final AiroTemporaryMobileThermalState thermalState;
  final int activeReceiverCount;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  bool isIdleTimedOut(DateTime now) {
    final lastActivity = lastActivityAt ?? startedAt;
    return !now.isBefore(lastActivity.add(idleTimeout));
  }

  bool allowsReceiver(String receiverNodeId) =>
      allowedReceiverNodeIds.contains(receiverNodeId);

  bool supports(AiroTemporaryMobileServerCapability capability) =>
      capabilities.contains(capability);

  @override
  String toString() {
    return 'AiroTemporaryMobileServerSnapshot('
        'serverId: $serverId, '
        'hostNodeId: $hostNodeId, '
        'locationId: $locationId, '
        'mediaId: $mediaId, '
        'grantId: ${accessGrant.grantId}, '
        'audienceNodeId: ${accessGrant.audienceNodeId}, '
        'capabilities: ${capabilities.map((capability) => capability.stableId).toList()}, '
        'expiresAt: $expiresAt, '
        'access: redacted'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    serverId,
    hostNodeId,
    locationId,
    mediaId,
    accessGrant,
    startedAt,
    expiresAt,
    lastActivityAt,
    idleTimeout,
    allowedReceiverNodeIds,
    capabilities,
    requiresTrustedReceiverScope,
    batteryPercent,
    isCharging,
    thermalState,
    activeReceiverCount,
  ];
}

class AiroTemporaryMobileServerValidationContext extends Equatable {
  const AiroTemporaryMobileServerValidationContext({
    required this.now,
    required this.receiverNodeId,
    this.hasLocalNetworkScope = false,
    this.hasTrustedReceiverScope = false,
  });

  final DateTime now;
  final String receiverNodeId;
  final bool hasLocalNetworkScope;
  final bool hasTrustedReceiverScope;

  @override
  List<Object?> get props => [
    now,
    receiverNodeId,
    hasLocalNetworkScope,
    hasTrustedReceiverScope,
  ];
}

class AiroTemporaryMobileServerValidationResult extends Equatable {
  AiroTemporaryMobileServerValidationResult({
    required this.serverId,
    required List<AiroTemporaryMobileServerValidationCode> codes,
  }) : codes = List.unmodifiable(codes);

  final String serverId;
  final List<AiroTemporaryMobileServerValidationCode> codes;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == AiroTemporaryMobileServerValidationCode.accepted;

  @override
  List<Object?> get props => [serverId, codes];
}

class AiroTemporaryMobileServerPolicy {
  const AiroTemporaryMobileServerPolicy({
    this.minBatteryPercent = 20,
    this.maxAllowedThermalState = AiroTemporaryMobileThermalState.warm,
    this.maxConcurrentReceivers = 1,
    this.requiredAccessScopes = const {
      AiroRouteAccessScope.playbackRead,
      AiroRouteAccessScope.rangeRead,
      AiroRouteAccessScope.probeRead,
    },
    this.requiredCapabilities = const {
      AiroTemporaryMobileServerCapability.lanOnly,
      AiroTemporaryMobileServerCapability.rangeRequests,
      AiroTemporaryMobileServerCapability.probeRequests,
      AiroTemporaryMobileServerCapability.entityValidation,
      AiroTemporaryMobileServerCapability.autoShutdownOnExpiry,
      AiroTemporaryMobileServerCapability.idleShutdown,
    },
  });

  final int minBatteryPercent;
  final AiroTemporaryMobileThermalState maxAllowedThermalState;
  final int maxConcurrentReceivers;
  final Set<AiroRouteAccessScope> requiredAccessScopes;
  final Set<AiroTemporaryMobileServerCapability> requiredCapabilities;

  AiroTemporaryMobileServerValidationResult validate({
    required AiroTemporaryMobileServerSnapshot snapshot,
    required AiroTemporaryMobileServerValidationContext context,
  }) {
    final codes = <AiroTemporaryMobileServerValidationCode>[];
    if (snapshot.isExpired(context.now)) {
      codes.add(AiroTemporaryMobileServerValidationCode.expired);
    }
    if (snapshot.isIdleTimedOut(context.now)) {
      codes.add(AiroTemporaryMobileServerValidationCode.idleTimeoutExceeded);
    }
    if (!context.hasLocalNetworkScope ||
        !snapshot.supports(AiroTemporaryMobileServerCapability.lanOnly)) {
      codes.add(AiroTemporaryMobileServerValidationCode.localNetworkRequired);
    }
    if (snapshot.requiresTrustedReceiverScope &&
        !context.hasTrustedReceiverScope) {
      codes.add(
        AiroTemporaryMobileServerValidationCode.trustedReceiverRequired,
      );
    }
    if (!snapshot.allowsReceiver(context.receiverNodeId)) {
      codes.add(AiroTemporaryMobileServerValidationCode.receiverNotAllowed);
    }
    if (!snapshot.accessGrant.isBoundTo(context.receiverNodeId)) {
      codes.add(AiroTemporaryMobileServerValidationCode.grantAudienceMismatch);
    }
    if (snapshot.accessGrant.isExpired(context.now)) {
      codes.add(AiroTemporaryMobileServerValidationCode.grantExpired);
    }
    if (!snapshot.accessGrant.allowsAll(requiredAccessScopes)) {
      codes.add(AiroTemporaryMobileServerValidationCode.grantScopeMissing);
    }
    _addCapabilityBlockers(snapshot, codes);
    if (!snapshot.isCharging && snapshot.batteryPercent < minBatteryPercent) {
      codes.add(AiroTemporaryMobileServerValidationCode.batteryTooLow);
    }
    if (snapshot.thermalState.index > maxAllowedThermalState.index) {
      codes.add(AiroTemporaryMobileServerValidationCode.thermalTooHigh);
    }
    if (snapshot.activeReceiverCount > maxConcurrentReceivers) {
      codes.add(
        AiroTemporaryMobileServerValidationCode.concurrentReceiverLimitExceeded,
      );
    }

    return AiroTemporaryMobileServerValidationResult(
      serverId: snapshot.serverId,
      codes: codes.isEmpty
          ? const [AiroTemporaryMobileServerValidationCode.accepted]
          : codes,
    );
  }

  void _addCapabilityBlockers(
    AiroTemporaryMobileServerSnapshot snapshot,
    List<AiroTemporaryMobileServerValidationCode> codes,
  ) {
    if (requiredCapabilities.contains(
          AiroTemporaryMobileServerCapability.rangeRequests,
        ) &&
        !snapshot.supports(AiroTemporaryMobileServerCapability.rangeRequests)) {
      codes.add(AiroTemporaryMobileServerValidationCode.rangeRequestsRequired);
    }
    if (requiredCapabilities.contains(
          AiroTemporaryMobileServerCapability.probeRequests,
        ) &&
        !snapshot.supports(AiroTemporaryMobileServerCapability.probeRequests)) {
      codes.add(AiroTemporaryMobileServerValidationCode.probeRequestsRequired);
    }
    if (requiredCapabilities.contains(
          AiroTemporaryMobileServerCapability.entityValidation,
        ) &&
        !snapshot.supports(
          AiroTemporaryMobileServerCapability.entityValidation,
        )) {
      codes.add(
        AiroTemporaryMobileServerValidationCode.entityValidationRequired,
      );
    }
    if (requiredCapabilities.contains(
          AiroTemporaryMobileServerCapability.autoShutdownOnExpiry,
        ) &&
        !snapshot.supports(
          AiroTemporaryMobileServerCapability.autoShutdownOnExpiry,
        )) {
      codes.add(AiroTemporaryMobileServerValidationCode.autoShutdownRequired);
    }
    if (requiredCapabilities.contains(
          AiroTemporaryMobileServerCapability.idleShutdown,
        ) &&
        !snapshot.supports(AiroTemporaryMobileServerCapability.idleShutdown)) {
      codes.add(AiroTemporaryMobileServerValidationCode.idleShutdownRequired);
    }
  }
}

abstract interface class AiroTemporaryMobileServerController {
  FutureOr<AiroTemporaryMobileServerSnapshot?> currentSnapshot();

  FutureOr<AiroTemporaryMobileServerValidationResult> validate(
    AiroTemporaryMobileServerValidationContext context,
  );

  FutureOr<void> shutdown(String serverId);
}

class AiroNoOpTemporaryMobileServerController
    implements AiroTemporaryMobileServerController {
  const AiroNoOpTemporaryMobileServerController();

  @override
  FutureOr<AiroTemporaryMobileServerSnapshot?> currentSnapshot() => null;

  @override
  FutureOr<AiroTemporaryMobileServerValidationResult> validate(
    AiroTemporaryMobileServerValidationContext context,
  ) {
    return AiroTemporaryMobileServerValidationResult(
      serverId: 'none',
      codes: const [AiroTemporaryMobileServerValidationCode.serverUnavailable],
    );
  }

  @override
  FutureOr<void> shutdown(String serverId) {}
}

class AiroFakeTemporaryMobileServerController
    implements AiroTemporaryMobileServerController {
  AiroFakeTemporaryMobileServerController({
    this.snapshot,
    this.policy = const AiroTemporaryMobileServerPolicy(),
  });

  AiroTemporaryMobileServerSnapshot? snapshot;
  final AiroTemporaryMobileServerPolicy policy;
  int shutdownCallCount = 0;

  @override
  FutureOr<AiroTemporaryMobileServerSnapshot?> currentSnapshot() => snapshot;

  @override
  FutureOr<AiroTemporaryMobileServerValidationResult> validate(
    AiroTemporaryMobileServerValidationContext context,
  ) {
    final current = snapshot;
    if (current == null) {
      return AiroTemporaryMobileServerValidationResult(
        serverId: 'none',
        codes: const [
          AiroTemporaryMobileServerValidationCode.serverUnavailable,
        ],
      );
    }
    return policy.validate(snapshot: current, context: context);
  }

  @override
  FutureOr<void> shutdown(String serverId) {
    shutdownCallCount += 1;
    if (snapshot?.serverId == serverId) {
      snapshot = null;
    }
  }
}
