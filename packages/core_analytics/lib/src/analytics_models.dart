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

enum AiroAnalyticsConsentTransitionCode {
  accepted('accepted'),
  optionalQueueCleared('optional_queue_cleared'),
  localOnlyExternalUploadBlocked('local_only_external_upload_blocked'),
  collectionDisabled('collection_disabled'),
  analyticsIdentityReset('analytics_identity_reset');

  const AiroAnalyticsConsentTransitionCode(this.stableId);

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

enum AiroAnalyticsPrivacySampleClass {
  approvedBucket('approved_bucket'),
  approvedCategory('approved_category'),
  urlLike('url_like'),
  localPathLike('local_path_like'),
  localIpLike('local_ip_like'),
  credentialLike('credential_like'),
  rawQueryField('raw_query_field'),
  rawTitleField('raw_title_field'),
  rawSourceField('raw_source_field'),
  authHeaderField('auth_header_field');

  const AiroAnalyticsPrivacySampleClass(this.stableId);

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

enum AiroAnalyticsFieldKind {
  stableIdentifier('stable_id'),
  category('category'),
  bucket('bucket'),
  count('count'),
  decimal('decimal'),
  boolean('boolean');

  const AiroAnalyticsFieldKind(this.stableId);

  final String stableId;
}

enum AiroAnalyticsRetentionClass {
  operational30Days('operational_30_days', 30),
  product90Days('product_90_days', 90),
  diagnostics30Days('diagnostics_30_days', 30),
  crash90Days('crash_90_days', 90),
  aggregateOnly('aggregate_only', 0);

  const AiroAnalyticsRetentionClass(this.stableId, this.days);

  final String stableId;
  final int days;
}

enum AiroAnalyticsDashboardRequirement {
  none('none'),
  optional('optional'),
  required('required');

  const AiroAnalyticsDashboardRequirement(this.stableId);

  final String stableId;
}

enum AiroAnalyticsSchemaValidationCode {
  accepted('accepted'),
  schemaMissing('schema_missing'),
  duplicateSchema('duplicate_schema'),
  ownerMismatch('owner_mismatch'),
  purposeMismatch('purpose_mismatch'),
  schemaVersionMismatch('schema_version_mismatch'),
  requiredFieldMissing('required_field_missing'),
  fieldNotAllowed('field_not_allowed'),
  fieldKindMismatch('field_kind_mismatch'),
  prohibitedFieldAllowed('prohibited_field_allowed'),
  privacyViolation('privacy_violation'),
  retentionInvalid('retention_invalid'),
  testCoverageMissing('test_coverage_missing');

  const AiroAnalyticsSchemaValidationCode(this.stableId);

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

class AiroAnalyticsPrivacyFilterTestCase extends Equatable {
  const AiroAnalyticsPrivacyFilterTestCase({
    required this.caseId,
    required this.field,
    required this.value,
    required this.sampleClass,
    this.expectedCode,
  });

  final String caseId;
  final String field;
  final Object? value;
  final AiroAnalyticsPrivacySampleClass sampleClass;
  final AiroAnalyticsPrivacyCode? expectedCode;

  bool get shouldReject => expectedCode != null;

  AiroAnalyticsEvent toEvent() {
    return AiroAnalyticsEvent(
      name: 'privacy_filter_probe',
      owner: 'security',
      purpose: AiroAnalyticsPurpose.diagnostics,
      params: {field: value},
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'caseId': caseId,
      'field': field,
      'sampleClass': sampleClass.stableId,
      'expectedCode': expectedCode?.stableId,
      'shouldReject': shouldReject,
    };
  }

  @override
  List<Object?> get props => [caseId, field, value, sampleClass, expectedCode];
}

class AiroAnalyticsPrivacyFilterTestSuite extends Equatable {
  AiroAnalyticsPrivacyFilterTestSuite({
    required this.suiteId,
    required Iterable<AiroAnalyticsPrivacyFilterTestCase> cases,
    this.schemaVersion = kAiroAnalyticsSchemaVersion,
  }) : cases = List.unmodifiable(cases);

