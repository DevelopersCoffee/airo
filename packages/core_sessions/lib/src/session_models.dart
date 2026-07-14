import 'dart:async';

import 'package:core_commands/core_commands.dart';
import 'package:core_media_routing/core_media_routing.dart';
import 'package:core_pairing/core_pairing.dart';
import 'package:core_protocol/core_protocol.dart';
import 'package:equatable/equatable.dart';

const String kAiroSessionSchemaVersion = '1.0.0';

enum AiroPlaybackSessionPhase {
  idle('idle'),
  preparing('preparing'),
  playing('playing'),
  paused('paused'),
  buffering('buffering'),
  seeking('seeking'),
  transferring('transferring'),
  stopped('stopped'),
  completed('completed'),
  failed('failed');

  const AiroPlaybackSessionPhase(this.stableId);

  final String stableId;
}

enum AiroSessionSyncEntityKind {
  playbackSession('playback_session'),
  playbackProgress('playback_progress'),
  controllerMembership('controller_membership'),
  handoff('handoff');

  const AiroSessionSyncEntityKind(this.stableId);

  final String stableId;
}

enum AiroSessionSyncOperation {
  upsert('upsert'),
  delete('delete');

  const AiroSessionSyncOperation(this.stableId);

  final String stableId;
}

enum AiroSessionSyncValidationCode {
  accepted('accepted'),
  expired('expired'),
  unsafePayload('unsafe_payload'),
  staleRevision('stale_revision'),
  conflict('conflict');

  const AiroSessionSyncValidationCode(this.stableId);

  final String stableId;
}

enum AiroSessionMergeCode {
  acceptedLocal('accepted_local'),
  acceptedRemote('accepted_remote'),
  ignoredStale('ignored_stale'),
  conflict('conflict');

  const AiroSessionMergeCode(this.stableId);

  final String stableId;
}

enum AiroHandoffPhase {
  requested('requested'),
  preparing('preparing'),
  ready('ready'),
  committed('committed'),
  aborted('aborted'),
  failed('failed');

  const AiroHandoffPhase(this.stableId);

  final String stableId;
}

enum AiroHandoffPreflightCode {
  accepted('accepted'),
  sourceMissing('source_missing'),
  destinationMissing('destination_missing'),
  sourceStale('source_stale'),
  destinationStale('destination_stale'),
  sourceNotActive('source_not_active'),
  destinationUnavailable('destination_unavailable'),
  trustInsufficient('trust_insufficient'),
  capabilityMissing('capability_missing');

  const AiroHandoffPreflightCode(this.stableId);

  final String stableId;
}

enum AiroSessionPayloadRejectionCode {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value');

  const AiroSessionPayloadRejectionCode(this.stableId);

  final String stableId;
}

enum AiroPlaybackOwnershipOperation {
  pause('pause'),
  resume('resume'),
  seek('seek'),
  stop('stop'),
  volume('volume'),
  audioTrack('audio_track'),
  subtitleTrack('subtitle_track'),
  recovery('recovery'),
  healthReport('health_report'),
  analyticsReport('analytics_report');

  const AiroPlaybackOwnershipOperation(this.stableId);

  final String stableId;
}

enum AiroPlaybackOwnershipTransferCode {
  accepted('accepted'),
  requestExpired('request_expired'),
  ownershipExpired('ownership_expired'),
  currentOwnerMismatch('current_owner_mismatch'),
  staleRevision('stale_revision'),
  requesterUnauthorized('requester_unauthorized');

  const AiroPlaybackOwnershipTransferCode(this.stableId);

  final String stableId;
}

class AiroPlaybackOwnershipSnapshot extends Equatable {
  AiroPlaybackOwnershipSnapshot({
    required this.sessionId,
    required this.ownerNodeId,
    required this.playbackNodeId,
    required this.sourceNodeId,
    required this.routeId,
    required this.routeKind,
    required this.analyticsOwnerNodeId,
    required this.healthReporterNodeId,
    required this.revision,
    required this.capturedAt,
    this.activeControllerNodeId,
    Set<AiroPlaybackOwnershipOperation> controllerGrant = const {},
    this.leaseExpiresAt,
    this.schemaVersion = kAiroSessionSchemaVersion,
  }) : controllerGrant = Set.unmodifiable(controllerGrant);

