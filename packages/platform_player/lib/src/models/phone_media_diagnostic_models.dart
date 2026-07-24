import 'package:equatable/equatable.dart';

/// Stable, redacted event taxonomy for CV-033 phone-hosted playback.
///
/// These events are safe to surface to diagnostics pipelines because they
/// contain only stable ids and codes. They never carry media URLs, session
/// tokens, file paths, or receiver credentials.
enum PhoneMediaDiagnosticEventKind {
  sessionOpen('session_open'),
  sessionClose('session_close'),
  sessionExpired('session_expired'),
  requestRejected('request_rejected'),
  requestRejectedSuppressed('request_rejected_suppressed'),
  requestError('request_error'),
  wifiDisconnectedTeardown('wifi_disconnected_teardown');

  const PhoneMediaDiagnosticEventKind(this.stableId);

  final String stableId;
}

class PhoneMediaDiagnosticEvent extends Equatable {
  PhoneMediaDiagnosticEvent({
    required this.kind,
    this.serverId,
    this.reason,
    this.errorType,
    this.suppressedCount,
    List<String> validationCodes = const [],
    List<String> servingCodes = const [],
  }) : validationCodes = List.unmodifiable(validationCodes),
       servingCodes = List.unmodifiable(servingCodes);

  final PhoneMediaDiagnosticEventKind kind;
  final String? serverId;
  final String? reason;
  final String? errorType;
  final int? suppressedCount;
  final List<String> validationCodes;
  final List<String> servingCodes;

  Map<String, Object?> toPublicMap() {
    return {
      if (serverId != null) 'serverId': serverId,
      if (reason != null) 'reason': reason,
      if (errorType != null) 'errorType': errorType,
      if (suppressedCount != null) 'suppressedCount': suppressedCount,
      if (validationCodes.isNotEmpty) 'validationCodes': validationCodes,
      if (servingCodes.isNotEmpty) 'servingCodes': servingCodes,
    };
  }

  @override
  String toString() {
    return 'PhoneMediaDiagnosticEvent('
        'kind: ${kind.stableId}, '
        'serverId: $serverId, '
        'reason: $reason, '
        'errorType: $errorType, '
        'suppressedCount: $suppressedCount, '
        'validationCodes: $validationCodes, '
        'servingCodes: $servingCodes'
        ')';
  }

  @override
  List<Object?> get props => [
    kind,
    serverId,
    reason,
    errorType,
    suppressedCount,
    validationCodes,
    servingCodes,
  ];
}
