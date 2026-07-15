import 'package:equatable/equatable.dart';

const String kAiroMediaErrorTaxonomySchemaVersion = '1.0.0';

enum AiroMediaErrorCategory {
  source('source'),
  authentication('authentication'),
  authorization('authorization'),
  network('network'),
  decoder('decoder'),
  capability('capability'),
  route('route'),
  playback('playback'),
  import('import'),
  epg('epg'),
  storage('storage'),
  protocol('protocol'),
  analytics('analytics'),
  unknown('unknown');

  const AiroMediaErrorCategory(this.stableId);

  final String stableId;
}

enum AiroMediaErrorSeverity {
  info('info'),
  warning('warning'),
  recoverable('recoverable'),
  critical('critical'),
  fatal('fatal');

  const AiroMediaErrorSeverity(this.stableId);

  final String stableId;
}

enum AiroMediaErrorRetryability {
  never('never'),
  immediate('immediate'),
  afterBackoff('after_backoff'),
  afterUserAction('after_user_action'),
  afterSourceRefresh('after_source_refresh');

  const AiroMediaErrorRetryability(this.stableId);

  final String stableId;

  bool get canRetryAutomatically =>
      this == AiroMediaErrorRetryability.immediate ||
      this == AiroMediaErrorRetryability.afterBackoff;

  bool get requiresUserAction =>
      this == AiroMediaErrorRetryability.afterUserAction ||
      this == AiroMediaErrorRetryability.afterSourceRefresh;
}

enum AiroMediaErrorCode {
  sourceInvalid('source_invalid'),
  sourceUnavailable('source_unavailable'),
  sourceExpired('source_expired'),
  authenticationRequired('authentication_required'),
  authorizationDenied('authorization_denied'),
  networkUnavailable('network_unavailable'),
  networkTimeout('network_timeout'),
  decoderUnsupported('decoder_unsupported'),
  decoderFailed('decoder_failed'),
  capabilityUnsupported('capability_unsupported'),
  routeUnavailable('route_unavailable'),
  playbackStartupFailed('playback_startup_failed'),
  playbackInterrupted('playback_interrupted'),
  importFailed('import_failed'),
  epgUnavailable('epg_unavailable'),
  storageFull('storage_full'),
  protocolMismatch('protocol_mismatch'),
  analyticsRejected('analytics_rejected'),
  unknown('unknown');

  const AiroMediaErrorCode(this.stableId);

  final String stableId;
}

enum AiroMediaErrorContextKind {
  session('session'),
  source('source'),
  route('route'),
  backend('backend'),
  device('device'),
  profile('profile'),
  worker('worker'),
  operation('operation');

  const AiroMediaErrorContextKind(this.stableId);

  final String stableId;
}

enum AiroMediaErrorSafeValueRejectionCode {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value'),
  messageKeyFormat('message_key_format'),
  diagnosticCodeFormat('diagnostic_code_format');

  const AiroMediaErrorSafeValueRejectionCode(this.stableId);

  final String stableId;
}

class AiroMediaErrorSafeValue extends Equatable {
  const AiroMediaErrorSafeValue._(this.value);

  factory AiroMediaErrorSafeValue.redacted(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return AiroMediaErrorSafeValue._(value.trim());
  }

  final String value;

  static AiroMediaErrorSafeValueRejectionCode? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return AiroMediaErrorSafeValueRejectionCode.empty;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroMediaErrorSafeValueRejectionCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroMediaErrorSafeValueRejectionCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroMediaErrorSafeValueRejectionCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroMediaErrorSafeValueRejectionCode.credentialLikeValue;
    }
    return null;
  }

  @override
  String toString() => 'AiroMediaErrorSafeValue(redacted)';

  @override
  List<Object?> get props => [value];
}

class AiroMediaUserMessageKey extends Equatable {
  const AiroMediaUserMessageKey._(this.value);

  factory AiroMediaUserMessageKey.stable(String value) {
    final trimmed = value.trim();
    final safeValueRejection = AiroMediaErrorSafeValue.validate(trimmed);
    if (safeValueRejection != null) {
      throw ArgumentError.value(value, 'value', safeValueRejection.stableId);
    }
    if (!RegExp(r'^media\.[a-z0-9_]+(\.[a-z0-9_]+)+$').hasMatch(trimmed)) {
      throw ArgumentError.value(
        value,
        'value',
        AiroMediaErrorSafeValueRejectionCode.messageKeyFormat.stableId,
      );
    }
    return AiroMediaUserMessageKey._(trimmed);
  }

