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

enum AiroUniversalSessionMemberRole {
  receiver('receiver'),
  activeController('active_controller'),
  controller('controller'),
  observer('observer'),
  orchestrationService('orchestration_service');

  const AiroUniversalSessionMemberRole(this.stableId);

  final String stableId;
}

enum AiroUniversalSessionPermission {
  reportActualState('report_actual_state'),
  requestDesiredState('request_desired_state'),
  recoverSnapshot('recover_snapshot'),
  manageMembership('manage_membership'),
  transferSession('transfer_session');

  const AiroUniversalSessionPermission(this.stableId);

  final String stableId;
}

enum AiroUniversalSessionDecisionAction {
  accept('accept'),
  deny('deny'),
  recover('recover'),
  noOp('no_op');

  const AiroUniversalSessionDecisionAction(this.stableId);

  final String stableId;
}

enum AiroUniversalSessionCode {
  accepted('accepted'),
  expiredSnapshot('expired_snapshot'),
  unsafePayload('unsafe_payload'),
  staleRevision('stale_revision'),
  revisionConflict('revision_conflict'),
  receiverMismatch('receiver_mismatch'),
  missingMember('missing_member'),
  memberExpired('member_expired'),
  memberRevoked('member_revoked'),
  permissionMissing('permission_missing'),
  repositoryUnavailable('repository_unavailable');

  const AiroUniversalSessionCode(this.stableId);

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
    this.duration,
    this.liveOffset,
    this.playbackSpeed = 1,
    this.volume,
    this.audioTrackId,
    this.subtitleTrackId,
  });

  final AiroPlaybackSessionPhase phase;
  final Duration position;
  final String updatedByControllerNodeId;
  final DateTime updatedAt;
  final AiroSessionCommandReference? commandReference;
  final Duration? duration;
  final Duration? liveOffset;
  final double playbackSpeed;
  final double? volume;
  final String? audioTrackId;
  final String? subtitleTrackId;

  @override
  List<Object?> get props => [
    phase,
    position,
    updatedByControllerNodeId,
    updatedAt,
    commandReference,
    duration,
    liveOffset,
    playbackSpeed,
    volume,
    audioTrackId,
    subtitleTrackId,
  ];
}

class AiroActualPlaybackState extends Equatable {
  const AiroActualPlaybackState({
    required this.phase,
    required this.position,
    required this.reportedByReceiverNodeId,
    required this.reportedAt,
    this.bufferedPosition,
    this.duration,
    this.liveOffset,
    this.playbackSpeed = 1,
    this.volume,
    this.audioTrackId,
    this.subtitleTrackId,
  });

  final AiroPlaybackSessionPhase phase;
  final Duration position;
  final String reportedByReceiverNodeId;
  final DateTime reportedAt;
  final Duration? bufferedPosition;
  final Duration? duration;
  final Duration? liveOffset;
  final double playbackSpeed;
  final double? volume;
  final String? audioTrackId;
  final String? subtitleTrackId;

  @override
  List<Object?> get props => [
    phase,
    position,
    reportedByReceiverNodeId,
    reportedAt,
    bufferedPosition,
    duration,
    liveOffset,
    playbackSpeed,
    volume,
    audioTrackId,
    subtitleTrackId,
  ];
}

class AiroUniversalSessionMember extends Equatable {
  AiroUniversalSessionMember({
    required this.memberId,
    required this.nodeId,
    required this.deviceId,
    required this.role,
    required Set<AiroUniversalSessionPermission> permissions,
    required this.joinedAt,
    this.expiresAt,
    this.revokedAt,
    this.schemaVersion = kAiroSessionSchemaVersion,
  }) : permissions = Set.unmodifiable(permissions);

  final String schemaVersion;
  final String memberId;
  final String nodeId;
  final String deviceId;
  final AiroUniversalSessionMemberRole role;
  final Set<AiroUniversalSessionPermission> permissions;
  final DateTime joinedAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;

  bool isExpired(DateTime now) =>
      expiresAt != null && !now.isBefore(expiresAt!);

  bool isRevoked(DateTime now) =>
      revokedAt != null && !now.isBefore(revokedAt!);

  bool allows({
    required AiroUniversalSessionPermission permission,
    required DateTime now,
  }) {
    return !isExpired(now) &&
        !isRevoked(now) &&
        permissions.contains(permission);
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    memberId,
    nodeId,
    deviceId,
    role,
    permissions,
    joinedAt,
    expiresAt,
    revokedAt,
  ];
}

class AiroUniversalPlaybackSessionSnapshot extends Equatable {
  AiroUniversalPlaybackSessionSnapshot({
    required this.sessionId,
    required this.activeReceiverNodeId,
    required this.revision,
    required this.actual,
    required Set<AiroUniversalSessionMember> members,
    required this.capturedAt,
    this.activeControllerNodeId,
    this.desired,
    this.mediaHandle,
    this.routeId,
    this.routeKind = AiroMediaRouteKind.cloudCommandOnly,
    this.expiresAt,
    this.schemaVersion = kAiroSessionSchemaVersion,
  }) : members = Set.unmodifiable(members);