  final String schemaVersion;
  final String suiteId;
  final List<AiroAnalyticsPrivacyFilterTestCase> cases;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'suiteId': suiteId,
      'cases': cases
          .map((testCase) => testCase.toPublicMap())
          .toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [schemaVersion, suiteId, cases];
}

class AiroAnalyticsSchemaValidationResult extends Equatable {
  AiroAnalyticsSchemaValidationResult({
    required List<AiroAnalyticsSchemaValidationCode> codes,
    List<AiroAnalyticsPrivacyViolation> privacyViolations = const [],
  }) : codes = List.unmodifiable(codes),
       privacyViolations = List.unmodifiable(privacyViolations);

  final List<AiroAnalyticsSchemaValidationCode> codes;
  final List<AiroAnalyticsPrivacyViolation> privacyViolations;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == AiroAnalyticsSchemaValidationCode.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
      'privacyViolations': privacyViolations
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
  List<Object?> get props => [codes, privacyViolations];
}

class AiroAnalyticsFieldSchema extends Equatable {
  const AiroAnalyticsFieldSchema({
    required this.name,
    required this.kind,
    this.required = false,
  });

  final String name;
  final AiroAnalyticsFieldKind kind;
  final bool required;

  Map<String, Object?> toPublicMap() {
    return {'name': name, 'kind': kind.stableId, 'required': required};
  }

  @override
  List<Object?> get props => [name, kind, required];
}

class AiroAnalyticsEventSchema extends Equatable {
  AiroAnalyticsEventSchema({
    required this.name,
    required this.owner,
    required this.purpose,
    required List<AiroAnalyticsFieldSchema> allowedFields,
    Set<String> prohibitedFields = const {},
    required this.retentionClass,
    required this.dashboardRequirement,
    this.testsRequired = true,
    this.schemaVersion = kAiroAnalyticsSchemaVersion,
  }) : allowedFields = List.unmodifiable(allowedFields),
       prohibitedFields = Set.unmodifiable(
         prohibitedFields.map(AiroAnalyticsPrivacyFilter.normalizeFieldName),
       );

  final String schemaVersion;
  final String name;
  final String owner;
  final AiroAnalyticsPurpose purpose;
  final List<AiroAnalyticsFieldSchema> allowedFields;
  final Set<String> prohibitedFields;
  final AiroAnalyticsRetentionClass retentionClass;
  final AiroAnalyticsDashboardRequirement dashboardRequirement;
  final bool testsRequired;

  Set<String> get allowedFieldNames =>
      allowedFields.map((field) => field.name).toSet();

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'name': name,
      'owner': owner,
      'purpose': purpose.stableId,
      'allowedFields': allowedFields
          .map((field) => field.toPublicMap())
          .toList(growable: false),
      'prohibitedFields': prohibitedFields.toList(growable: false)..sort(),
      'retentionClass': retentionClass.stableId,
      'retentionDays': retentionClass.days,
      'dashboardRequirement': dashboardRequirement.stableId,
      'testsRequired': testsRequired,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    name,
    owner,
    purpose,
    allowedFields,
    prohibitedFields,
    retentionClass,
    dashboardRequirement,
    testsRequired,
  ];
}

class AiroAnalyticsSchemaRegistry extends Equatable {
  AiroAnalyticsSchemaRegistry({
    required Iterable<AiroAnalyticsEventSchema> schemas,
    this.privacyFilter,
    this.schemaVersion = kAiroAnalyticsSchemaVersion,
  }) : schemas = List.unmodifiable(schemas);

  final String schemaVersion;
  final List<AiroAnalyticsEventSchema> schemas;
  final AiroAnalyticsPrivacyFilter? privacyFilter;

  AiroAnalyticsEventSchema? schemaFor(String eventName) {
    for (final schema in schemas) {
      if (schema.name == eventName) return schema;
    }
    return null;
  }

  AiroAnalyticsSchemaValidationResult validateRegistry() {
    final codes = <AiroAnalyticsSchemaValidationCode>[];
    final seenNames = <String>{};
    for (final schema in schemas) {
      if (!seenNames.add(schema.name)) {
        codes.add(AiroAnalyticsSchemaValidationCode.duplicateSchema);
      }
      if (schema.retentionClass != AiroAnalyticsRetentionClass.aggregateOnly &&
          schema.retentionClass.days <= 0) {
        codes.add(AiroAnalyticsSchemaValidationCode.retentionInvalid);
      }
      if (schema.testsRequired == false) {
        codes.add(AiroAnalyticsSchemaValidationCode.testCoverageMissing);
      }
      final allowedNormalized = schema.allowedFields
          .map(
            (field) =>
                AiroAnalyticsPrivacyFilter.normalizeFieldName(field.name),
          )
          .toSet();
      final prohibited = {
        ...schema.prohibitedFields,
        ...AiroAnalyticsPrivacyFilter.standard.prohibitedFields,
      };
      if (allowedNormalized.any(prohibited.contains)) {
        codes.add(AiroAnalyticsSchemaValidationCode.prohibitedFieldAllowed);
      }
    }
    return AiroAnalyticsSchemaValidationResult(
      codes: codes.isEmpty
          ? const [AiroAnalyticsSchemaValidationCode.accepted]
          : codes.toSet().toList(growable: false),
    );
  }

