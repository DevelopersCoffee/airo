import 'package:equatable/equatable.dart';

import '../services/cast_log_redaction.dart';
import 'playback_engine_models.dart';

/// Stable, user-safe diagnostic codes for playback failures (CV-001).
enum AiroPlaybackDiagnosticCode {
  networkUnavailable('network_unavailable'),
  providerAuthDenied('provider_auth_denied'),
  providerNotFound('provider_not_found'),
  providerRateLimited('provider_rate_limited'),
  providerServerError('provider_server_error'),
  streamStalled('stream_stalled'),
  streamEndedEarly('stream_ended_early'),
  codecUnsupported('codec_unsupported'),
  playerInitFailed('player_init_failed'),
  sourceInvalid('source_invalid'),
  unknown('unknown');

  const AiroPlaybackDiagnosticCode(this.stableId);

  final String stableId;
}

enum AiroPlaybackDiagnosticSeverity {
  info('info'),
  recoverable('recoverable'),
  fatal('fatal');

  const AiroPlaybackDiagnosticSeverity(this.stableId);

  final String stableId;
}

/// Raw failure observation handed to [AiroPlaybackDiagnosticMapper].
///
/// Exactly one signal is usually set; when several are present the mapper
/// resolves them in priority order: [overrideCode], [httpStatusCode],
/// [engineError], [stalledFor], [endedAfter].
class AiroPlaybackFailureEvent extends Equatable {
  const AiroPlaybackFailureEvent({
    this.engineError,
    this.httpStatusCode,
    this.stalledFor,
    this.endedAfter,
    this.sourceUri,
    this.overrideCode,
  });

  final AiroPlaybackError? engineError;
  final int? httpStatusCode;
  final Duration? stalledFor;
  final Duration? endedAfter;
  final Uri? sourceUri;
  final AiroPlaybackDiagnosticCode? overrideCode;

  @override
  List<Object?> get props => [
    engineError,
    httpStatusCode,
    stalledFor,
    endedAfter,
    sourceUri,
    overrideCode,
  ];
}

class AiroPlaybackDiagnostic extends Equatable {
  const AiroPlaybackDiagnostic({
    required this.code,
    required this.severity,
    required this.retryEligible,
    required this.userMessage,
    this.technicalDetail,
  });

  final AiroPlaybackDiagnosticCode code;
  final AiroPlaybackDiagnosticSeverity severity;
  final bool retryEligible;

  /// Short TV-safe copy. Never contains URLs or credentials.
  final String userMessage;

  /// Redacted detail for the optional debug overlay. Source URIs are reduced
  /// to `scheme://host[:port]` via [redactedUriForLog].
  final String? technicalDetail;

  @override
  List<Object?> get props => [
    code,
    severity,
    retryEligible,
    userMessage,
    technicalDetail,
  ];
}

/// Maps raw playback failure signals to stable user-safe diagnostics.
class AiroPlaybackDiagnosticMapper {
  const AiroPlaybackDiagnosticMapper();

  AiroPlaybackDiagnostic map(AiroPlaybackFailureEvent event) {
    final code = _resolveCode(event);
    return AiroPlaybackDiagnostic(
      code: code,
      severity: _severityFor(code),
      retryEligible: _retryEligibleFor(code),
      userMessage: _userMessageFor(code),
      technicalDetail: _technicalDetailFor(event, code),
    );
  }

  AiroPlaybackDiagnosticCode _resolveCode(AiroPlaybackFailureEvent event) {
    final override = event.overrideCode;
    if (override != null) return override;

    final status = event.httpStatusCode;
    if (status != null) return _codeForHttpStatus(status);

    final engineError = event.engineError;
    if (engineError != null) return _codeForEngineError(engineError.code);

    if (event.stalledFor != null) {
      return AiroPlaybackDiagnosticCode.streamStalled;
    }
    if (event.endedAfter != null) {
      return AiroPlaybackDiagnosticCode.streamEndedEarly;
    }
    return AiroPlaybackDiagnosticCode.unknown;
  }