  final String schemaVersion;
  final String sessionId;
  final String ownerNodeId;
  final String playbackNodeId;
  final String sourceNodeId;
  final String routeId;
  final AiroMediaRouteKind routeKind;
  final String analyticsOwnerNodeId;
  final String healthReporterNodeId;
  final String? activeControllerNodeId;
  final Set<AiroPlaybackOwnershipOperation> controllerGrant;
  final AiroSessionRevision revision;
  final DateTime capturedAt;
  final DateTime? leaseExpiresAt;

  bool isExpired(DateTime now) =>
      leaseExpiresAt != null && !now.isBefore(leaseExpiresAt!);

  bool canPerform({
    required String nodeId,
    required AiroPlaybackOwnershipOperation operation,
    required DateTime now,
  }) {
    if (isExpired(now)) return false;
    if (nodeId == ownerNodeId) return true;
    if (operation == AiroPlaybackOwnershipOperation.analyticsReport &&
        nodeId == analyticsOwnerNodeId) {
      return true;
    }
    if (operation == AiroPlaybackOwnershipOperation.healthReport &&
        nodeId == healthReporterNodeId) {
      return true;
    }
    return nodeId == activeControllerNodeId &&
        controllerGrant.contains(operation);
  }

  AiroPlaybackOwnershipSnapshot copyWith({
    String? ownerNodeId,
    String? playbackNodeId,
    String? sourceNodeId,
    String? routeId,
    AiroMediaRouteKind? routeKind,
    String? analyticsOwnerNodeId,
    String? healthReporterNodeId,
    String? activeControllerNodeId,
    Set<AiroPlaybackOwnershipOperation>? controllerGrant,
    AiroSessionRevision? revision,
    DateTime? capturedAt,
    DateTime? leaseExpiresAt,
  }) {
    return AiroPlaybackOwnershipSnapshot(
      sessionId: sessionId,
      ownerNodeId: ownerNodeId ?? this.ownerNodeId,
      playbackNodeId: playbackNodeId ?? this.playbackNodeId,
      sourceNodeId: sourceNodeId ?? this.sourceNodeId,
      routeId: routeId ?? this.routeId,
      routeKind: routeKind ?? this.routeKind,
      analyticsOwnerNodeId: analyticsOwnerNodeId ?? this.analyticsOwnerNodeId,
      healthReporterNodeId: healthReporterNodeId ?? this.healthReporterNodeId,
      activeControllerNodeId:
          activeControllerNodeId ?? this.activeControllerNodeId,
      controllerGrant: controllerGrant ?? this.controllerGrant,
      revision: revision ?? this.revision,
      capturedAt: capturedAt ?? this.capturedAt,
      leaseExpiresAt: leaseExpiresAt ?? this.leaseExpiresAt,
      schemaVersion: schemaVersion,
    );
  }

  @override
  String toString() {
    return 'AiroPlaybackOwnershipSnapshot('
        'sessionId: $sessionId, '
        'ownerNodeId: $ownerNodeId, '
        'playbackNodeId: $playbackNodeId, '
        'sourceNodeId: $sourceNodeId, '
        'routeId: $routeId, '
        'routeKind: ${routeKind.stableId}, '
        'analyticsOwnerNodeId: $analyticsOwnerNodeId, '
        'healthReporterNodeId: $healthReporterNodeId, '
        'activeControllerNodeId: $activeControllerNodeId, '
        'controllerGrant: ${controllerGrant.map((operation) => operation.stableId).toList()}, '
        'revision: ${revision.value}, '
        'leaseExpiresAt: $leaseExpiresAt'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    sessionId,
    ownerNodeId,
    playbackNodeId,
    sourceNodeId,
    routeId,
    routeKind,
    analyticsOwnerNodeId,
    healthReporterNodeId,
    activeControllerNodeId,
    controllerGrant,
    revision,
    capturedAt,
    leaseExpiresAt,
  ];
}

