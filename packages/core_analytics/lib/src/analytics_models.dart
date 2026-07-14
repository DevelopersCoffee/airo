// ignore_for_file: prefer_initializing_formals

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

enum AiroAnalyticsProviderKind {
  noOp('no_op'),
  localDiagnostics('local_diagnostics'),
  vendorAdapter('vendor_adapter'),
  selfHosted('self_hosted');

  const AiroAnalyticsProviderKind(this.stableId);

  final String stableId;
}

enum AiroAnalyticsProductProfile {
  fullTv('full_tv'),
  standardTv('standard_tv'),
  liteReceiver('lite_receiver'),
  embeddedReceiver('embedded_receiver'),
  mobileCompanion('mobile_companion'),
  desktopCompanion('desktop_companion');

  const AiroAnalyticsProductProfile(this.stableId);

  final String stableId;
}

enum AiroAnalyticsTrackStatus {
  accepted('accepted'),
  droppedByConsent('dropped_by_consent'),
  droppedByLocalOnly('dropped_by_local_only'),
  droppedByCollectionDisabled('dropped_by_collection_disabled'),
  droppedQueueFull('dropped_queue_full'),
  rejectedPrivacy('rejected_privacy'),
  rejectedSchema('rejected_schema'),
  providerUnavailable('provider_unavailable'),
  timedEventMissing('timed_event_missing');

  const AiroAnalyticsTrackStatus(this.stableId);

  final String stableId;
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

enum AiroAnalyticsConfigurationCode {
  accepted('accepted'),
  queueBudgetInvalid('queue_budget_invalid'),
  externalUploadInLocalOnly('external_upload_in_local_only'),
  vendorSdkNotIsolated('vendor_sdk_not_isolated'),
  playbackMayBlock('playback_may_block'),
  resettableInstallIdMissing('resettable_install_id_missing');

  const AiroAnalyticsConfigurationCode(this.stableId);

  final String stableId;
}

enum AiroAnalyticsLifecycleCode {
  initialized('initialized'),
  disabled('disabled'),
  invalidConfiguration('invalid_configuration');

  const AiroAnalyticsLifecycleCode(this.stableId);

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

class AiroAnalyticsConfigurationResult extends Equatable {
  AiroAnalyticsConfigurationResult({
    required List<AiroAnalyticsConfigurationCode> codes,
  }) : codes = List.unmodifiable(codes);

  final List<AiroAnalyticsConfigurationCode> codes;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == AiroAnalyticsConfigurationCode.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [codes];
}

class AiroAnalyticsServiceConfiguration extends Equatable {
  const AiroAnalyticsServiceConfiguration({
    required this.providerKind,
    required this.productProfile,
    this.consent = const AiroAnalyticsConsentState.disabled(),
    this.collectionEnabled = false,
    this.maxQueueEvents = 0,
    this.externalUploadAllowed = false,
    this.providerSdkIsolated = true,
    this.nonBlocking = true,
    this.resettableInstallationId = true,
    this.schemaVersion = kAiroAnalyticsSchemaVersion,
  });

  final String schemaVersion;
  final AiroAnalyticsProviderKind providerKind;
  final AiroAnalyticsProductProfile productProfile;
  final AiroAnalyticsConsentState consent;
  final bool collectionEnabled;
  final int maxQueueEvents;
  final bool externalUploadAllowed;
  final bool providerSdkIsolated;
  final bool nonBlocking;
  final bool resettableInstallationId;

  AiroAnalyticsConfigurationResult validate() {
    final codes = <AiroAnalyticsConfigurationCode>[];
    if (maxQueueEvents < 0) {
      codes.add(AiroAnalyticsConfigurationCode.queueBudgetInvalid);
    }
    if (consent.localOnly && externalUploadAllowed) {
      codes.add(AiroAnalyticsConfigurationCode.externalUploadInLocalOnly);
    }
    if (providerKind == AiroAnalyticsProviderKind.vendorAdapter &&
        !providerSdkIsolated) {
      codes.add(AiroAnalyticsConfigurationCode.vendorSdkNotIsolated);
    }
    if (!nonBlocking) {
      codes.add(AiroAnalyticsConfigurationCode.playbackMayBlock);
    }
    if (!resettableInstallationId) {
      codes.add(AiroAnalyticsConfigurationCode.resettableInstallIdMissing);
    }
    return AiroAnalyticsConfigurationResult(
      codes: codes.isEmpty
          ? const [AiroAnalyticsConfigurationCode.accepted]
          : codes,
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'providerKind': providerKind.stableId,
      'productProfile': productProfile.stableId,
      'collectionEnabled': collectionEnabled,
      'maxQueueEvents': maxQueueEvents,
      'externalUploadAllowed': externalUploadAllowed,
      'providerSdkIsolated': providerSdkIsolated,
      'nonBlocking': nonBlocking,
      'resettableInstallationId': resettableInstallationId,
      'consent': {
        'operational': consent.operational,
        'product': consent.product,
        'playbackQuality': consent.playbackQuality,
        'diagnostics': consent.diagnostics,
        'crash': consent.crash,
        'personalized': consent.personalized,
        'localOnly': consent.localOnly,
      },
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    providerKind,
    productProfile,
    consent,
    collectionEnabled,
    maxQueueEvents,
    externalUploadAllowed,
    providerSdkIsolated,
    nonBlocking,
    resettableInstallationId,
  ];
}

class AiroAnalyticsLifecycleResult extends Equatable {
  const AiroAnalyticsLifecycleResult({
    required this.code,
    this.configurationResult,
  });