  final String value;

  @override
  String toString() => value;

  @override
  List<Object?> get props => [value];
}

class AiroMediaErrorContext extends Equatable {
  const AiroMediaErrorContext({
    required this.kind,
    required this.ref,
    this.schemaVersion = kAiroMediaErrorTaxonomySchemaVersion,
  });

  final String schemaVersion;
  final AiroMediaErrorContextKind kind;
  final AiroMediaErrorSafeValue ref;

  @override
  String toString() {
    return 'AiroMediaErrorContext('
        'kind: ${kind.stableId}, '
        'ref: redacted'
        ')';
  }

  @override
  List<Object?> get props => [schemaVersion, kind, ref];
}

class AiroMediaDiagnosticHandle extends Equatable {
  const AiroMediaDiagnosticHandle._(this.value);

  factory AiroMediaDiagnosticHandle.redacted(String value) {
    final rejection = AiroMediaErrorSafeValue.validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return AiroMediaDiagnosticHandle._(value.trim());
  }

  final String value;

  @override
  String toString() => 'AiroMediaDiagnosticHandle(redacted)';

  @override
  List<Object?> get props => [value];
}

class AiroMediaDiagnosticCode extends Equatable {
  const AiroMediaDiagnosticCode._(this.value);

  factory AiroMediaDiagnosticCode.stable(String value) {
    final trimmed = value.trim();
    final safeValueRejection = AiroMediaErrorSafeValue.validate(trimmed);
    if (safeValueRejection != null) {
      throw ArgumentError.value(value, 'value', safeValueRejection.stableId);
    }
    if (!RegExp(r'^[a-z0-9_]+(\.[a-z0-9_]+)*$').hasMatch(trimmed)) {
      throw ArgumentError.value(
        value,
        'value',
        AiroMediaErrorSafeValueRejectionCode.diagnosticCodeFormat.stableId,
      );
    }
    return AiroMediaDiagnosticCode._(trimmed);
  }

  final String value;

  @override
  String toString() => value;

  @override
  List<Object?> get props => [value];
}

class AiroMediaErrorDescriptor extends Equatable {
  AiroMediaErrorDescriptor({
    required this.code,
    required this.category,
    required this.severity,
    required this.retryability,
    required this.userMessageKey,
    Iterable<AiroMediaErrorContext> contexts = const [],
    Iterable<AiroMediaDiagnosticCode> diagnosticCodes = const [],
    this.diagnosticHandle,
    this.schemaVersion = kAiroMediaErrorTaxonomySchemaVersion,
  }) : contexts = List.unmodifiable(contexts),
       diagnosticCodes = List.unmodifiable(diagnosticCodes);

  final String schemaVersion;
  final AiroMediaErrorCode code;
  final AiroMediaErrorCategory category;
  final AiroMediaErrorSeverity severity;
  final AiroMediaErrorRetryability retryability;
  final AiroMediaUserMessageKey userMessageKey;
  final List<AiroMediaErrorContext> contexts;
  final List<AiroMediaDiagnosticCode> diagnosticCodes;
  final AiroMediaDiagnosticHandle? diagnosticHandle;

  bool get retryable => retryability != AiroMediaErrorRetryability.never;

  bool get canRetryAutomatically => retryability.canRetryAutomatically;

  bool get requiresUserAction => retryability.requiresUserAction;

  @override
  String toString() {
    return 'AiroMediaErrorDescriptor('
        'code: ${code.stableId}, '
        'category: ${category.stableId}, '
        'severity: ${severity.stableId}, '
        'retryability: ${retryability.stableId}, '
        'userMessageKey: ${userMessageKey.value}, '
        'contextCount: ${contexts.length}, '
        'diagnosticCodes: ${diagnosticCodes.map((code) => code.value).toList()}, '
        'diagnosticHandle: ${diagnosticHandle == null ? 'none' : 'redacted'}'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    code,
    category,
    severity,
    retryability,
    userMessageKey,
    contexts,
    diagnosticCodes,
    diagnosticHandle,
  ];
}

class AiroMediaErrorInput extends Equatable {
  AiroMediaErrorInput({
    required this.code,
    Iterable<AiroMediaErrorContext> contexts = const [],
    Iterable<AiroMediaDiagnosticCode> diagnosticCodes = const [],
    this.diagnosticHandle,
  }) : contexts = List.unmodifiable(contexts),
       diagnosticCodes = List.unmodifiable(diagnosticCodes);