  final String schemaVersion;
  final String sessionId;
  final String activeReceiverNodeId;
  final String? activeControllerNodeId;
  final AiroSessionRevision revision;
  final AiroActualPlaybackState actual;
  final AiroDesiredPlaybackState? desired;
  final AiroSessionPayloadHandle? mediaHandle;
  final String? routeId;
  final AiroMediaRouteKind routeKind;
  final Set<AiroUniversalSessionMember> members;
  final DateTime capturedAt;
  final DateTime? expiresAt;

  bool isExpired(DateTime now) =>
      expiresAt != null && !now.isBefore(expiresAt!);

  bool get isReceiverAuthoritative =>
      actual.reportedByReceiverNodeId == activeReceiverNodeId &&
      revision.reporterNodeId == activeReceiverNodeId;

  AiroUniversalSessionMember? memberFor(String nodeId) {
    for (final member in members) {
      if (member.nodeId == nodeId) return member;
    }
    return null;
  }

  bool canMemberPerform({
    required String nodeId,
    required AiroUniversalSessionPermission permission,
    required DateTime now,
  }) {
    final member = memberFor(nodeId);
    return member != null && member.allows(permission: permission, now: now);
  }

  bool get hasStaleDesiredState {
    final desiredState = desired;
    return desiredState != null &&
        !desiredState.updatedAt.isAfter(actual.reportedAt);
  }

  AiroUniversalPlaybackSessionSnapshot reconciled() {
    if (!hasStaleDesiredState) return this;
    return copyWith(clearDesired: true);
  }