  final AiroAnalyticsLifecycleCode code;
  final AiroAnalyticsConfigurationResult? configurationResult;

  bool get accepted => code == AiroAnalyticsLifecycleCode.initialized;

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'code': code.stableId,
      'configurationResult': configurationResult?.toPublicMap(),
    };
  }

  @override
  List<Object?> get props => [code, configurationResult];
}

class AiroAnalyticsTrackResult extends Equatable {
  AiroAnalyticsTrackResult({
    required this.status,
    List<AiroAnalyticsPrivacyViolation> violations = const [],
  }) : violations = List.unmodifiable(violations);

  final AiroAnalyticsTrackStatus status;
  final List<AiroAnalyticsPrivacyViolation> violations;

  bool get accepted => status == AiroAnalyticsTrackStatus.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'status': status.stableId,
      'violations': violations
          .map(
            (violation) => {
              'code': violation.code.stableId,
              'field': violation.field,
            },
          )
          .toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [status, violations];
}

class AiroAnalyticsTimedEventHandle extends Equatable {
  AiroAnalyticsTimedEventHandle({
    required this.eventName,
    required this.owner,
    required this.purpose,
    required this.startedAt,
    Map<String, Object?> params = const {},
    this.priority = AiroAnalyticsPriority.normal,
  }) : params = Map.unmodifiable(params);

  final String eventName;
  final String owner;
  final AiroAnalyticsPurpose purpose;
  final DateTime startedAt;
  final Map<String, Object?> params;
  final AiroAnalyticsPriority priority;

  AiroAnalyticsEvent complete({required DateTime endedAt}) {
    final durationMs = endedAt.difference(startedAt).inMilliseconds;
    return AiroAnalyticsEvent(
      name: eventName,
      owner: owner,
      purpose: purpose,
      priority: priority,
      params: {...params, 'duration_bucket': _durationBucket(durationMs)},
    );
  }

  @override
  List<Object?> get props => [
    eventName,
    owner,
    purpose,
    startedAt,
    params,
    priority,
  ];
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
  Future<AiroAnalyticsLifecycleResult> initialize(
    AiroAnalyticsServiceConfiguration configuration,
  ) async {
    final result = configuration.validate();
    if (!result.accepted) {
      return AiroAnalyticsLifecycleResult(
        code: AiroAnalyticsLifecycleCode.invalidConfiguration,
        configurationResult: result,
      );
    }
    if (!configuration.collectionEnabled) {
      return AiroAnalyticsLifecycleResult(
        code: AiroAnalyticsLifecycleCode.disabled,
        configurationResult: result,
      );
    }
    return AiroAnalyticsLifecycleResult(
      code: AiroAnalyticsLifecycleCode.initialized,
      configurationResult: result,
    );
  }

  Future<AiroAnalyticsTrackResult> track(AiroAnalyticsEvent event);

  AiroAnalyticsTimedEventHandle startTimedEvent({
    required String eventName,
    required String owner,
    required AiroAnalyticsPurpose purpose,
    required DateTime startedAt,
    Map<String, Object?> params = const {},
    AiroAnalyticsPriority priority = AiroAnalyticsPriority.normal,
  }) {
    return AiroAnalyticsTimedEventHandle(
      eventName: eventName,
      owner: owner,
      purpose: purpose,
      startedAt: startedAt,
      params: params,
      priority: priority,
    );
  }

  Future<AiroAnalyticsTrackResult> endTimedEvent({
    required AiroAnalyticsTimedEventHandle handle,
    required DateTime endedAt,
  }) {
    return track(handle.complete(endedAt: endedAt));
  }

