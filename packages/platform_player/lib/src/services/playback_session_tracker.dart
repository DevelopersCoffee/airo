import 'package:equatable/equatable.dart';

import 'cast_log_redaction.dart';

enum AiroPlaybackSessionEventKind {
  opened('opened'),
  stopped('stopped'),
  duplicateDetected('duplicate_detected'),
  unknownSession('unknown_session');

  const AiroPlaybackSessionEventKind(this.stableId);

  final String stableId;
}

/// Redacted, session-scoped lifecycle event (CV-001 UC-003).
class AiroPlaybackSessionEvent extends Equatable {
  const AiroPlaybackSessionEvent({
    required this.kind,
    required this.surfaceId,
    required this.sessionId,
    this.evictedSessionId,
    this.redactedSource,
  });

  final AiroPlaybackSessionEventKind kind;
  final String surfaceId;
  final String sessionId;

  /// Set when a duplicate open evicted an older session on the same surface.
  final String? evictedSessionId;

  /// Source reduced to `scheme://host[:port]`; never carries credentials.
  final String? redactedSource;

  @override
  String toString() {
    return 'AiroPlaybackSessionEvent('
        'kind: ${kind.stableId}, '
        'surfaceId: $surfaceId, '
        'sessionId: $sessionId, '
        'evictedSessionId: $evictedSessionId, '
        'source: $redactedSource'
        ')';
  }

  @override
  List<Object?> get props => [
    kind,
    surfaceId,
    sessionId,
    evictedSessionId,
    redactedSource,
  ];
}

/// Tracks active playback sessions per surface so channel switches, retries,
/// and disposal never leave duplicate live connections (CV-001 UC-003).
///
/// Pure bookkeeping: the playback service reports open/stop transitions and
/// acts on the returned event (e.g. closing the evicted session's resources
/// when [AiroPlaybackSessionEventKind.duplicateDetected] is returned).
class AiroPlaybackSessionTracker {
  final Map<String, String> _activeSessionBySurface = {};

  int activeSessionCount(String surfaceId) {
    return _activeSessionBySurface.containsKey(surfaceId) ? 1 : 0;
  }

  String? activeSessionId(String surfaceId) {
    return _activeSessionBySurface[surfaceId];
  }

  AiroPlaybackSessionEvent onSessionOpened({
    required String surfaceId,
    required String sessionId,
    Uri? sourceUri,
  }) {
    final previous = _activeSessionBySurface[surfaceId];
    _activeSessionBySurface[surfaceId] = sessionId;

    if (previous != null && previous != sessionId) {
      return AiroPlaybackSessionEvent(
        kind: AiroPlaybackSessionEventKind.duplicateDetected,
        surfaceId: surfaceId,
        sessionId: sessionId,
        evictedSessionId: previous,
        redactedSource: sourceUri == null ? null : redactedUriForLog(sourceUri),
      );
    }

    return AiroPlaybackSessionEvent(
      kind: AiroPlaybackSessionEventKind.opened,
      surfaceId: surfaceId,
      sessionId: sessionId,
      redactedSource: sourceUri == null ? null : redactedUriForLog(sourceUri),
    );
  }

  AiroPlaybackSessionEvent onSessionStopped({
    required String surfaceId,
    required String sessionId,
  }) {
    final active = _activeSessionBySurface[surfaceId];
    if (active != sessionId) {
      return AiroPlaybackSessionEvent(
        kind: AiroPlaybackSessionEventKind.unknownSession,
        surfaceId: surfaceId,
        sessionId: sessionId,
      );
    }

    _activeSessionBySurface.remove(surfaceId);
    return AiroPlaybackSessionEvent(
      kind: AiroPlaybackSessionEventKind.stopped,
      surfaceId: surfaceId,
      sessionId: sessionId,
    );
  }
}