  final AiroMediaErrorCode code;
  final List<AiroMediaErrorContext> contexts;
  final List<AiroMediaDiagnosticCode> diagnosticCodes;
  final AiroMediaDiagnosticHandle? diagnosticHandle;

  @override
  List<Object?> get props => [
    code,
    contexts,
    diagnosticCodes,
    diagnosticHandle,
  ];
}

abstract interface class AiroMediaErrorClassifier {
  AiroMediaErrorDescriptor classify(AiroMediaErrorInput input);
}

class AiroDefaultMediaErrorClassifier implements AiroMediaErrorClassifier {
  const AiroDefaultMediaErrorClassifier();

  @override
  AiroMediaErrorDescriptor classify(AiroMediaErrorInput input) {
    final preset = _presets[input.code] ?? _unknownPreset;
    return AiroMediaErrorDescriptor(
      code: input.code,
      category: preset.category,
      severity: preset.severity,
      retryability: preset.retryability,
      userMessageKey: AiroMediaUserMessageKey.stable(preset.userMessageKey),
      contexts: input.contexts,
      diagnosticCodes: input.diagnosticCodes,
      diagnosticHandle: input.diagnosticHandle,
    );
  }
}

class AiroNoOpMediaErrorClassifier implements AiroMediaErrorClassifier {
  const AiroNoOpMediaErrorClassifier();

  @override
  AiroMediaErrorDescriptor classify(AiroMediaErrorInput input) {
    return AiroMediaErrorDescriptor(
      code: AiroMediaErrorCode.unknown,
      category: AiroMediaErrorCategory.unknown,
      severity: AiroMediaErrorSeverity.warning,
      retryability: AiroMediaErrorRetryability.never,
      userMessageKey: AiroMediaUserMessageKey.stable('media.error.unknown'),
      contexts: input.contexts,
      diagnosticCodes: [AiroMediaDiagnosticCode.stable('noop_classifier')],
    );
  }
}

class AiroFakeMediaErrorClassifier implements AiroMediaErrorClassifier {
  AiroFakeMediaErrorClassifier({
    required Map<AiroMediaErrorCode, AiroMediaErrorDescriptor> descriptors,
    this.fallback = const AiroNoOpMediaErrorClassifier(),
  }) : _descriptors = Map.unmodifiable(descriptors);

  final Map<AiroMediaErrorCode, AiroMediaErrorDescriptor> _descriptors;
  final AiroMediaErrorClassifier fallback;

  @override
  AiroMediaErrorDescriptor classify(AiroMediaErrorInput input) {
    return _descriptors[input.code] ?? fallback.classify(input);
  }
}

class _MediaErrorPreset {
  const _MediaErrorPreset({
    required this.category,
    required this.severity,
    required this.retryability,
    required this.userMessageKey,
  });

  final AiroMediaErrorCategory category;
  final AiroMediaErrorSeverity severity;
  final AiroMediaErrorRetryability retryability;
  final String userMessageKey;
}

const _unknownPreset = _MediaErrorPreset(
  category: AiroMediaErrorCategory.unknown,
  severity: AiroMediaErrorSeverity.warning,
  retryability: AiroMediaErrorRetryability.never,
  userMessageKey: 'media.error.unknown',
);