  Future<void> updateConsent(AiroAnalyticsConsentState consent) async {}

  Future<void> setCollectionEnabled(bool enabled) async {}

  Future<void> flush();

  Future<void> reset();
}

typedef AiroAnalyticsProviderSender =
    Future<void> Function(AiroAnalyticsEvent event);

class AiroNoOpAnalyticsService implements AiroAnalyticsService {
  const AiroNoOpAnalyticsService({
    this.consent = const AiroAnalyticsConsentState.disabled(),
    this.privacyFilter,
    this.collectionEnabled = true,
  });

  final AiroAnalyticsConsentState consent;
  final AiroAnalyticsPrivacyFilter? privacyFilter;
  final bool collectionEnabled;

  @override
  Future<AiroAnalyticsLifecycleResult> initialize(
    AiroAnalyticsServiceConfiguration configuration,
  ) {
    return _initializeAnalyticsService(configuration);
  }

  @override
  Future<AiroAnalyticsTrackResult> track(AiroAnalyticsEvent event) async {
    return validateEvent(
      event,
      consent: consent,
      privacyFilter: privacyFilter ?? AiroAnalyticsPrivacyFilter.standard,
      collectionEnabled: collectionEnabled,
    );
  }

  @override
  AiroAnalyticsTimedEventHandle startTimedEvent({
    required String eventName,
    required String owner,
    required AiroAnalyticsPurpose purpose,
    required DateTime startedAt,
    Map<String, Object?> params = const {},
    AiroAnalyticsPriority priority = AiroAnalyticsPriority.normal,
  }) {
    return AiroAnalyticsTimedEventHandle(
      eventName: eventName,
      owner: owner,
      purpose: purpose,
      startedAt: startedAt,
      params: params,
      priority: priority,
    );
  }

  @override
  Future<AiroAnalyticsTrackResult> endTimedEvent({
    required AiroAnalyticsTimedEventHandle handle,
    required DateTime endedAt,
  }) {
    return track(handle.complete(endedAt: endedAt));
  }

  @override
  Future<void> updateConsent(AiroAnalyticsConsentState consent) async {}

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> reset() async {}
}

class AiroLocalDiagnosticsAnalyticsService implements AiroAnalyticsService {
  AiroLocalDiagnosticsAnalyticsService({
    AiroAnalyticsConsentState consent =
        const AiroAnalyticsConsentState.localOnly(),
    this.privacyFilter,
    this.maxEvents = 100,
    bool collectionEnabled = true,
  }) : _consent = consent,
       _collectionEnabled = collectionEnabled;

  final AiroAnalyticsPrivacyFilter? privacyFilter;
  final int maxEvents;
  final List<AiroAnalyticsEvent> _events = [];
  AiroAnalyticsConsentState _consent;
  bool _collectionEnabled;

  List<AiroAnalyticsEvent> get events => List.unmodifiable(_events);
  AiroAnalyticsConsentState get consent => _consent;
  bool get collectionEnabled => _collectionEnabled;

  @override
  Future<AiroAnalyticsLifecycleResult> initialize(
    AiroAnalyticsServiceConfiguration configuration,
  ) {
    return _initializeAnalyticsService(configuration);
  }

