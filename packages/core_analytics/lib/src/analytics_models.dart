import 'package:equatable/equatable.dart';

const String kAiroAnalyticsSchemaVersion = '1.0.0';

enum AiroAnalyticsPurpose {
  operational('operational'),
  product('product'),
  playbackQuality('playback_quality'),
  diagnostics('diagnostics'),
  crash('crash'),
  personalized('personalized');

  const AiroAnalyticsPurpose(this.stableId);

  final String stableId;
}

enum AiroAnalyticsPriority {
  low('low'),
  normal('normal'),
  high('high'),
  critical('critical');

  const AiroAnalyticsPriority(this.stableId);

  final String stableId;
}

enum AiroAnalyticsTrackStatus {
  accepted,
  droppedByConsent,
  droppedByLocalOnly,
  droppedQueueFull,
  rejectedPrivacy,
  rejectedSchema,
}

enum AiroAnalyticsPrivacyCode {
  prohibitedFieldName('prohibited_field_name'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value');

  const AiroAnalyticsPrivacyCode(this.stableId);

  final String stableId;
}

class AiroAnalyticsEvent extends Equatable {
  AiroAnalyticsEvent({
    required this.name,
    required this.owner,
    required this.purpose,
    Map<String, Object?> params = const {},
    this.priority = AiroAnalyticsPriority.normal,
    this.schemaVersion = kAiroAnalyticsSchemaVersion,
  }) : params = Map.unmodifiable(params);

  final String name;
  final String owner;
  final AiroAnalyticsPurpose purpose;
  final AiroAnalyticsPriority priority;
  final String schemaVersion;
  final Map<String, Object?> params;

  @override
  List<Object?> get props => [
    name,
    owner,
    purpose,
    priority,
    schemaVersion,
    params,
  ];
}

class AiroAnalyticsConsentState extends Equatable {
  const AiroAnalyticsConsentState({
    required this.operational,
    required this.product,
    required this.playbackQuality,
    required this.diagnostics,
    required this.crash,
    required this.personalized,
    this.localOnly = false,
  });

  const AiroAnalyticsConsentState.disabled()
    : this(
        operational: true,
        product: false,
        playbackQuality: false,
        diagnostics: false,
        crash: false,
        personalized: false,
      );

  const AiroAnalyticsConsentState.localOnly()
    : this(
        operational: true,
        product: false,
        playbackQuality: false,
        diagnostics: true,
        crash: false,
        personalized: false,
        localOnly: true,
      );

  const AiroAnalyticsConsentState.allEnabled()
    : this(
        operational: true,
        product: true,
        playbackQuality: true,
        diagnostics: true,
        crash: true,
        personalized: true,
      );

  final bool operational;
  final bool product;
  final bool playbackQuality;
  final bool diagnostics;
  final bool crash;
  final bool personalized;
  final bool localOnly;

  bool allows(AiroAnalyticsPurpose purpose) {
    return switch (purpose) {
      AiroAnalyticsPurpose.operational => operational,
      AiroAnalyticsPurpose.product => product,
      AiroAnalyticsPurpose.playbackQuality => playbackQuality,
      AiroAnalyticsPurpose.diagnostics => diagnostics,
      AiroAnalyticsPurpose.crash => crash,
      AiroAnalyticsPurpose.personalized => personalized,
    };
  }

  @override
  List<Object?> get props => [
    operational,
    product,
    playbackQuality,
    diagnostics,
    crash,
    personalized,
    localOnly,
  ];
}

class AiroAnalyticsPrivacyViolation extends Equatable {
  const AiroAnalyticsPrivacyViolation({
    required this.code,
    required this.field,
  });

  final AiroAnalyticsPrivacyCode code;
  final String field;

  @override
  List<Object?> get props => [code, field];
}

class AiroAnalyticsPrivacyResult extends Equatable {
  AiroAnalyticsPrivacyResult({
    required List<AiroAnalyticsPrivacyViolation> violations,
  }) : violations = List.unmodifiable(violations);

  final List<AiroAnalyticsPrivacyViolation> violations;

  bool get isAccepted => violations.isEmpty;

  @override
  List<Object?> get props => [violations];
}

class AiroAnalyticsTrackResult extends Equatable {
  AiroAnalyticsTrackResult({
    required this.status,
    List<AiroAnalyticsPrivacyViolation> violations = const [],
  }) : violations = List.unmodifiable(violations);

  final AiroAnalyticsTrackStatus status;
  final List<AiroAnalyticsPrivacyViolation> violations;

  bool get accepted => status == AiroAnalyticsTrackStatus.accepted;

  @override
  List<Object?> get props => [status, violations];
}

class AiroAnalyticsPrivacyFilter {
  AiroAnalyticsPrivacyFilter({
    Set<String> prohibitedFields = _defaultProhibitedFields,
  }) : prohibitedFields = Set.unmodifiable(
         prohibitedFields.map(_normalizeFieldName),
       );

  static final AiroAnalyticsPrivacyFilter standard =
      AiroAnalyticsPrivacyFilter();