class AiroPlaybackOwnershipTransferRequest extends Equatable {
  AiroPlaybackOwnershipTransferRequest({
    required this.transferId,
    required this.sessionId,
    required this.currentOwnerNodeId,
    required this.newOwnerNodeId,
    required this.requestedByNodeId,
    required this.baseRevision,
    required this.issuedAt,
    required this.expiresAt,
    this.analyticsOwnerNodeId,
    this.healthReporterNodeId,
    this.activeControllerNodeId,
    Set<AiroPlaybackOwnershipOperation> controllerGrant = const {},
    this.schemaVersion = kAiroSessionSchemaVersion,
  }) : controllerGrant = Set.unmodifiable(controllerGrant);

  final String schemaVersion;
  final String transferId;
  final String sessionId;
  final String currentOwnerNodeId;
  final String newOwnerNodeId;
  final String requestedByNodeId;
  final int baseRevision;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String? analyticsOwnerNodeId;
  final String? healthReporterNodeId;
  final String? activeControllerNodeId;
  final Set<AiroPlaybackOwnershipOperation> controllerGrant;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  @override
  List<Object?> get props => [
    schemaVersion,
    transferId,
    sessionId,
    currentOwnerNodeId,
    newOwnerNodeId,
    requestedByNodeId,
    baseRevision,
    issuedAt,
    expiresAt,
    analyticsOwnerNodeId,
    healthReporterNodeId,
    activeControllerNodeId,
    controllerGrant,
  ];
}

class AiroPlaybackOwnershipTransferResult extends Equatable {
  const AiroPlaybackOwnershipTransferResult({
    required this.code,
    required this.snapshot,
  });

  final AiroPlaybackOwnershipTransferCode code;
  final AiroPlaybackOwnershipSnapshot snapshot;

  bool get accepted => code == AiroPlaybackOwnershipTransferCode.accepted;

  @override
  List<Object?> get props => [code, snapshot];
}

class AiroPlaybackOwnershipPolicy {
  const AiroPlaybackOwnershipPolicy();

  AiroPlaybackOwnershipTransferResult transfer({
    required AiroPlaybackOwnershipSnapshot current,
    required AiroPlaybackOwnershipTransferRequest request,
    required DateTime now,
  }) {
    if (request.isExpired(now)) {
      return AiroPlaybackOwnershipTransferResult(
        code: AiroPlaybackOwnershipTransferCode.requestExpired,
        snapshot: current,
      );
    }
    if (current.isExpired(now)) {
      return AiroPlaybackOwnershipTransferResult(
        code: AiroPlaybackOwnershipTransferCode.ownershipExpired,
        snapshot: current,
      );
    }
    if (request.currentOwnerNodeId != current.ownerNodeId) {
      return AiroPlaybackOwnershipTransferResult(
        code: AiroPlaybackOwnershipTransferCode.currentOwnerMismatch,
        snapshot: current,
      );
    }
    if (request.baseRevision != current.revision.value) {
      return AiroPlaybackOwnershipTransferResult(
        code: AiroPlaybackOwnershipTransferCode.staleRevision,
        snapshot: current,
      );
    }
    if (request.requestedByNodeId != current.ownerNodeId &&
        request.requestedByNodeId != current.activeControllerNodeId) {
      return AiroPlaybackOwnershipTransferResult(
        code: AiroPlaybackOwnershipTransferCode.requesterUnauthorized,
        snapshot: current,
      );
    }

    return AiroPlaybackOwnershipTransferResult(
      code: AiroPlaybackOwnershipTransferCode.accepted,
      snapshot: current.copyWith(
        ownerNodeId: request.newOwnerNodeId,
        analyticsOwnerNodeId:
            request.analyticsOwnerNodeId ?? request.newOwnerNodeId,
        healthReporterNodeId:
            request.healthReporterNodeId ?? request.newOwnerNodeId,
        activeControllerNodeId: request.activeControllerNodeId,
        controllerGrant: request.controllerGrant,
        revision: AiroSessionRevision(
          value: current.revision.value + 1,
          updatedAt: now,
          reporterNodeId: request.requestedByNodeId,
        ),
        capturedAt: now,
      ),
    );
  }
}

