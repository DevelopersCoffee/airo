import 'dart:async';

import 'package:equatable/equatable.dart';

import 'session_models.dart';

const String kAiroRouteHealthEventSchemaVersion = '1.0.0';

enum AiroRouteHealthEventKind {
  snapshot('snapshot'),
  playbackState('playback_state'),
  position('position'),
  buffer('buffer'),
  volume('volume'),
  audioTrack('audio_track'),
  subtitleTrack('subtitle_track'),
  playbackSpeed('playback_speed'),
  routeHealth('route_health'),
  failure('failure'),
  completed('completed');

  const AiroRouteHealthEventKind(this.stableId);

  final String stableId;
}

enum AiroRouteHealthLevel {
  healthy('healthy'),
  degraded('degraded'),
  critical('critical'),
  recovering('recovering'),
  failed('failed'),
  unknown('unknown');

  const AiroRouteHealthLevel(this.stableId);

  final String stableId;
}

enum AiroRouteFailureCategory {
  network('network'),
  decoder('decoder'),
  sourceExpired('source_expired'),
  unsupportedMedia('unsupported_media'),
  routeUnavailable('route_unavailable'),
  permissionDenied('permission_denied'),
  playbackBackend('playback_backend'),
  timeout('timeout'),
  unknown('unknown');

  const AiroRouteFailureCategory(this.stableId);

  final String stableId;
}

enum AiroRouteFailureRetryability {
  retryable('retryable'),
  alternateRoute('alternate_route'),
  userActionRequired('user_action_required'),
  terminal('terminal'),
  unknown('unknown');

  const AiroRouteFailureRetryability(this.stableId);

  final String stableId;
}

enum AiroRouteHealthEventValidationCode {
  accepted('accepted'),
  sessionMismatch('session_mismatch'),
  routeMismatch('route_mismatch'),
  reporterUnauthorized('reporter_unauthorized'),
  nonPositiveSequence('non_positive_sequence'),
  staleSequence('stale_sequence'),
  invalidPosition('invalid_position'),
  invalidDuration('invalid_duration'),
  invalidBufferedAhead('invalid_buffered_ahead'),
  invalidVolume('invalid_volume'),
  invalidPlaybackSpeed('invalid_playback_speed'),
  failureMissing('failure_missing');

  const AiroRouteHealthEventValidationCode(this.stableId);

  final String stableId;
}

class AiroRouteFailureDetail extends Equatable {
  const AiroRouteFailureDetail({
    required this.category,
    required this.retryability,
    required this.stableCode,
    this.messageBucket,
  });

  final AiroRouteFailureCategory category;
  final AiroRouteFailureRetryability retryability;
  final String stableCode;
  final String? messageBucket;

  @override
  String toString() {
    return 'AiroRouteFailureDetail('
        'category: ${category.stableId}, '
        'retryability: ${retryability.stableId}, '
        'stableCode: $stableCode, '
        'messageBucket: $messageBucket'
        ')';
  }

  @override
  List<Object?> get props => [
    category,
    retryability,
    stableCode,
    messageBucket,
  ];
}

class AiroRouteHealthEvent extends Equatable {
  const AiroRouteHealthEvent({
    required this.eventId,
    required this.sessionId,
    required this.routeId,
    required this.mediaId,
    required this.reporterNodeId,
    required this.playbackNodeId,
    required this.sourceNodeId,
    required this.sequence,
    required this.occurredAt,
    required this.kind,
    this.playbackPhase,
    this.position,
    this.duration,
    this.bufferedAhead,
    this.volumePercent,
    this.isMuted,
    this.audioTrackId,
    this.subtitleTrackId,
    this.playbackSpeed,
    this.healthLevel = AiroRouteHealthLevel.unknown,
    this.failure,
    this.diagnosticHandle,
    this.schemaVersion = kAiroRouteHealthEventSchemaVersion,
  });

  final String schemaVersion;
  final String eventId;
  final String sessionId;
  final String routeId;
  final String mediaId;
  final String reporterNodeId;
  final String playbackNodeId;
  final String sourceNodeId;
  final int sequence;
  final DateTime occurredAt;
  final AiroRouteHealthEventKind kind;
  final AiroPlaybackSessionPhase? playbackPhase;
  final Duration? position;
  final Duration? duration;
  final Duration? bufferedAhead;
  final int? volumePercent;
  final bool? isMuted;
  final String? audioTrackId;
  final String? subtitleTrackId;
  final double? playbackSpeed;
  final AiroRouteHealthLevel healthLevel;
  final AiroRouteFailureDetail? failure;
  final AiroSessionPayloadHandle? diagnosticHandle;

  @override
  String toString() {
    return 'AiroRouteHealthEvent('
        'eventId: $eventId, '
        'sessionId: $sessionId, '
        'routeId: $routeId, '
        'mediaId: $mediaId, '
        'reporterNodeId: $reporterNodeId, '
        'playbackNodeId: $playbackNodeId, '
        'sourceNodeId: $sourceNodeId, '
        'sequence: $sequence, '
        'kind: ${kind.stableId}, '
        'phase: ${playbackPhase?.stableId}, '
        'healthLevel: ${healthLevel.stableId}, '
        'failure: $failure, '
        'diagnosticHandle: redacted'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    eventId,
    sessionId,
    routeId,
    mediaId,
    reporterNodeId,
    playbackNodeId,
    sourceNodeId,
    sequence,
    occurredAt,
    kind,
    playbackPhase,
    position,
    duration,
    bufferedAhead,
    volumePercent,
    isMuted,
    audioTrackId,
    subtitleTrackId,
    playbackSpeed,
    healthLevel,
    failure,
    diagnosticHandle,
  ];
}