  static const Set<String> _defaultProhibitedFields = {
    'channel',
    'channelName',
    'mediaTitle',
    'movieTitle',
    'programTitle',
    'playlistName',
    'playlistUrl',
    'streamUrl',
    'signedUrl',
    'url',
    'authorization',
    'authHeader',
    'cookie',
    'credential',
    'providerCredential',
    'localPath',
    'path',
    'localIp',
    'ipAddress',
    'query',
    'searchQuery',
    'voiceTranscript',
  };

  final Set<String> prohibitedFields;

  AiroAnalyticsPrivacyResult validate(AiroAnalyticsEvent event) {
    final violations = <AiroAnalyticsPrivacyViolation>[];

    for (final entry in event.params.entries) {
      final field = entry.key;
      final normalized = _normalizeFieldName(field);
      if (prohibitedFields.contains(normalized)) {
        violations.add(
          AiroAnalyticsPrivacyViolation(
            code: AiroAnalyticsPrivacyCode.prohibitedFieldName,
            field: field,
          ),
        );
      }

      final value = entry.value;
      if (value is String) {
        final code = _classifyStringValue(value);
        if (code != null) {
          violations.add(
            AiroAnalyticsPrivacyViolation(code: code, field: field),
          );
        }
      }
    }

    return AiroAnalyticsPrivacyResult(violations: violations);
  }

  static String _normalizeFieldName(String field) {
    return field.replaceAll(RegExp('[^A-Za-z0-9]'), '').toLowerCase();
  }

  static AiroAnalyticsPrivacyCode? _classifyStringValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroAnalyticsPrivacyCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroAnalyticsPrivacyCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroAnalyticsPrivacyCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroAnalyticsPrivacyCode.credentialLikeValue;
    }

    return null;
  }
}

abstract class AiroAnalyticsService {
  Future<AiroAnalyticsTrackResult> track(AiroAnalyticsEvent event);

  Future<void> flush();

  Future<void> reset();
}

class AiroNoOpAnalyticsService implements AiroAnalyticsService {
  const AiroNoOpAnalyticsService({
    this.consent = const AiroAnalyticsConsentState.disabled(),
    this.privacyFilter,
  });

  final AiroAnalyticsConsentState consent;
  final AiroAnalyticsPrivacyFilter? privacyFilter;

  @override
  Future<AiroAnalyticsTrackResult> track(AiroAnalyticsEvent event) async {
    return validateEvent(
      event,
      consent: consent,
      privacyFilter: privacyFilter ?? AiroAnalyticsPrivacyFilter.standard,
    );
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> reset() async {}
}

class AiroLocalDiagnosticsAnalyticsService implements AiroAnalyticsService {
  AiroLocalDiagnosticsAnalyticsService({
    this.consent = const AiroAnalyticsConsentState.localOnly(),
    this.privacyFilter,
    this.maxEvents = 100,
  });

  final AiroAnalyticsConsentState consent;
  final AiroAnalyticsPrivacyFilter? privacyFilter;
  final int maxEvents;
  final List<AiroAnalyticsEvent> _events = [];

  List<AiroAnalyticsEvent> get events => List.unmodifiable(_events);

  @override
  Future<AiroAnalyticsTrackResult> track(AiroAnalyticsEvent event) async {
    final result = validateEvent(
      event,
      consent: consent,
      privacyFilter: privacyFilter ?? AiroAnalyticsPrivacyFilter.standard,
    );
    if (!result.accepted) return result;
    if (_events.length >= maxEvents) {
      return AiroAnalyticsTrackResult(
        status: AiroAnalyticsTrackStatus.droppedQueueFull,
      );
    }

    _events.add(event);
    return result;
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> reset() async {
    _events.clear();
  }
}

AiroAnalyticsTrackResult validateEvent(
  AiroAnalyticsEvent event, {
  required AiroAnalyticsConsentState consent,
  AiroAnalyticsPrivacyFilter? privacyFilter,
}) {
  if (!_isSnakeCase(event.name)) {
    return AiroAnalyticsTrackResult(
      status: AiroAnalyticsTrackStatus.rejectedSchema,
    );
  }

  if (consent.localOnly &&
      event.purpose != AiroAnalyticsPurpose.operational &&
      event.purpose != AiroAnalyticsPurpose.diagnostics) {
    return AiroAnalyticsTrackResult(
      status: AiroAnalyticsTrackStatus.droppedByLocalOnly,
    );
  }

  if (!consent.allows(event.purpose)) {
    return AiroAnalyticsTrackResult(
      status: AiroAnalyticsTrackStatus.droppedByConsent,
    );
  }

  final privacy = (privacyFilter ?? AiroAnalyticsPrivacyFilter.standard)
      .validate(event);
  if (!privacy.isAccepted) {
    return AiroAnalyticsTrackResult(
      status: AiroAnalyticsTrackStatus.rejectedPrivacy,
      violations: privacy.violations,
    );
  }

  return AiroAnalyticsTrackResult(status: AiroAnalyticsTrackStatus.accepted);
}

bool _isSnakeCase(String value) {
  return RegExp(r'^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$').hasMatch(value);
}