class AiroSessionRevision extends Equatable
    implements Comparable<AiroSessionRevision> {
  const AiroSessionRevision({
    required this.value,
    required this.updatedAt,
    required this.reporterNodeId,
  });

  final int value;
  final DateTime updatedAt;
  final String reporterNodeId;

  bool isNewerThan(AiroSessionRevision other) {
    if (value != other.value) return value > other.value;
    if (updatedAt != other.updatedAt) return updatedAt.isAfter(other.updatedAt);
    return false;
  }

  bool conflictsWith(AiroSessionRevision other) {
    return value == other.value &&
        updatedAt == other.updatedAt &&
        reporterNodeId != other.reporterNodeId;
  }

  @override
  int compareTo(AiroSessionRevision other) {
    if (isNewerThan(other)) return 1;
    if (other.isNewerThan(this)) return -1;
    if (conflictsWith(other)) return 0;
    return reporterNodeId.compareTo(other.reporterNodeId);
  }

  @override
  List<Object?> get props => [value, updatedAt, reporterNodeId];
}

class AiroSessionPayloadHandle extends Equatable {
  const AiroSessionPayloadHandle._(this.value);

  factory AiroSessionPayloadHandle.redacted(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return AiroSessionPayloadHandle._(value.trim());
  }

  final String value;

  static AiroSessionPayloadRejectionCode? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return AiroSessionPayloadRejectionCode.empty;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroSessionPayloadRejectionCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroSessionPayloadRejectionCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroSessionPayloadRejectionCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroSessionPayloadRejectionCode.credentialLikeValue;
    }

    return null;
  }

  @override
  String toString() => 'AiroSessionPayloadHandle(redacted)';

  @override
  List<Object?> get props => [value];
}

class AiroSessionCommandReference extends Equatable {
  const AiroSessionCommandReference({
    required this.commandId,
    required this.sessionId,
    required this.senderNodeId,
    required this.targetNodeId,
    required this.issuedAt,
  });

  factory AiroSessionCommandReference.fromEnvelope(
    AiroCommandEnvelope envelope,
  ) {
    return AiroSessionCommandReference(
      commandId: envelope.commandId,
      sessionId: envelope.sessionId,
      senderNodeId: envelope.senderNodeId,
      targetNodeId: envelope.targetNodeId,
      issuedAt: envelope.issuedAt,
    );
  }

  final String commandId;
  final String sessionId;
  final String senderNodeId;
  final String targetNodeId;
  final DateTime issuedAt;

  @override
  List<Object?> get props => [
    commandId,
    sessionId,
    senderNodeId,
    targetNodeId,
    issuedAt,
  ];
}

class AiroDesiredPlaybackState extends Equatable {
  const AiroDesiredPlaybackState({
    required this.phase,
    required this.position,
    required this.updatedByControllerNodeId,
    required this.updatedAt,
    this.commandReference,
  });

  final AiroPlaybackSessionPhase phase;
  final Duration position;
  final String updatedByControllerNodeId;
  final DateTime updatedAt;
  final AiroSessionCommandReference? commandReference;

  @override
  List<Object?> get props => [
    phase,
    position,
    updatedByControllerNodeId,
    updatedAt,
    commandReference,
  ];
}

class AiroActualPlaybackState extends Equatable {
  const AiroActualPlaybackState({
    required this.phase,
    required this.position,
    required this.reportedByReceiverNodeId,
    required this.reportedAt,
    this.bufferedPosition,
    this.playbackSpeed = 1,
  });

  final AiroPlaybackSessionPhase phase;
  final Duration position;
  final String reportedByReceiverNodeId;
  final DateTime reportedAt;
  final Duration? bufferedPosition;
  final double playbackSpeed;

  @override
  List<Object?> get props => [
    phase,
    position,
    reportedByReceiverNodeId,
    reportedAt,
    bufferedPosition,
    playbackSpeed,
  ];
}

class AiroPlaybackSessionSnapshot extends Equatable {
  const AiroPlaybackSessionSnapshot({
    required this.sessionId,
    required this.receiverNodeId,
    required this.revision,
    required this.actual,
    required this.capturedAt,
    this.activeControllerNodeId,
    this.desired,
    this.mediaHandle,
    this.expiresAt,
    this.schemaVersion = kAiroSessionSchemaVersion,
  });