  AiroUniversalPlaybackSessionSnapshot copyWith({
    String? activeReceiverNodeId,
    String? activeControllerNodeId,
    AiroSessionRevision? revision,
    AiroActualPlaybackState? actual,
    AiroDesiredPlaybackState? desired,
    bool clearDesired = false,
    AiroSessionPayloadHandle? mediaHandle,
    String? routeId,
    AiroMediaRouteKind? routeKind,
    Set<AiroUniversalSessionMember>? members,
    DateTime? capturedAt,
    DateTime? expiresAt,
  }) {
    return AiroUniversalPlaybackSessionSnapshot(
      sessionId: sessionId,
      activeReceiverNodeId: activeReceiverNodeId ?? this.activeReceiverNodeId,
      activeControllerNodeId:
          activeControllerNodeId ?? this.activeControllerNodeId,
      revision: revision ?? this.revision,
      actual: actual ?? this.actual,
      desired: clearDesired ? null : desired ?? this.desired,
      mediaHandle: mediaHandle ?? this.mediaHandle,
      routeId: routeId ?? this.routeId,
      routeKind: routeKind ?? this.routeKind,
      members: members ?? this.members,
      capturedAt: capturedAt ?? this.capturedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'sessionId': sessionId,
      'activeReceiverNodeId': activeReceiverNodeId,
      'activeControllerNodeId': activeControllerNodeId,
      'revision': revision.value,
      'revisionReporterNodeId': revision.reporterNodeId,
      'actualPhase': actual.phase.stableId,
      'actualPositionMs': actual.position.inMilliseconds,
      'actualLiveOffsetMs': actual.liveOffset?.inMilliseconds,
      'actualRate': actual.playbackSpeed,
      'actualVolume': actual.volume,
      'desiredPhase': desired?.phase.stableId,
      'desiredPositionMs': desired?.position.inMilliseconds,
      'routeKind': routeKind.stableId,
      'routeId': routeId,
      'hasMediaHandle': mediaHandle != null,
      'members': members
          .map(
            (member) => {
              'memberId': member.memberId,
              'nodeId': member.nodeId,
              'deviceId': member.deviceId,
              'role': member.role.stableId,
              'permissions': member.permissions
                  .map((permission) => permission.stableId)
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
      'capturedAt': capturedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'AiroUniversalPlaybackSessionSnapshot('
        'sessionId: $sessionId, '
        'activeReceiverNodeId: $activeReceiverNodeId, '
        'activeControllerNodeId: $activeControllerNodeId, '
        'revision: ${revision.value}, '
        'actualPhase: ${actual.phase.stableId}, '
        'desiredPhase: ${desired?.phase.stableId}, '
        'routeKind: ${routeKind.stableId}, '
        'mediaHandle: ${mediaHandle == null ? null : 'redacted'}, '
        'capturedAt: $capturedAt, '
        'expiresAt: $expiresAt'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    sessionId,
    activeReceiverNodeId,
    activeControllerNodeId,
    revision,
    actual,
    desired,
    mediaHandle,
    routeId,
    routeKind,
    members,
    capturedAt,
    expiresAt,
  ];
}

class AiroUniversalSessionDecision extends Equatable {
  AiroUniversalSessionDecision({
    required this.action,
    required Iterable<AiroUniversalSessionCode> codes,
    required this.snapshot,
  }) : codes = List.unmodifiable(codes);

  final AiroUniversalSessionDecisionAction action;
  final List<AiroUniversalSessionCode> codes;
  final AiroUniversalPlaybackSessionSnapshot snapshot;

  bool get accepted =>
      action == AiroUniversalSessionDecisionAction.accept &&
      codes.length == 1 &&
      codes.single == AiroUniversalSessionCode.accepted;

  Map<String, Object?> toDiagnosticMap() {
    return {
      'sessionId': snapshot.sessionId,
      'action': action.stableId,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
      'revision': snapshot.revision.value,
      'reporterNodeId': snapshot.revision.reporterNodeId,
    };
  }

  @override
  List<Object?> get props => [action, codes, snapshot];
}

class AiroUniversalPlaybackSessionPolicy extends Equatable {
  const AiroUniversalPlaybackSessionPolicy();

  AiroUniversalSessionDecision evaluateIncoming({
    required AiroUniversalPlaybackSessionSnapshot incoming,
    required DateTime now,
    AiroUniversalPlaybackSessionSnapshot? current,
    AiroUniversalSessionPermission requiredReporterPermission =
        AiroUniversalSessionPermission.reportActualState,
  }) {
    final codes = <AiroUniversalSessionCode>[];
    if (incoming.isExpired(now)) {
      codes.add(AiroUniversalSessionCode.expiredSnapshot);
    }
    if (incoming.mediaHandle != null &&
        AiroSessionPayloadHandle.validate(incoming.mediaHandle!.value) !=
            null) {
      codes.add(AiroUniversalSessionCode.unsafePayload);
    }
    if (!incoming.isReceiverAuthoritative) {
      codes.add(AiroUniversalSessionCode.receiverMismatch);
    }

    final reporter = incoming.memberFor(incoming.revision.reporterNodeId);
    if (reporter == null) {
      codes.add(AiroUniversalSessionCode.missingMember);
    } else {
      if (reporter.isExpired(now)) {
        codes.add(AiroUniversalSessionCode.memberExpired);
      }
      if (reporter.isRevoked(now)) {
        codes.add(AiroUniversalSessionCode.memberRevoked);
      }
      if (!reporter.permissions.contains(requiredReporterPermission)) {
        codes.add(AiroUniversalSessionCode.permissionMissing);
      }
    }

    if (current != null) {
      if (incoming.revision.conflictsWith(current.revision)) {
        codes.add(AiroUniversalSessionCode.revisionConflict);
      } else if (current.revision.isNewerThan(incoming.revision)) {
        codes.add(AiroUniversalSessionCode.staleRevision);
      }
    }

    final acceptedSnapshot = incoming.reconciled();
    return AiroUniversalSessionDecision(
      action: codes.isEmpty
          ? AiroUniversalSessionDecisionAction.accept
          : AiroUniversalSessionDecisionAction.deny,
      codes: codes.isEmpty ? const [AiroUniversalSessionCode.accepted] : codes,
      snapshot: codes.isEmpty ? acceptedSnapshot : current ?? incoming,
    );
  }

  @override
  List<Object?> get props => const [];
}

abstract interface class AiroUniversalPlaybackSessionRepository {
  Future<AiroUniversalSessionDecision> upsert(
    AiroUniversalPlaybackSessionSnapshot snapshot, {
    required DateTime now,
  });

  Future<AiroUniversalPlaybackSessionSnapshot?> recoverLatest({
    required String sessionId,
    required DateTime now,
  });
}

class AiroNoOpUniversalPlaybackSessionRepository
    implements AiroUniversalPlaybackSessionRepository {
  const AiroNoOpUniversalPlaybackSessionRepository();

  @override
  Future<AiroUniversalPlaybackSessionSnapshot?> recoverLatest({
    required String sessionId,
    required DateTime now,
  }) async {
    return null;
  }

  @override
  Future<AiroUniversalSessionDecision> upsert(
    AiroUniversalPlaybackSessionSnapshot snapshot, {
    required DateTime now,
  }) async {
    return AiroUniversalSessionDecision(
      action: AiroUniversalSessionDecisionAction.noOp,
      codes: const [AiroUniversalSessionCode.repositoryUnavailable],
      snapshot: snapshot,
    );
  }
}

class AiroFakeUniversalPlaybackSessionRepository
    implements AiroUniversalPlaybackSessionRepository {
  AiroFakeUniversalPlaybackSessionRepository({
    this.policy = const AiroUniversalPlaybackSessionPolicy(),
  });

  final AiroUniversalPlaybackSessionPolicy policy;
  final Map<String, AiroUniversalPlaybackSessionSnapshot> _snapshots = {};

  @override
  Future<AiroUniversalPlaybackSessionSnapshot?> recoverLatest({
    required String sessionId,
    required DateTime now,
  }) async {
    final snapshot = _snapshots[sessionId];
    if (snapshot == null || snapshot.isExpired(now)) return null;
    return snapshot.isReceiverAuthoritative ? snapshot : null;
  }

  @override
  Future<AiroUniversalSessionDecision> upsert(
    AiroUniversalPlaybackSessionSnapshot snapshot, {
    required DateTime now,
  }) async {
    final decision = policy.evaluateIncoming(
      incoming: snapshot,
      now: now,
      current: _snapshots[snapshot.sessionId],
    );
    if (decision.accepted) {
      _snapshots[snapshot.sessionId] = decision.snapshot;
    }
    return decision;
  }
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