  AiroPlaybackDiagnosticCode _codeForHttpStatus(int status) {
    if (status == 401 || status == 403) {
      return AiroPlaybackDiagnosticCode.providerAuthDenied;
    }
    if (status == 404) return AiroPlaybackDiagnosticCode.providerNotFound;
    if (status == 429) return AiroPlaybackDiagnosticCode.providerRateLimited;
    if (status >= 500) return AiroPlaybackDiagnosticCode.providerServerError;
    return AiroPlaybackDiagnosticCode.unknown;
  }

  AiroPlaybackDiagnosticCode _codeForEngineError(AiroPlaybackErrorCode code) {
    return switch (code) {
      AiroPlaybackErrorCode.networkUnavailable =>
        AiroPlaybackDiagnosticCode.networkUnavailable,
      AiroPlaybackErrorCode.codecUnsupported ||
      AiroPlaybackErrorCode.protectedPlaybackUnsupported =>
        AiroPlaybackDiagnosticCode.codecUnsupported,
      AiroPlaybackErrorCode.decoderFailed ||
      AiroPlaybackErrorCode.backendUnavailable =>
        AiroPlaybackDiagnosticCode.playerInitFailed,
      AiroPlaybackErrorCode.invalidSource =>
        AiroPlaybackDiagnosticCode.sourceInvalid,
      AiroPlaybackErrorCode.sourceUnavailable =>
        AiroPlaybackDiagnosticCode.providerServerError,
      AiroPlaybackErrorCode.unsupportedOperation ||
      AiroPlaybackErrorCode.operationRejected ||
      AiroPlaybackErrorCode.qualityUnavailable ||
      AiroPlaybackErrorCode.trackUnavailable =>
        AiroPlaybackDiagnosticCode.unknown,
    };
  }

  AiroPlaybackDiagnosticSeverity _severityFor(AiroPlaybackDiagnosticCode code) {
    return switch (code) {
      AiroPlaybackDiagnosticCode.codecUnsupported ||
      AiroPlaybackDiagnosticCode.playerInitFailed ||
      AiroPlaybackDiagnosticCode.sourceInvalid ||
      AiroPlaybackDiagnosticCode.providerAuthDenied ||
      AiroPlaybackDiagnosticCode.providerNotFound =>
        AiroPlaybackDiagnosticSeverity.fatal,
      _ => AiroPlaybackDiagnosticSeverity.recoverable,
    };
  }

  bool _retryEligibleFor(AiroPlaybackDiagnosticCode code) {
    return switch (code) {
      AiroPlaybackDiagnosticCode.providerAuthDenied ||
      AiroPlaybackDiagnosticCode.providerNotFound ||
      AiroPlaybackDiagnosticCode.codecUnsupported ||
      AiroPlaybackDiagnosticCode.playerInitFailed ||
      AiroPlaybackDiagnosticCode.sourceInvalid => false,
      _ => true,
    };
  }

  String _userMessageFor(AiroPlaybackDiagnosticCode code) {
    return switch (code) {
      AiroPlaybackDiagnosticCode.networkUnavailable =>
        'Network connection lost. Reconnecting…',
      AiroPlaybackDiagnosticCode.providerAuthDenied =>
        'Your provider rejected this stream. Check your playlist credentials.',
      AiroPlaybackDiagnosticCode.providerNotFound =>
        'This channel is missing from your provider right now.',
      AiroPlaybackDiagnosticCode.providerRateLimited =>
        'Your provider is limiting connections. Retrying shortly…',
      AiroPlaybackDiagnosticCode.providerServerError =>
        'Your provider is having trouble. Retrying…',
      AiroPlaybackDiagnosticCode.streamStalled =>
        'Stream stalled. Reconnecting…',
      AiroPlaybackDiagnosticCode.streamEndedEarly =>
        'The stream stopped unexpectedly. Reconnecting…',
      AiroPlaybackDiagnosticCode.codecUnsupported =>
        'This stream format is not supported on this device.',
      AiroPlaybackDiagnosticCode.playerInitFailed =>
        'Playback could not start on this device.',
      AiroPlaybackDiagnosticCode.sourceInvalid =>
        'This channel address looks invalid. Check your playlist.',
      AiroPlaybackDiagnosticCode.unknown => 'Playback failed. Retrying…',
    };
  }