class AiroRouteHealthEventValidation extends Equatable {
  AiroRouteHealthEventValidation({
    required this.eventId,
    required List<AiroRouteHealthEventValidationCode> codes,
  }) : codes = List.unmodifiable(codes);

  final String eventId;
  final List<AiroRouteHealthEventValidationCode> codes;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == AiroRouteHealthEventValidationCode.accepted;

  @override
  List<Object?> get props => [eventId, codes];
}

class AiroRouteHealthEventPolicy {
  const AiroRouteHealthEventPolicy();

  AiroRouteHealthEventValidation validate({
    required AiroRouteHealthEvent event,
    required AiroPlaybackOwnershipSnapshot ownership,
    required DateTime now,
    int? lastAcceptedSequence,
  }) {
    final codes = <AiroRouteHealthEventValidationCode>[];
    if (event.sessionId != ownership.sessionId) {
      codes.add(AiroRouteHealthEventValidationCode.sessionMismatch);
    }
    if (event.routeId != ownership.routeId) {
      codes.add(AiroRouteHealthEventValidationCode.routeMismatch);
    }
    if (!ownership.canPerform(
      nodeId: event.reporterNodeId,
      operation: AiroPlaybackOwnershipOperation.healthReport,
      now: now,
    )) {
      codes.add(AiroRouteHealthEventValidationCode.reporterUnauthorized);
    }
    if (event.sequence <= 0) {
      codes.add(AiroRouteHealthEventValidationCode.nonPositiveSequence);
    }
    if (lastAcceptedSequence != null &&
        event.sequence <= lastAcceptedSequence) {
      codes.add(AiroRouteHealthEventValidationCode.staleSequence);
    }
    _addDurationBlockers(event, codes);
    if (event.volumePercent != null &&
        (event.volumePercent! < 0 || event.volumePercent! > 100)) {
      codes.add(AiroRouteHealthEventValidationCode.invalidVolume);
    }
    if (event.playbackSpeed != null &&
        (event.playbackSpeed! <= 0 || event.playbackSpeed! > 4)) {
      codes.add(AiroRouteHealthEventValidationCode.invalidPlaybackSpeed);
    }
    if (event.kind == AiroRouteHealthEventKind.failure &&
        event.failure == null) {
      codes.add(AiroRouteHealthEventValidationCode.failureMissing);
    }

    return AiroRouteHealthEventValidation(
      eventId: event.eventId,
      codes: codes.isEmpty
          ? const [AiroRouteHealthEventValidationCode.accepted]
          : codes,
    );
  }

  void _addDurationBlockers(
    AiroRouteHealthEvent event,
    List<AiroRouteHealthEventValidationCode> codes,
  ) {
    final position = event.position;
    final duration = event.duration;
    final bufferedAhead = event.bufferedAhead;
    if (position != null && position < Duration.zero) {
      codes.add(AiroRouteHealthEventValidationCode.invalidPosition);
    }
    if (duration != null && duration < Duration.zero) {
      codes.add(AiroRouteHealthEventValidationCode.invalidDuration);
    }
    if (bufferedAhead != null && bufferedAhead < Duration.zero) {
      codes.add(AiroRouteHealthEventValidationCode.invalidBufferedAhead);
    }
    if (position != null && duration != null && position > duration) {
      codes.add(AiroRouteHealthEventValidationCode.invalidPosition);
    }
  }
}

abstract interface class AiroRouteHealthEventSink {
  FutureOr<AiroRouteHealthEventValidation> publish(AiroRouteHealthEvent event);
}

class AiroNoOpRouteHealthEventSink implements AiroRouteHealthEventSink {
  const AiroNoOpRouteHealthEventSink();

  @override
  FutureOr<AiroRouteHealthEventValidation> publish(AiroRouteHealthEvent event) {
    return AiroRouteHealthEventValidation(
      eventId: event.eventId,
      codes: const [AiroRouteHealthEventValidationCode.accepted],
    );
  }
}

class AiroFakeRouteHealthEventSink implements AiroRouteHealthEventSink {
  AiroFakeRouteHealthEventSink({
    required this.ownership,
    this.policy = const AiroRouteHealthEventPolicy(),
    this.now,
  });

  final AiroPlaybackOwnershipSnapshot ownership;
  final AiroRouteHealthEventPolicy policy;
  final DateTime? now;
  final List<AiroRouteHealthEvent> events = [];
  int? _lastAcceptedSequence;

  @override
  FutureOr<AiroRouteHealthEventValidation> publish(AiroRouteHealthEvent event) {
    final validation = policy.validate(
      event: event,
      ownership: ownership,
      now: now ?? event.occurredAt,
      lastAcceptedSequence: _lastAcceptedSequence,
    );
    if (validation.accepted) {
      events.add(event);
      _lastAcceptedSequence = event.sequence;
    }
    return validation;
  }
}