const Map<AiroMediaErrorCode, _MediaErrorPreset> _presets = {
  AiroMediaErrorCode.sourceInvalid: _MediaErrorPreset(
    category: AiroMediaErrorCategory.source,
    severity: AiroMediaErrorSeverity.recoverable,
    retryability: AiroMediaErrorRetryability.afterUserAction,
    userMessageKey: 'media.source.invalid',
  ),
  AiroMediaErrorCode.sourceUnavailable: _MediaErrorPreset(
    category: AiroMediaErrorCategory.source,
    severity: AiroMediaErrorSeverity.warning,
    retryability: AiroMediaErrorRetryability.afterBackoff,
    userMessageKey: 'media.source.unavailable',
  ),
  AiroMediaErrorCode.sourceExpired: _MediaErrorPreset(
    category: AiroMediaErrorCategory.source,
    severity: AiroMediaErrorSeverity.recoverable,
    retryability: AiroMediaErrorRetryability.afterSourceRefresh,
    userMessageKey: 'media.source.expired',
  ),
  AiroMediaErrorCode.authenticationRequired: _MediaErrorPreset(
    category: AiroMediaErrorCategory.authentication,
    severity: AiroMediaErrorSeverity.recoverable,
    retryability: AiroMediaErrorRetryability.afterUserAction,
    userMessageKey: 'media.auth.required',
  ),
  AiroMediaErrorCode.authorizationDenied: _MediaErrorPreset(
    category: AiroMediaErrorCategory.authorization,
    severity: AiroMediaErrorSeverity.critical,
    retryability: AiroMediaErrorRetryability.afterUserAction,
    userMessageKey: 'media.auth.denied',
  ),
  AiroMediaErrorCode.networkUnavailable: _MediaErrorPreset(
    category: AiroMediaErrorCategory.network,
    severity: AiroMediaErrorSeverity.warning,
    retryability: AiroMediaErrorRetryability.afterBackoff,
    userMessageKey: 'media.network.unavailable',
  ),
  AiroMediaErrorCode.networkTimeout: _MediaErrorPreset(
    category: AiroMediaErrorCategory.network,
    severity: AiroMediaErrorSeverity.warning,
    retryability: AiroMediaErrorRetryability.afterBackoff,
    userMessageKey: 'media.network.timeout',
  ),
  AiroMediaErrorCode.decoderUnsupported: _MediaErrorPreset(
    category: AiroMediaErrorCategory.decoder,
    severity: AiroMediaErrorSeverity.recoverable,
    retryability: AiroMediaErrorRetryability.afterUserAction,
    userMessageKey: 'media.decoder.unsupported',
  ),
  AiroMediaErrorCode.decoderFailed: _MediaErrorPreset(
    category: AiroMediaErrorCategory.decoder,
    severity: AiroMediaErrorSeverity.critical,
    retryability: AiroMediaErrorRetryability.immediate,
    userMessageKey: 'media.decoder.failed',
  ),
  AiroMediaErrorCode.capabilityUnsupported: _MediaErrorPreset(
    category: AiroMediaErrorCategory.capability,
    severity: AiroMediaErrorSeverity.recoverable,
    retryability: AiroMediaErrorRetryability.afterUserAction,
    userMessageKey: 'media.capability.unsupported',
  ),
  AiroMediaErrorCode.routeUnavailable: _MediaErrorPreset(
    category: AiroMediaErrorCategory.route,
    severity: AiroMediaErrorSeverity.warning,
    retryability: AiroMediaErrorRetryability.afterBackoff,
    userMessageKey: 'media.route.unavailable',
  ),
  AiroMediaErrorCode.playbackStartupFailed: _MediaErrorPreset(
    category: AiroMediaErrorCategory.playback,
    severity: AiroMediaErrorSeverity.critical,
    retryability: AiroMediaErrorRetryability.immediate,
    userMessageKey: 'media.playback.startup_failed',
  ),
  AiroMediaErrorCode.playbackInterrupted: _MediaErrorPreset(
    category: AiroMediaErrorCategory.playback,
    severity: AiroMediaErrorSeverity.warning,
    retryability: AiroMediaErrorRetryability.afterBackoff,
    userMessageKey: 'media.playback.interrupted',
  ),
  AiroMediaErrorCode.importFailed: _MediaErrorPreset(
    category: AiroMediaErrorCategory.import,
    severity: AiroMediaErrorSeverity.recoverable,
    retryability: AiroMediaErrorRetryability.afterUserAction,
    userMessageKey: 'media.import.failed',
  ),
  AiroMediaErrorCode.epgUnavailable: _MediaErrorPreset(
    category: AiroMediaErrorCategory.epg,
    severity: AiroMediaErrorSeverity.info,
    retryability: AiroMediaErrorRetryability.afterBackoff,
    userMessageKey: 'media.epg.unavailable',
  ),
  AiroMediaErrorCode.storageFull: _MediaErrorPreset(
    category: AiroMediaErrorCategory.storage,
    severity: AiroMediaErrorSeverity.critical,
    retryability: AiroMediaErrorRetryability.afterUserAction,
    userMessageKey: 'media.storage.full',
  ),
  AiroMediaErrorCode.protocolMismatch: _MediaErrorPreset(
    category: AiroMediaErrorCategory.protocol,
    severity: AiroMediaErrorSeverity.critical,
    retryability: AiroMediaErrorRetryability.afterUserAction,
    userMessageKey: 'media.protocol.mismatch',
  ),
  AiroMediaErrorCode.analyticsRejected: _MediaErrorPreset(
    category: AiroMediaErrorCategory.analytics,
    severity: AiroMediaErrorSeverity.info,
    retryability: AiroMediaErrorRetryability.never,
    userMessageKey: 'media.analytics.rejected',
  ),
  AiroMediaErrorCode.unknown: _unknownPreset,
};