  AiroAnalyticsSchemaValidationResult validateEvent(AiroAnalyticsEvent event) {
    final schema = schemaFor(event.name);
    if (schema == null) {
      return AiroAnalyticsSchemaValidationResult(
        codes: const [AiroAnalyticsSchemaValidationCode.schemaMissing],
      );
    }

    final codes = <AiroAnalyticsSchemaValidationCode>[];
    if (event.owner != schema.owner) {
      codes.add(AiroAnalyticsSchemaValidationCode.ownerMismatch);
    }
    if (event.purpose != schema.purpose) {
      codes.add(AiroAnalyticsSchemaValidationCode.purposeMismatch);
    }
    if (event.schemaVersion != schema.schemaVersion) {
      codes.add(AiroAnalyticsSchemaValidationCode.schemaVersionMismatch);
    }

    final fieldsByName = {
      for (final field in schema.allowedFields) field.name: field,
    };
    for (final field in schema.allowedFields.where((field) => field.required)) {
      if (!event.params.containsKey(field.name)) {
        codes.add(AiroAnalyticsSchemaValidationCode.requiredFieldMissing);
        break;
      }
    }
    for (final entry in event.params.entries) {
      final field = fieldsByName[entry.key];
      if (field == null) {
        codes.add(AiroAnalyticsSchemaValidationCode.fieldNotAllowed);
        continue;
      }
      if (!_matchesFieldKind(field.kind, entry.value)) {
        codes.add(AiroAnalyticsSchemaValidationCode.fieldKindMismatch);
      }
    }

    final privacy = (privacyFilter ?? AiroAnalyticsPrivacyFilter.standard)
        .validate(event);
    if (!privacy.isAccepted) {
      codes.add(AiroAnalyticsSchemaValidationCode.privacyViolation);
    }

    return AiroAnalyticsSchemaValidationResult(
      codes: codes.isEmpty
          ? const [AiroAnalyticsSchemaValidationCode.accepted]
          : codes.toSet().toList(growable: false),
      privacyViolations: privacy.violations,
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'schemas': schemas
          .map((schema) => schema.toPublicMap())
          .toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [schemaVersion, schemas, privacyFilter];
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
      'consent': _consentToPublicMap(consent),
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

class AiroAnalyticsConsentTransitionResult extends Equatable {
  AiroAnalyticsConsentTransitionResult({
    required this.previousConsent,
    required this.nextConsent,
    required List<AiroAnalyticsConsentTransitionCode> codes,
    this.removedEventCount = 0,
    this.resetGeneration = 0,
  }) : codes = List.unmodifiable(codes);

  final AiroAnalyticsConsentState previousConsent;
  final AiroAnalyticsConsentState nextConsent;
  final List<AiroAnalyticsConsentTransitionCode> codes;
  final int removedEventCount;
  final int resetGeneration;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == AiroAnalyticsConsentTransitionCode.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
      'removedEventCount': removedEventCount,
      'resetGeneration': resetGeneration,
      'previousConsent': _consentToPublicMap(previousConsent),
      'nextConsent': _consentToPublicMap(nextConsent),
    };
  }

  @override
  List<Object?> get props => [
    previousConsent,
    nextConsent,
    codes,
    removedEventCount,
    resetGeneration,
  ];
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
         prohibitedFields.map(normalizeFieldName),
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
      final normalized = normalizeFieldName(field);
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

  static String normalizeFieldName(String field) {
    return field.replaceAll(RegExp('[^A-Za-z0-9]'), '').toLowerCase();
  }

  static AiroAnalyticsPrivacyCode? _classifyStringValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null &&
        const {'http', 'https', 'rtsp', 'rtmp'}.contains(uri.scheme)) {
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

  Future<AiroAnalyticsConsentTransitionResult> updateConsent(
    AiroAnalyticsConsentState consent,
  ) async {
    return AiroAnalyticsConsentTransitionPolicy.evaluate(
      previousConsent: const AiroAnalyticsConsentState.disabled(),
      nextConsent: consent,
    );
  }

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
  Future<AiroAnalyticsConsentTransitionResult> updateConsent(
    AiroAnalyticsConsentState consent,
  ) async {
    return AiroAnalyticsConsentTransitionPolicy.evaluate(
      previousConsent: this.consent,
      nextConsent: consent,
      collectionEnabled: collectionEnabled,
    );
  }

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
  int _resetGeneration = 0;

  List<AiroAnalyticsEvent> get events => List.unmodifiable(_events);
  AiroAnalyticsConsentState get consent => _consent;
  bool get collectionEnabled => _collectionEnabled;
  int get resetGeneration => _resetGeneration;

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
  Future<AiroAnalyticsConsentTransitionResult> updateConsent(
    AiroAnalyticsConsentState consent,
  ) async {
    final previousConsent = _consent;
    _consent = consent;
    final previousCount = _events.length;
    _events.removeWhere((event) {
      return validateEvent(
            event,
            consent: _consent,
            privacyFilter: privacyFilter ?? AiroAnalyticsPrivacyFilter.standard,
            collectionEnabled: _collectionEnabled,
          ).status !=
          AiroAnalyticsTrackStatus.accepted;
    });
    return AiroAnalyticsConsentTransitionPolicy.evaluate(
      previousConsent: previousConsent,
      nextConsent: _consent,
      removedEventCount: previousCount - _events.length,
      collectionEnabled: _collectionEnabled,
      resetGeneration: _resetGeneration,
    );
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
    _resetGeneration += 1;
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
  int _resetGeneration = 0;

  AiroAnalyticsConsentState get consent => _consent;
  bool get collectionEnabled => _collectionEnabled;
  int get resetGeneration => _resetGeneration;

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
  Future<AiroAnalyticsConsentTransitionResult> updateConsent(
    AiroAnalyticsConsentState consent,
  ) async {
    final previousConsent = _consent;
    _consent = consent;
    return AiroAnalyticsConsentTransitionPolicy.evaluate(
      previousConsent: previousConsent,
      nextConsent: _consent,
      collectionEnabled: _collectionEnabled,
      resetGeneration: _resetGeneration,
    );
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    _collectionEnabled = enabled;
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> reset() async {
    _resetGeneration += 1;
  }
}

class AiroAnalyticsConsentTransitionPolicy {
  const AiroAnalyticsConsentTransitionPolicy._();

  static AiroAnalyticsConsentTransitionResult evaluate({
    required AiroAnalyticsConsentState previousConsent,
    required AiroAnalyticsConsentState nextConsent,
    int removedEventCount = 0,
    bool collectionEnabled = true,
    int resetGeneration = 0,
  }) {
    final codes = <AiroAnalyticsConsentTransitionCode>[];
    if (removedEventCount > 0) {
      codes.add(AiroAnalyticsConsentTransitionCode.optionalQueueCleared);
    }
    if (nextConsent.localOnly) {
      codes.add(
        AiroAnalyticsConsentTransitionCode.localOnlyExternalUploadBlocked,
      );
    }
    if (!collectionEnabled) {
      codes.add(AiroAnalyticsConsentTransitionCode.collectionDisabled);
    }
    if (resetGeneration > 0) {
      codes.add(AiroAnalyticsConsentTransitionCode.analyticsIdentityReset);
    }

    return AiroAnalyticsConsentTransitionResult(
      previousConsent: previousConsent,
      nextConsent: nextConsent,
      codes: codes.isEmpty
          ? const [AiroAnalyticsConsentTransitionCode.accepted]
          : codes,
      removedEventCount: removedEventCount,
      resetGeneration: resetGeneration,
    );
  }
}

class AiroTvAnalyticsSchemas {
  const AiroTvAnalyticsSchemas._();

  static AiroAnalyticsSchemaRegistry registry() {
    return AiroAnalyticsSchemaRegistry(
      schemas: [
        playbackStartupCompleted(),
        pairingCompleted(),
        handoffCompleted(),
        legacyDecoderFallback(),
        subscriptionConversion(),
      ],
    );
  }

  static AiroAnalyticsEventSchema playbackStartupCompleted() {
    return AiroAnalyticsEventSchema(
      name: 'playback_startup_completed',
      owner: 'media',
      purpose: AiroAnalyticsPurpose.playbackQuality,
      retentionClass: AiroAnalyticsRetentionClass.product90Days,
      dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
      prohibitedFields: const {
        'channel',
        'mediaTitle',
        'streamUrl',
        'playlistUrl',
        'query',
      },
      allowedFields: const [
        AiroAnalyticsFieldSchema(
          name: 'source_type',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'startup_bucket',
          kind: AiroAnalyticsFieldKind.bucket,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'decoder_type',
          kind: AiroAnalyticsFieldKind.category,
        ),
        AiroAnalyticsFieldSchema(
          name: 'resolution_bucket',
          kind: AiroAnalyticsFieldKind.bucket,
        ),
      ],
    );
  }

  static AiroAnalyticsEventSchema pairingCompleted() {
    return AiroAnalyticsEventSchema(
      name: 'pairing_completed',
      owner: 'device_ecosystem',
      purpose: AiroAnalyticsPurpose.operational,
      retentionClass: AiroAnalyticsRetentionClass.operational30Days,
      dashboardRequirement: AiroAnalyticsDashboardRequirement.optional,
      allowedFields: const [
        AiroAnalyticsFieldSchema(
          name: 'source_profile',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'target_profile',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'route_type',
          kind: AiroAnalyticsFieldKind.category,
        ),
      ],
    );
  }

  static AiroAnalyticsEventSchema handoffCompleted() {
    return AiroAnalyticsEventSchema(
      name: 'handoff_completed',
      owner: 'media',
      purpose: AiroAnalyticsPurpose.operational,
      retentionClass: AiroAnalyticsRetentionClass.operational30Days,
      dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
      allowedFields: const [
        AiroAnalyticsFieldSchema(
          name: 'source_profile',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'target_profile',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'result_category',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
      ],
    );
  }

  static AiroAnalyticsEventSchema legacyDecoderFallback() {
    return AiroAnalyticsEventSchema(
      name: 'legacy_decoder_fallback',
      owner: 'platform_media',
      purpose: AiroAnalyticsPurpose.diagnostics,
      retentionClass: AiroAnalyticsRetentionClass.diagnostics30Days,
      dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
      allowedFields: const [
        AiroAnalyticsFieldSchema(
          name: 'device_tier',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'decoder_type',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'fallback_count',
          kind: AiroAnalyticsFieldKind.count,
        ),
      ],
    );
  }

  static AiroAnalyticsEventSchema subscriptionConversion() {
    return AiroAnalyticsEventSchema(
      name: 'subscription_conversion',
      owner: 'growth',
      purpose: AiroAnalyticsPurpose.product,
      retentionClass: AiroAnalyticsRetentionClass.product90Days,
      dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
      allowedFields: const [
        AiroAnalyticsFieldSchema(
          name: 'entry_surface',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'plan_bucket',
          kind: AiroAnalyticsFieldKind.bucket,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'success',
          kind: AiroAnalyticsFieldKind.boolean,
          required: true,
        ),
      ],
    );
  }
}

class AiroTvAnalyticsPrivacyFilterSuites {
  const AiroTvAnalyticsPrivacyFilterSuites._();

  static AiroAnalyticsPrivacyFilterTestSuite standard() {
    return AiroAnalyticsPrivacyFilterTestSuite(
      suiteId: 'airo-tv-analytics-privacy-filter',
      cases: const [
        AiroAnalyticsPrivacyFilterTestCase(
          caseId: 'approved-source-type',
          field: 'source_type',
          value: 'iptv',
          sampleClass: AiroAnalyticsPrivacySampleClass.approvedCategory,
        ),
        AiroAnalyticsPrivacyFilterTestCase(
          caseId: 'approved-startup-bucket',
          field: 'startup_bucket',
          value: '1_3s',
          sampleClass: AiroAnalyticsPrivacySampleClass.approvedBucket,
        ),
        AiroAnalyticsPrivacyFilterTestCase(
          caseId: 'stream-url-value',
          field: 'source_type',
          value: 'https://example.com/live.m3u8',
          sampleClass: AiroAnalyticsPrivacySampleClass.urlLike,
          expectedCode: AiroAnalyticsPrivacyCode.urlValue,
        ),
        AiroAnalyticsPrivacyFilterTestCase(
          caseId: 'rtsp-url-value',
          field: 'source_type',
          value: 'rtsp://camera.example/live',
          sampleClass: AiroAnalyticsPrivacySampleClass.urlLike,
          expectedCode: AiroAnalyticsPrivacyCode.urlValue,
        ),
        AiroAnalyticsPrivacyFilterTestCase(
          caseId: 'local-path-value',
          field: 'storage_bucket',
          value: '/Users/example/video.ts',
          sampleClass: AiroAnalyticsPrivacySampleClass.localPathLike,
          expectedCode: AiroAnalyticsPrivacyCode.localPathValue,
        ),
        AiroAnalyticsPrivacyFilterTestCase(
          caseId: 'local-ip-value',
          field: 'network_bucket',
          value: 'route 192.168.1.10',
          sampleClass: AiroAnalyticsPrivacySampleClass.localIpLike,
          expectedCode: AiroAnalyticsPrivacyCode.localIpValue,
        ),
        AiroAnalyticsPrivacyFilterTestCase(
          caseId: 'credential-like-value',
          field: 'auth_bucket',
          value: 'Bearer abc.def',
          sampleClass: AiroAnalyticsPrivacySampleClass.credentialLike,
          expectedCode: AiroAnalyticsPrivacyCode.credentialLikeValue,
        ),
        AiroAnalyticsPrivacyFilterTestCase(
          caseId: 'auth-header-field',
          field: 'authorization',
          value: 'present',
          sampleClass: AiroAnalyticsPrivacySampleClass.authHeaderField,
          expectedCode: AiroAnalyticsPrivacyCode.prohibitedFieldName,
        ),
        AiroAnalyticsPrivacyFilterTestCase(
          caseId: 'raw-search-field',
          field: 'searchQuery',
          value: 'latest live match',
          sampleClass: AiroAnalyticsPrivacySampleClass.rawQueryField,
          expectedCode: AiroAnalyticsPrivacyCode.prohibitedFieldName,
        ),
        AiroAnalyticsPrivacyFilterTestCase(
          caseId: 'raw-title-field',
          field: 'programTitle',
          value: 'Evening News',
          sampleClass: AiroAnalyticsPrivacySampleClass.rawTitleField,
          expectedCode: AiroAnalyticsPrivacyCode.prohibitedFieldName,
        ),
        AiroAnalyticsPrivacyFilterTestCase(
          caseId: 'raw-channel-field',
          field: 'channelName',
          value: 'City News Live',
          sampleClass: AiroAnalyticsPrivacySampleClass.rawTitleField,
          expectedCode: AiroAnalyticsPrivacyCode.prohibitedFieldName,
        ),
        AiroAnalyticsPrivacyFilterTestCase(
          caseId: 'raw-source-field',
          field: 'playlistUrl',
          value: 'redacted',
          sampleClass: AiroAnalyticsPrivacySampleClass.rawSourceField,
          expectedCode: AiroAnalyticsPrivacyCode.prohibitedFieldName,
        ),
      ],
    );
  }
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

bool _matchesFieldKind(AiroAnalyticsFieldKind kind, Object? value) {
  return switch (kind) {
    AiroAnalyticsFieldKind.stableIdentifier =>
      value is String && _isSnakeCase(value),
    AiroAnalyticsFieldKind.category => value is String && _isSnakeCase(value),
    AiroAnalyticsFieldKind.bucket => value is String && _isBucketValue(value),
    AiroAnalyticsFieldKind.count => value is int && value >= 0,
    AiroAnalyticsFieldKind.decimal => value is num && value.isFinite,
    AiroAnalyticsFieldKind.boolean => value is bool,
  };
}

bool _isSnakeCase(String value) {
  return RegExp(r'^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$').hasMatch(value);
}

bool _isBucketValue(String value) {
  return RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$').hasMatch(value);
}

Map<String, Object?> _consentToPublicMap(AiroAnalyticsConsentState consent) {
  return {
    'operational': consent.operational,
    'product': consent.product,
    'playbackQuality': consent.playbackQuality,
    'diagnostics': consent.diagnostics,
    'crash': consent.crash,
    'personalized': consent.personalized,
    'localOnly': consent.localOnly,
  };
}