  @override
  Future<AiroAnalyticsTrackResult> track(AiroAnalyticsEvent event) async {
    final result = validateEvent(
      event,
      consent: _consent,
      privacyFilter: privacyFilter ?? AiroAnalyticsPrivacyFilter.standard,
      collectionEnabled: _collectionEnabled,
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
  AiroAnalyticsTimedEventHandle startTimedEvent({
    required String eventName,
    required String owner,
    required AiroAnalyticsPurpose purpose,
    required DateTime startedAt,
    Map<String, Object?> params = const {},
    AiroAnalyticsPriority priority = AiroAnalyticsPriority.normal,
  }) {
    return AiroAnalyticsTimedEventHandle(
      eventName: eventName,
      owner: owner,
      purpose: purpose,
      startedAt: startedAt,
      params: params,
      priority: priority,
    );
  }

  @override
  Future<AiroAnalyticsTrackResult> endTimedEvent({
    required AiroAnalyticsTimedEventHandle handle,
    required DateTime endedAt,
  }) {
    return track(handle.complete(endedAt: endedAt));
  }

  @override
  Future<void> updateConsent(AiroAnalyticsConsentState consent) async {
    _consent = consent;
    _events.removeWhere((event) {
      return validateEvent(
            event,
            consent: _consent,
            privacyFilter: privacyFilter ?? AiroAnalyticsPrivacyFilter.standard,
            collectionEnabled: _collectionEnabled,
          ).status !=
          AiroAnalyticsTrackStatus.accepted;
    });
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    _collectionEnabled = enabled;
    if (!enabled) {
      _events.clear();
    }
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> reset() async {
    _events.clear();
  }
}

class AiroProviderBackedAnalyticsService implements AiroAnalyticsService {
  AiroProviderBackedAnalyticsService({
    required AiroAnalyticsProviderSender sender,
    AiroAnalyticsConsentState consent =
        const AiroAnalyticsConsentState.disabled(),
    this.privacyFilter,
    bool collectionEnabled = false,
  }) : _sender = sender,
       _consent = consent,
       _collectionEnabled = collectionEnabled;

  final AiroAnalyticsProviderSender _sender;
  final AiroAnalyticsPrivacyFilter? privacyFilter;
  AiroAnalyticsConsentState _consent;
  bool _collectionEnabled;

  AiroAnalyticsConsentState get consent => _consent;
  bool get collectionEnabled => _collectionEnabled;

  @override
  Future<AiroAnalyticsLifecycleResult> initialize(
    AiroAnalyticsServiceConfiguration configuration,
  ) async {
    final result = await _initializeAnalyticsService(configuration);
    if (result.accepted) {
      _consent = configuration.consent;
      _collectionEnabled = configuration.collectionEnabled;
    }
    return result;
  }

  @override
  Future<AiroAnalyticsTrackResult> track(AiroAnalyticsEvent event) async {
    final result = validateEvent(
      event,
      consent: _consent,
      privacyFilter: privacyFilter ?? AiroAnalyticsPrivacyFilter.standard,
      collectionEnabled: _collectionEnabled,
    );
    if (!result.accepted) return result;

    try {
      await _sender(event);
      return result;
    } catch (_) {
      return AiroAnalyticsTrackResult(
        status: AiroAnalyticsTrackStatus.providerUnavailable,
      );
    }
  }

  @override
  AiroAnalyticsTimedEventHandle startTimedEvent({
    required String eventName,
    required String owner,
    required AiroAnalyticsPurpose purpose,
    required DateTime startedAt,
    Map<String, Object?> params = const {},
    AiroAnalyticsPriority priority = AiroAnalyticsPriority.normal,
  }) {
    return AiroAnalyticsTimedEventHandle(
      eventName: eventName,
      owner: owner,
      purpose: purpose,
      startedAt: startedAt,
      params: params,
      priority: priority,
    );
  }

  @override
  Future<AiroAnalyticsTrackResult> endTimedEvent({
    required AiroAnalyticsTimedEventHandle handle,
    required DateTime endedAt,
  }) {
    return track(handle.complete(endedAt: endedAt));
  }

  @override
  Future<void> updateConsent(AiroAnalyticsConsentState consent) async {
    _consent = consent;
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    _collectionEnabled = enabled;
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> reset() async {}
}

AiroAnalyticsTrackResult validateEvent(
  AiroAnalyticsEvent event, {
  required AiroAnalyticsConsentState consent,
  AiroAnalyticsPrivacyFilter? privacyFilter,
  bool collectionEnabled = true,
}) {
  if (!collectionEnabled) {
    return AiroAnalyticsTrackResult(
      status: AiroAnalyticsTrackStatus.droppedByCollectionDisabled,
    );
  }

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

Future<AiroAnalyticsLifecycleResult> _initializeAnalyticsService(
  AiroAnalyticsServiceConfiguration configuration,
) async {
  final result = configuration.validate();
  if (!result.accepted) {
    return AiroAnalyticsLifecycleResult(
      code: AiroAnalyticsLifecycleCode.invalidConfiguration,
      configurationResult: result,
    );
  }
  if (!configuration.collectionEnabled) {
    return AiroAnalyticsLifecycleResult(
      code: AiroAnalyticsLifecycleCode.disabled,
      configurationResult: result,
    );
  }
  return AiroAnalyticsLifecycleResult(
    code: AiroAnalyticsLifecycleCode.initialized,
    configurationResult: result,
  );
}

String _durationBucket(int durationMs) {
  if (durationMs < 0) return 'invalid';
  if (durationMs < 1000) return '0_1s';
  if (durationMs < 3000) return '1_3s';
  if (durationMs < 10000) return '3_10s';
  if (durationMs < 30000) return '10_30s';
  return '30s_plus';
}

bool _isSnakeCase(String value) {
  return RegExp(r'^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$').hasMatch(value);
}