  String? _technicalDetailFor(
    AiroPlaybackFailureEvent event,
    AiroPlaybackDiagnosticCode code,
  ) {
    final parts = <String>['code=${code.stableId}'];
    final status = event.httpStatusCode;
    if (status != null) parts.add('http=$status');
    final engineError = event.engineError;
    if (engineError != null) {
      parts.add('engine=${engineError.code.stableId}');
    }
    final stalledFor = event.stalledFor;
    if (stalledFor != null) parts.add('stalledMs=${stalledFor.inMilliseconds}');
    final endedAfter = event.endedAfter;
    if (endedAfter != null) parts.add('playedMs=${endedAfter.inMilliseconds}');
    if (event.sourceUri != null) {
      parts.add('source=${redactedUriForLog(event.sourceUri)}');
    }
    return parts.join(' ');
  }
}

enum AiroPlaybackRetryAction {
  /// Schedule another attempt after [AiroPlaybackRetryDecision.delay].
  retry('retry'),

  /// Retryable failure, but attempts are exhausted.
  giveUp('give_up'),

  /// Failure class is not retryable; stop immediately.
  stop('stop');

  const AiroPlaybackRetryAction(this.stableId);

  final String stableId;
}

/// Bounded exponential backoff policy for transient playback failures.
class AiroPlaybackRetryPolicy extends Equatable {
  const AiroPlaybackRetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 8),
  });

  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;

  Duration delayForAttempt(int attempt) {
    assert(attempt >= 1, 'attempt is 1-based');
    var delay = initialDelay;
    for (var i = 1; i < attempt; i++) {
      delay *= 2;
      if (delay >= maxDelay) return maxDelay;
    }
    return delay <= maxDelay ? delay : maxDelay;
  }

  @override
  List<Object?> get props => [maxAttempts, initialDelay, maxDelay];
}

class AiroPlaybackRetryDecision extends Equatable {
  const AiroPlaybackRetryDecision({
    required this.action,
    required this.attempt,
    required this.diagnostic,
    this.delay,
  });

  final AiroPlaybackRetryAction action;

  /// 1-based attempt number this decision corresponds to. Zero when no
  /// attempt was consumed (non-retryable or already terminal).
  final int attempt;

  final AiroPlaybackDiagnostic diagnostic;
  final Duration? delay;

  @override
  List<Object?> get props => [action, attempt, diagnostic, delay];
}

/// Caller-driven retry state machine: no timers, no clock. The playback
/// service owns scheduling; this only decides.
class AiroPlaybackRetryStateMachine {
  AiroPlaybackRetryStateMachine({
    this.policy = const AiroPlaybackRetryPolicy(),
  });

  final AiroPlaybackRetryPolicy policy;

  int _attempts = 0;
  bool _terminal = false;

  bool get isTerminal => _terminal;

  AiroPlaybackRetryDecision onFailure(AiroPlaybackDiagnostic diagnostic) {
    if (!diagnostic.retryEligible) {
      _terminal = true;
      return AiroPlaybackRetryDecision(
        action: AiroPlaybackRetryAction.stop,
        attempt: 0,
        diagnostic: diagnostic,
      );
    }
    if (_terminal || _attempts >= policy.maxAttempts) {
      _terminal = true;
      return AiroPlaybackRetryDecision(
        action: AiroPlaybackRetryAction.giveUp,
        attempt: _attempts,
        diagnostic: diagnostic,
      );
    }
    _attempts += 1;
    return AiroPlaybackRetryDecision(
      action: AiroPlaybackRetryAction.retry,
      attempt: _attempts,
      diagnostic: diagnostic,
      delay: policy.delayForAttempt(_attempts),
    );
  }

  /// Playback ran healthily again; future failures start a fresh cycle.
  void onPlaybackRecovered() {
    _attempts = 0;
    _terminal = false;
  }

  /// New playback session (channel change, manual retry).
  void reset() {
    _attempts = 0;
    _terminal = false;
  }
}