  final String schemaVersion;
  final String sessionId;
  final String receiverNodeId;
  final String? activeControllerNodeId;
  final AiroSessionRevision revision;
  final AiroActualPlaybackState actual;
  final AiroDesiredPlaybackState? desired;
  final AiroSessionPayloadHandle? mediaHandle;
  final DateTime capturedAt;
  final DateTime? expiresAt;

  bool isExpired(DateTime now) =>
      expiresAt != null && !now.isBefore(expiresAt!);

  @override
  String toString() {
    return 'AiroPlaybackSessionSnapshot('
        'sessionId: $sessionId, '
        'receiverNodeId: $receiverNodeId, '
        'activeControllerNodeId: $activeControllerNodeId, '
        'revision: ${revision.value}, '
        'actualPhase: ${actual.phase.stableId}, '
        'desiredPhase: ${desired?.phase.stableId}, '
        'mediaHandle: ${mediaHandle == null ? null : 'redacted'}, '
        'capturedAt: $capturedAt, '
        'expiresAt: $expiresAt'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    sessionId,
    receiverNodeId,
    activeControllerNodeId,
    revision,
    actual,
    desired,
    mediaHandle,
    capturedAt,
    expiresAt,
  ];
}

class AiroSessionMergeResult extends Equatable {
  const AiroSessionMergeResult({required this.code, required this.snapshot});

  final AiroSessionMergeCode code;
  final AiroPlaybackSessionSnapshot snapshot;

  @override
  List<Object?> get props => [code, snapshot];
}

class AiroSessionConflictPolicy {
  const AiroSessionConflictPolicy();

  AiroSessionMergeResult merge({
    required AiroPlaybackSessionSnapshot current,
    required AiroPlaybackSessionSnapshot incoming,
  }) {
    if (incoming.revision.conflictsWith(current.revision)) {
      return AiroSessionMergeResult(
        code: AiroSessionMergeCode.conflict,
        snapshot: current,
      );
    }
    if (incoming.revision.isNewerThan(current.revision)) {
      return AiroSessionMergeResult(
        code: AiroSessionMergeCode.acceptedRemote,
        snapshot: incoming,
      );
    }
    if (current.revision.isNewerThan(incoming.revision)) {
      return AiroSessionMergeResult(
        code: AiroSessionMergeCode.ignoredStale,
        snapshot: current,
      );
    }
    return AiroSessionMergeResult(
      code: AiroSessionMergeCode.acceptedLocal,
      snapshot: current,
    );
  }
}

class AiroSessionSyncDelta extends Equatable {
  const AiroSessionSyncDelta({
    required this.deltaId,
    required this.sessionId,
    required this.entityKind,
    required this.operation,
    required this.revision,
    required this.payloadHandle,
    required this.issuedAt,
    required this.expiresAt,
    this.commandId,
    this.schemaVersion = kAiroSessionSchemaVersion,
  });

  final String schemaVersion;
  final String deltaId;
  final String sessionId;
  final AiroSessionSyncEntityKind entityKind;
  final AiroSessionSyncOperation operation;
  final AiroSessionRevision revision;
  final AiroSessionPayloadHandle payloadHandle;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String? commandId;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  @override
  String toString() {
    return 'AiroSessionSyncDelta('
        'deltaId: $deltaId, '
        'sessionId: $sessionId, '
        'entityKind: ${entityKind.stableId}, '
        'operation: ${operation.stableId}, '
        'revision: ${revision.value}, '
        'payloadHandle: redacted, '
        'issuedAt: $issuedAt, '
        'expiresAt: $expiresAt'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    deltaId,
    sessionId,
    entityKind,
    operation,
    revision,
    payloadHandle,
    issuedAt,
    expiresAt,
    commandId,
  ];
}

class AiroSessionSyncValidationResult extends Equatable {
  AiroSessionSyncValidationResult({
    required List<AiroSessionSyncValidationCode> codes,
  }) : codes = List.unmodifiable(codes);

  final List<AiroSessionSyncValidationCode> codes;

  bool get accepted => codes.isEmpty;

  bool has(AiroSessionSyncValidationCode code) => codes.contains(code);

  @override
  List<Object?> get props => [codes];
}

class AiroSessionSyncPolicy {
  const AiroSessionSyncPolicy();

  AiroSessionSyncValidationResult validate({
    required AiroSessionSyncDelta delta,
    required DateTime now,
    AiroSessionRevision? currentRevision,
  }) {
    final codes = <AiroSessionSyncValidationCode>[];
    if (delta.isExpired(now)) {
      codes.add(AiroSessionSyncValidationCode.expired);
    }
    if (AiroSessionPayloadHandle.validate(delta.payloadHandle.value) != null) {
      codes.add(AiroSessionSyncValidationCode.unsafePayload);
    }
    if (currentRevision != null) {
      if (delta.revision.conflictsWith(currentRevision)) {
        codes.add(AiroSessionSyncValidationCode.conflict);
      } else if (currentRevision.isNewerThan(delta.revision)) {
        codes.add(AiroSessionSyncValidationCode.staleRevision);
      }
    }
    return AiroSessionSyncValidationResult(codes: codes);
  }
}

class AiroHandoffRequest extends Equatable {
  const AiroHandoffRequest({
    required this.handoffId,
    required this.sessionId,
    required this.sourceReceiverNodeId,
    required this.destinationReceiverNodeId,
    required this.controllerNodeId,
    required this.requiredScope,
    required this.issuedAt,
    required this.expiresAt,
    this.expectedRevision,
    this.commandId,
    this.schemaVersion = kAiroSessionSchemaVersion,
  });

  final String schemaVersion;
  final String handoffId;
  final String sessionId;
  final String sourceReceiverNodeId;
  final String destinationReceiverNodeId;
  final String controllerNodeId;
  final AiroPairingScope requiredScope;
  final AiroSessionRevision? expectedRevision;
  final String? commandId;
  final DateTime issuedAt;
  final DateTime expiresAt;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  @override
  List<Object?> get props => [
    schemaVersion,
    handoffId,
    sessionId,
    sourceReceiverNodeId,
    destinationReceiverNodeId,
    controllerNodeId,
    requiredScope,
    expectedRevision,
    commandId,
    issuedAt,
    expiresAt,
  ];
}

class AiroHandoffRecord extends Equatable {
  const AiroHandoffRecord({
    required this.request,
    required this.phase,
    required this.updatedAt,
    this.reasonCode,
  });

  final AiroHandoffRequest request;
  final AiroHandoffPhase phase;
  final DateTime updatedAt;
  final String? reasonCode;

  @override
  List<Object?> get props => [request, phase, updatedAt, reasonCode];
}

class AiroHandoffPreflightResult extends Equatable {
  AiroHandoffPreflightResult({required List<AiroHandoffPreflightCode> codes})
    : codes = List.unmodifiable(codes);

  final List<AiroHandoffPreflightCode> codes;

  bool get accepted => codes.isEmpty;

  bool has(AiroHandoffPreflightCode code) => codes.contains(code);

  @override
  List<Object?> get props => [codes];
}

class AiroHandoffPreflightPolicy {
  AiroHandoffPreflightPolicy({
    required Set<AiroNodeCapability> requiredDestinationCapabilities,
    this.maxSnapshotAge = const Duration(seconds: 10),
    this.minimumTrustLevel = AiroTrustedDeviceTrustLevel.paired,
  }) : requiredDestinationCapabilities = Set.unmodifiable(
         requiredDestinationCapabilities,
       );

  final Set<AiroNodeCapability> requiredDestinationCapabilities;
  final Duration maxSnapshotAge;
  final AiroTrustedDeviceTrustLevel minimumTrustLevel;

  AiroHandoffPreflightResult evaluate({
    required AiroHandoffRequest request,
    required DateTime now,
    AiroPlaybackSessionSnapshot? sourceSnapshot,
    AiroPlaybackSessionSnapshot? destinationSnapshot,
    AiroTrustedDeviceRecord? trustRecord,
    AiroNodeCapabilityAdvertisement? destinationAdvertisement,
  }) {
    final codes = <AiroHandoffPreflightCode>[];
    if (sourceSnapshot == null) {
      codes.add(AiroHandoffPreflightCode.sourceMissing);
    } else {
      if (sourceSnapshot.isExpired(now) ||
          now.difference(sourceSnapshot.capturedAt) > maxSnapshotAge) {
        codes.add(AiroHandoffPreflightCode.sourceStale);
      }
      if (!_activeSourcePhases.contains(sourceSnapshot.actual.phase)) {
        codes.add(AiroHandoffPreflightCode.sourceNotActive);
      }
    }

    if (destinationSnapshot == null) {
      codes.add(AiroHandoffPreflightCode.destinationMissing);
    } else if (destinationSnapshot.isExpired(now) ||
        now.difference(destinationSnapshot.capturedAt) > maxSnapshotAge) {
      codes.add(AiroHandoffPreflightCode.destinationStale);
    }

    if (destinationAdvertisement == null ||
        destinationAdvertisement.isExpired(now) ||
        !destinationAdvertisement.lifecycle.canNegotiate) {
      codes.add(AiroHandoffPreflightCode.destinationUnavailable);
    } else if (!destinationAdvertisement.advertisesAll(
      requiredDestinationCapabilities,
    )) {
      codes.add(AiroHandoffPreflightCode.capabilityMissing);
    }

    if (trustRecord == null ||
        !trustRecord.trustLevel.satisfies(minimumTrustLevel) ||
        !trustRecord.allows(requiredScope: request.requiredScope, now: now)) {
      codes.add(AiroHandoffPreflightCode.trustInsufficient);
    }

    return AiroHandoffPreflightResult(codes: codes);
  }

  static const Set<AiroPlaybackSessionPhase> _activeSourcePhases = {
    AiroPlaybackSessionPhase.playing,
    AiroPlaybackSessionPhase.paused,
    AiroPlaybackSessionPhase.buffering,
    AiroPlaybackSessionPhase.seeking,
  };
}

abstract class AiroPlaybackSessionRepository {
  Stream<AiroPlaybackSessionSnapshot> get snapshots;

  Future<AiroPlaybackSessionSnapshot?> getById(String sessionId);

  Future<AiroSessionMergeResult> upsert(AiroPlaybackSessionSnapshot snapshot);

  Future<void> delete(String sessionId);
}

class AiroNoOpPlaybackSessionRepository
    implements AiroPlaybackSessionRepository {
  const AiroNoOpPlaybackSessionRepository();

  @override
  Stream<AiroPlaybackSessionSnapshot> get snapshots => const Stream.empty();

  @override
  Future<AiroPlaybackSessionSnapshot?> getById(String sessionId) async => null;

  @override
  Future<AiroSessionMergeResult> upsert(
    AiroPlaybackSessionSnapshot snapshot,
  ) async {
    return AiroSessionMergeResult(
      code: AiroSessionMergeCode.ignoredStale,
      snapshot: snapshot,
    );
  }

  @override
  Future<void> delete(String sessionId) async {}
}

class AiroFakePlaybackSessionRepository
    implements AiroPlaybackSessionRepository {
  AiroFakePlaybackSessionRepository({
    this.conflictPolicy = const AiroSessionConflictPolicy(),
  });

  final AiroSessionConflictPolicy conflictPolicy;
  final StreamController<AiroPlaybackSessionSnapshot> _controller =
      StreamController<AiroPlaybackSessionSnapshot>.broadcast();
  final Map<String, AiroPlaybackSessionSnapshot> _snapshots = {};

  @override
  Stream<AiroPlaybackSessionSnapshot> get snapshots => _controller.stream;

  @override
  Future<AiroPlaybackSessionSnapshot?> getById(String sessionId) async {
    return _snapshots[sessionId];
  }

  @override
  Future<AiroSessionMergeResult> upsert(
    AiroPlaybackSessionSnapshot snapshot,
  ) async {
    final current = _snapshots[snapshot.sessionId];
    final result = current == null
        ? AiroSessionMergeResult(
            code: AiroSessionMergeCode.acceptedRemote,
            snapshot: snapshot,
          )
        : conflictPolicy.merge(current: current, incoming: snapshot);
    if (result.code == AiroSessionMergeCode.acceptedRemote ||
        result.code == AiroSessionMergeCode.acceptedLocal) {
      _snapshots[snapshot.sessionId] = result.snapshot;
      _controller.add(result.snapshot);
    }
    return result;
  }

  @override
  Future<void> delete(String sessionId) async {
    _snapshots.remove(sessionId);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
