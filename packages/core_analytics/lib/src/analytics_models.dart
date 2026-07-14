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

enum AiroAnalyticsGatewayRegion {
  us('us'),
  eu('eu'),
  india('india'),
  localOnly('local_only');

  const AiroAnalyticsGatewayRegion(this.stableId);

  final String stableId;
}

enum AiroAnalyticsGatewayDecisionCode {
  accepted('accepted'),
  collectionDisabled('collection_disabled'),
  localOnlyUploadBlocked('local_only_upload_blocked'),
  schemaRejected('schema_rejected'),
  privacyRejected('privacy_rejected'),
  regionNotAllowed('region_not_allowed'),
  rateLimited('rate_limited'),
  retentionUnsupported('retention_unsupported'),
  deletionUnsupported('deletion_unsupported'),
  providerKindInvalid('provider_kind_invalid');

  const AiroAnalyticsGatewayDecisionCode(this.stableId);

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

enum AiroAnalyticsEventFamily {
  operationalCore('operational_core', AiroAnalyticsPurpose.operational),
  deviceEcosystem('device_ecosystem', AiroAnalyticsPurpose.operational),
  delegation('delegation', AiroAnalyticsPurpose.operational),
  playbackQuality('playback_quality', AiroAnalyticsPurpose.playbackQuality),
  diagnostics('diagnostics', AiroAnalyticsPurpose.diagnostics),
  crashReporting('crash_reporting', AiroAnalyticsPurpose.crash),
  productGrowth('product_growth', AiroAnalyticsPurpose.product),
  personalization('personalization', AiroAnalyticsPurpose.personalized);

  const AiroAnalyticsEventFamily(this.stableId, this.purpose);

  final String stableId;
  final AiroAnalyticsPurpose purpose;
}

enum AiroAnalyticsProfileValidationCode {
  accepted('accepted'),
  allowedPurposeMissing('allowed_purpose_missing'),
  unsupportedPurposeAllowed('unsupported_purpose_allowed'),
  eventFamilyPurposeNotAllowed('event_family_purpose_not_allowed'),
  queueBudgetInvalid('queue_budget_invalid'),
  crashBudgetInvalid('crash_budget_invalid'),
  localRetentionInvalid('local_retention_invalid'),
  externalUploadInLocalOnly('external_upload_in_local_only'),
  providerUploadWithoutProvider('provider_upload_without_provider');

  const AiroAnalyticsProfileValidationCode(this.stableId);

  final String stableId;
}

enum AiroAnalyticsTrackStatus {
  accepted('accepted'),
  droppedByConsent('dropped_by_consent'),
  droppedByLocalOnly('dropped_by_local_only'),
  droppedByCollectionDisabled('dropped_by_collection_disabled'),
  droppedQueueFull('dropped_queue_full'),
  deferredByPlayback('deferred_by_playback'),
  rejectedPrivacy('rejected_privacy'),
  rejectedSchema('rejected_schema'),
  providerBackoffActive('provider_backoff_active'),
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

enum AiroAnalyticsQueueOfferCode {
  accepted('accepted'),
  evictedLowerPriority('evicted_lower_priority'),
  queueFull('queue_full');

  const AiroAnalyticsQueueOfferCode(this.stableId);

  final String stableId;
}

enum AiroAnalyticsUploadDecisionCode {
  eligible('eligible'),
  deferredDuringPlayback('deferred_during_playback'),
  providerBackoffActive('provider_backoff_active');

  const AiroAnalyticsUploadDecisionCode(this.stableId);

  final String stableId;
}

enum AiroCrashSeverity {
  nonFatal('non_fatal'),
  fatal('fatal'),
  nativeFatal('native_fatal');

  const AiroCrashSeverity(this.stableId);

  final String stableId;
}

enum AiroCrashKind {
  appException('app_exception'),
  nativeSignal('native_signal'),
  outOfMemory('out_of_memory'),
  playbackEngine('playback_engine'),
  platformChannel('platform_channel');

  const AiroCrashKind(this.stableId);

  final String stableId;
}

enum AiroCrashRedactionCode {
  none('none'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value'),
  prohibitedFieldName('prohibited_field_name'),
  stackFrameRedacted('stack_frame_redacted'),
  nativeSymbolRedacted('native_symbol_redacted');

  const AiroCrashRedactionCode(this.stableId);

  final String stableId;
}

enum AiroCrashReportStatus {
  accepted('accepted'),
  storedLocalOnly('stored_local_only'),
  uploadBlockedLocalOnly('upload_blocked_local_only'),
  droppedByConsent('dropped_by_consent'),
  droppedByCollectionDisabled('dropped_by_collection_disabled'),
  providerUnavailable('provider_unavailable');

  const AiroCrashReportStatus(this.stableId);

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

enum AiroAnalyticsRetentionPolicyCode {
  accepted('accepted'),
  retentionDaysMismatch('retention_days_mismatch'),
  aggregateHasRawRetention('aggregate_has_raw_retention'),
  retentionClassMissing('retention_class_missing'),
  accessRoleMissing('access_role_missing'),
  accessPurposeMissing('access_purpose_missing');

  const AiroAnalyticsRetentionPolicyCode(this.stableId);

  final String stableId;
}

enum AiroAnalyticsDeletionReason {
  consentWithdrawal('consent_withdrawal'),
  privacyRequest('privacy_request'),
  accountDeletion('account_deletion'),
  retentionExpiry('retention_expiry');

  const AiroAnalyticsDeletionReason(this.stableId);

  final String stableId;
}

enum AiroAnalyticsDeletionStep {
  clearLocalQueue('clear_local_queue'),
  clearLocalCrashDiagnostics('clear_local_crash_diagnostics'),
  resetAnalyticsIdentity('reset_analytics_identity'),
  requestProviderExport('request_provider_export'),
  requestProviderDelete('request_provider_delete'),
  writeAggregateTombstone('write_aggregate_tombstone'),
  writeAuditRecord('write_audit_record');

  const AiroAnalyticsDeletionStep(this.stableId);

  final String stableId;
}

enum AiroAnalyticsAccessRole {
  support('support'),
  productAnalyst('product_analyst'),
  privacyOfficer('privacy_officer'),
  securityAuditor('security_auditor'),
  releaseEngineer('release_engineer');

  const AiroAnalyticsAccessRole(this.stableId);

  final String stableId;
}

enum AiroAnalyticsAccessPurpose {
  supportTroubleshooting('support_troubleshooting'),
  productMeasurement('product_measurement'),
  privacyRequest('privacy_request'),
  securityInvestigation('security_investigation'),
  releaseQuality('release_quality');

  const AiroAnalyticsAccessPurpose(this.stableId);

  final String stableId;
}

enum AiroAnalyticsAccessDecisionCode {
  accepted('accepted'),
  roleNotAllowed('role_not_allowed'),
  purposeNotAllowed('purpose_not_allowed'),
  approvalRequired('approval_required'),
  productionAccessBlocked('production_access_blocked');

  const AiroAnalyticsAccessDecisionCode(this.stableId);

  final String stableId;
}

enum AiroAnalyticsDashboardRequirement {
  none('none'),
  optional('optional'),
  required('required');

  const AiroAnalyticsDashboardRequirement(this.stableId);

  final String stableId;
}

enum AiroAnalyticsDashboardSurface {
  executive('executive'),
  playbackQuality('playback_quality'),
  legacyDevice('legacy_device'),
  deviceEcosystem('device_ecosystem'),
  subscription('subscription'),
  regression('regression');

  const AiroAnalyticsDashboardSurface(this.stableId);

  final String stableId;
}

enum AiroAnalyticsAlertSeverity {
  info('info'),
  warning('warning'),
  critical('critical');

  const AiroAnalyticsAlertSeverity(this.stableId);

  final String stableId;
}

enum AiroAnalyticsAlertComparison {
  greaterThan('greater_than'),
  lessThan('less_than');

  const AiroAnalyticsAlertComparison(this.stableId);

  final String stableId;
}

enum AiroAnalyticsDashboardCatalogCode {
  accepted('accepted'),
  duplicateMetric('duplicate_metric'),
  metricIdInvalid('metric_id_invalid'),
  metricOwnerMissing('metric_owner_missing'),
  requiredSurfaceMissing('required_surface_missing'),
  alertMetricMissing('alert_metric_missing'),
  alertThresholdInvalid('alert_threshold_invalid'),
  alertWindowInvalid('alert_window_invalid'),
  alertRunbookMissing('alert_runbook_missing');

  const AiroAnalyticsDashboardCatalogCode(this.stableId);

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

class AiroAnalyticsSchemaFixtureCase extends Equatable {
  AiroAnalyticsSchemaFixtureCase({
    required this.caseId,
    required this.event,
    required Iterable<AiroAnalyticsSchemaValidationCode> expectedCodes,
  }) : expectedCodes = List.unmodifiable(expectedCodes);

  final String caseId;
  final AiroAnalyticsEvent event;
  final List<AiroAnalyticsSchemaValidationCode> expectedCodes;

  bool get shouldPass =>
      expectedCodes.length == 1 &&
      expectedCodes.single == AiroAnalyticsSchemaValidationCode.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'caseId': caseId,
      'eventName': event.name,
      'owner': event.owner,
      'purpose': event.purpose.stableId,
      'fieldNames': event.params.keys.toList(growable: false)..sort(),
      'expectedCodes': expectedCodes
          .map((code) => code.stableId)
          .toList(growable: false),
      'shouldPass': shouldPass,
    };
  }

  @override
  List<Object?> get props => [caseId, event, expectedCodes];
}

class AiroAnalyticsSchemaFixtureSuite extends Equatable {
  AiroAnalyticsSchemaFixtureSuite({
    required this.suiteId,
    required Iterable<AiroAnalyticsSchemaFixtureCase> cases,
    this.schemaVersion = kAiroAnalyticsSchemaVersion,
  }) : cases = List.unmodifiable(cases);

  final String schemaVersion;
  final String suiteId;
  final List<AiroAnalyticsSchemaFixtureCase> cases;

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

class AiroAnalyticsProfileValidationResult extends Equatable {
  AiroAnalyticsProfileValidationResult({
    required List<AiroAnalyticsProfileValidationCode> codes,
  }) : codes = List.unmodifiable(codes);

  final List<AiroAnalyticsProfileValidationCode> codes;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == AiroAnalyticsProfileValidationCode.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [codes];
}

class AiroAnalyticsRetentionPolicyResult extends Equatable {
  AiroAnalyticsRetentionPolicyResult({
    required List<AiroAnalyticsRetentionPolicyCode> codes,
  }) : codes = List.unmodifiable(codes);

  final List<AiroAnalyticsRetentionPolicyCode> codes;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == AiroAnalyticsRetentionPolicyCode.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [codes];
}

class AiroAnalyticsRetentionRule extends Equatable {
  AiroAnalyticsRetentionRule({
    required this.retentionClass,
    required this.rawRetentionDays,
    required this.deleteOnConsentWithdrawal,
    required this.exportable,
    required Iterable<AiroAnalyticsAccessRole> allowedRoles,
    required Iterable<AiroAnalyticsAccessPurpose> allowedPurposes,
  }) : allowedRoles = Set.unmodifiable(allowedRoles),
       allowedPurposes = Set.unmodifiable(allowedPurposes);

  final AiroAnalyticsRetentionClass retentionClass;
  final int rawRetentionDays;
  final bool deleteOnConsentWithdrawal;
  final bool exportable;
  final Set<AiroAnalyticsAccessRole> allowedRoles;
  final Set<AiroAnalyticsAccessPurpose> allowedPurposes;

  Map<String, Object?> toPublicMap() {
    return {
      'retentionClass': retentionClass.stableId,
      'rawRetentionDays': rawRetentionDays,
      'deleteOnConsentWithdrawal': deleteOnConsentWithdrawal,
      'exportable': exportable,
      'allowedRoles':
          allowedRoles.map((role) => role.stableId).toList(growable: false)
            ..sort(),
      'allowedPurposes':
          allowedPurposes
              .map((purpose) => purpose.stableId)
              .toList(growable: false)
            ..sort(),
    };
  }

  @override
  List<Object?> get props => [
    retentionClass,
    rawRetentionDays,
    deleteOnConsentWithdrawal,
    exportable,
    allowedRoles,
    allowedPurposes,
  ];
}

class AiroAnalyticsDeletionPlan extends Equatable {
  AiroAnalyticsDeletionPlan({
    required this.reason,
    required Iterable<AiroAnalyticsRetentionClass> retentionClasses,
    required Iterable<AiroAnalyticsDeletionStep> steps,
    required Iterable<AiroAnalyticsPurpose> affectedPurposes,
  }) : retentionClasses = List.unmodifiable(retentionClasses),
       steps = List.unmodifiable(steps),
       affectedPurposes = List.unmodifiable(affectedPurposes);

  final AiroAnalyticsDeletionReason reason;
  final List<AiroAnalyticsRetentionClass> retentionClasses;
  final List<AiroAnalyticsDeletionStep> steps;
  final List<AiroAnalyticsPurpose> affectedPurposes;

  Map<String, Object?> toPublicMap() {
    return {
      'reason': reason.stableId,
      'retentionClasses': retentionClasses
          .map((retentionClass) => retentionClass.stableId)
          .toList(growable: false),
      'steps': steps.map((step) => step.stableId).toList(growable: false),
      'affectedPurposes': affectedPurposes
          .map((purpose) => purpose.stableId)
          .toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [
    reason,
    retentionClasses,
    steps,
    affectedPurposes,
  ];
}

class AiroAnalyticsAccessRequest extends Equatable {
  const AiroAnalyticsAccessRequest({
    required this.role,
    required this.purpose,
    required this.retentionClass,
    this.productionData = false,
    this.approved = false,
  });

  final AiroAnalyticsAccessRole role;
  final AiroAnalyticsAccessPurpose purpose;
  final AiroAnalyticsRetentionClass retentionClass;
  final bool productionData;
  final bool approved;

  Map<String, Object?> toPublicMap() {
    return {
      'role': role.stableId,
      'purpose': purpose.stableId,
      'retentionClass': retentionClass.stableId,
      'productionData': productionData,
      'approved': approved,
    };
  }

  @override
  List<Object?> get props => [
    role,
    purpose,
    retentionClass,
    productionData,
    approved,
  ];
}

class AiroAnalyticsAccessDecision extends Equatable {
  AiroAnalyticsAccessDecision({
    required this.request,
    required List<AiroAnalyticsAccessDecisionCode> codes,
  }) : codes = List.unmodifiable(codes);

  final AiroAnalyticsAccessRequest request;
  final List<AiroAnalyticsAccessDecisionCode> codes;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == AiroAnalyticsAccessDecisionCode.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'request': request.toPublicMap(),
      'codes': codes.map((code) => code.stableId).toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [request, codes];
}

class AiroAnalyticsRetentionPolicy extends Equatable {
  AiroAnalyticsRetentionPolicy({
    required Iterable<AiroAnalyticsRetentionRule> rules,
    this.schemaVersion = kAiroAnalyticsSchemaVersion,
  }) : rules = List.unmodifiable(rules);

  final String schemaVersion;
  final List<AiroAnalyticsRetentionRule> rules;

  AiroAnalyticsRetentionRule? ruleFor(
    AiroAnalyticsRetentionClass retentionClass,
  ) {
    for (final rule in rules) {
      if (rule.retentionClass == retentionClass) return rule;
    }
    return null;
  }

  AiroAnalyticsRetentionPolicyResult validate() {
    final codes = <AiroAnalyticsRetentionPolicyCode>[];
    for (final retentionClass in AiroAnalyticsRetentionClass.values) {
      final rule = ruleFor(retentionClass);
      if (rule == null) {
        codes.add(AiroAnalyticsRetentionPolicyCode.retentionClassMissing);
        continue;
      }
      if (retentionClass == AiroAnalyticsRetentionClass.aggregateOnly) {
        if (rule.rawRetentionDays != 0) {
          codes.add(AiroAnalyticsRetentionPolicyCode.aggregateHasRawRetention);
        }
      } else if (rule.rawRetentionDays != retentionClass.days) {
        codes.add(AiroAnalyticsRetentionPolicyCode.retentionDaysMismatch);
      }
      if (rule.allowedRoles.isEmpty) {
        codes.add(AiroAnalyticsRetentionPolicyCode.accessRoleMissing);
      }
      if (rule.allowedPurposes.isEmpty) {
        codes.add(AiroAnalyticsRetentionPolicyCode.accessPurposeMissing);
      }
    }
    return AiroAnalyticsRetentionPolicyResult(
      codes: codes.isEmpty
          ? const [AiroAnalyticsRetentionPolicyCode.accepted]
          : codes.toSet().toList(growable: false),
    );
  }

  AiroAnalyticsDeletionPlan deletionPlan(AiroAnalyticsDeletionReason reason) {
    return switch (reason) {
      AiroAnalyticsDeletionReason.consentWithdrawal =>
        AiroAnalyticsDeletionPlan(
          reason: reason,
          retentionClasses: const [
            AiroAnalyticsRetentionClass.product90Days,
            AiroAnalyticsRetentionClass.diagnostics30Days,
            AiroAnalyticsRetentionClass.crash90Days,
          ],
          steps: const [
            AiroAnalyticsDeletionStep.clearLocalQueue,
            AiroAnalyticsDeletionStep.clearLocalCrashDiagnostics,
            AiroAnalyticsDeletionStep.resetAnalyticsIdentity,
            AiroAnalyticsDeletionStep.requestProviderDelete,
            AiroAnalyticsDeletionStep.writeAuditRecord,
          ],
          affectedPurposes: const [
            AiroAnalyticsPurpose.product,
            AiroAnalyticsPurpose.playbackQuality,
            AiroAnalyticsPurpose.diagnostics,
            AiroAnalyticsPurpose.crash,
            AiroAnalyticsPurpose.personalized,
          ],
        ),
      AiroAnalyticsDeletionReason.privacyRequest ||
      AiroAnalyticsDeletionReason.accountDeletion => AiroAnalyticsDeletionPlan(
        reason: reason,
        retentionClasses: const [
          AiroAnalyticsRetentionClass.operational30Days,
          AiroAnalyticsRetentionClass.product90Days,
          AiroAnalyticsRetentionClass.diagnostics30Days,
          AiroAnalyticsRetentionClass.crash90Days,
          AiroAnalyticsRetentionClass.aggregateOnly,
        ],
        steps: const [
          AiroAnalyticsDeletionStep.clearLocalQueue,
          AiroAnalyticsDeletionStep.clearLocalCrashDiagnostics,
          AiroAnalyticsDeletionStep.resetAnalyticsIdentity,
          AiroAnalyticsDeletionStep.requestProviderExport,
          AiroAnalyticsDeletionStep.requestProviderDelete,
          AiroAnalyticsDeletionStep.writeAggregateTombstone,
          AiroAnalyticsDeletionStep.writeAuditRecord,
        ],
        affectedPurposes: AiroAnalyticsPurpose.values,
      ),
      AiroAnalyticsDeletionReason.retentionExpiry => AiroAnalyticsDeletionPlan(
        reason: reason,
        retentionClasses: const [
          AiroAnalyticsRetentionClass.operational30Days,
          AiroAnalyticsRetentionClass.product90Days,
          AiroAnalyticsRetentionClass.diagnostics30Days,
          AiroAnalyticsRetentionClass.crash90Days,
        ],
        steps: const [
          AiroAnalyticsDeletionStep.clearLocalQueue,
          AiroAnalyticsDeletionStep.clearLocalCrashDiagnostics,
          AiroAnalyticsDeletionStep.requestProviderDelete,
          AiroAnalyticsDeletionStep.writeAuditRecord,
        ],
        affectedPurposes: AiroAnalyticsPurpose.values,
      ),
    };
  }

  AiroAnalyticsAccessDecision evaluateAccess(
    AiroAnalyticsAccessRequest request,
  ) {
    final rule = ruleFor(request.retentionClass);
    if (rule == null) {
      return AiroAnalyticsAccessDecision(
        request: request,
        codes: const [AiroAnalyticsAccessDecisionCode.roleNotAllowed],
      );
    }
    final codes = <AiroAnalyticsAccessDecisionCode>[];
    if (!rule.allowedRoles.contains(request.role)) {
      codes.add(AiroAnalyticsAccessDecisionCode.roleNotAllowed);
    }
    if (!rule.allowedPurposes.contains(request.purpose)) {
      codes.add(AiroAnalyticsAccessDecisionCode.purposeNotAllowed);
    }
    if (request.productionData && !request.approved) {
      codes.add(AiroAnalyticsAccessDecisionCode.approvalRequired);
    }
    if (request.productionData &&
        request.role == AiroAnalyticsAccessRole.support) {
      codes.add(AiroAnalyticsAccessDecisionCode.productionAccessBlocked);
    }
    return AiroAnalyticsAccessDecision(
      request: request,
      codes: codes.isEmpty
          ? const [AiroAnalyticsAccessDecisionCode.accepted]
          : codes.toSet().toList(growable: false),
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'rules': rules.map((rule) => rule.toPublicMap()).toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [schemaVersion, rules];
}

class AiroAnalyticsDashboardCatalogResult extends Equatable {
  AiroAnalyticsDashboardCatalogResult({
    required List<AiroAnalyticsDashboardCatalogCode> codes,
  }) : codes = List.unmodifiable(codes);

  final List<AiroAnalyticsDashboardCatalogCode> codes;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == AiroAnalyticsDashboardCatalogCode.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [codes];
}

class AiroAnalyticsDashboardMetricSpec extends Equatable {
  const AiroAnalyticsDashboardMetricSpec({
    required this.metricId,
    required this.owner,
    required this.purpose,
    required this.retentionClass,
    required this.surface,
    required this.dashboardRequirement,
    this.aggregateOnly = true,
    this.alertable = false,
  });

  final String metricId;
  final String owner;
  final AiroAnalyticsPurpose purpose;
  final AiroAnalyticsRetentionClass retentionClass;
  final AiroAnalyticsDashboardSurface surface;
  final AiroAnalyticsDashboardRequirement dashboardRequirement;
  final bool aggregateOnly;
  final bool alertable;

  Map<String, Object?> toPublicMap() {
    return {
      'metricId': metricId,
      'owner': owner,
      'purpose': purpose.stableId,
      'retentionClass': retentionClass.stableId,
      'surface': surface.stableId,
      'dashboardRequirement': dashboardRequirement.stableId,
      'aggregateOnly': aggregateOnly,
      'alertable': alertable,
    };
  }

  @override
  List<Object?> get props => [
    metricId,
    owner,
    purpose,
    retentionClass,
    surface,
    dashboardRequirement,
    aggregateOnly,
    alertable,
  ];
}

class AiroAnalyticsOperationalAlertRule extends Equatable {
  const AiroAnalyticsOperationalAlertRule({
    required this.alertId,
    required this.metricId,
    required this.severity,
    required this.comparison,
    required this.threshold,
    required this.evaluationWindowMinutes,
    required this.runbookId,
  });

  final String alertId;
  final String metricId;
  final AiroAnalyticsAlertSeverity severity;
  final AiroAnalyticsAlertComparison comparison;
  final double threshold;
  final int evaluationWindowMinutes;
  final String runbookId;

  Map<String, Object?> toPublicMap() {
    return {
      'alertId': alertId,
      'metricId': metricId,
      'severity': severity.stableId,
      'comparison': comparison.stableId,
      'threshold': threshold,
      'evaluationWindowMinutes': evaluationWindowMinutes,
      'runbookId': runbookId,
    };
  }

  @override
  List<Object?> get props => [
    alertId,
    metricId,
    severity,
    comparison,
    threshold,
    evaluationWindowMinutes,
    runbookId,
  ];
}

class AiroAnalyticsDashboardCatalog extends Equatable {
  AiroAnalyticsDashboardCatalog({
    required Iterable<AiroAnalyticsDashboardMetricSpec> metrics,
    required Iterable<AiroAnalyticsOperationalAlertRule> alerts,
    this.schemaVersion = kAiroAnalyticsSchemaVersion,
  }) : metrics = List.unmodifiable(metrics),
       alerts = List.unmodifiable(alerts);

  final String schemaVersion;
  final List<AiroAnalyticsDashboardMetricSpec> metrics;
  final List<AiroAnalyticsOperationalAlertRule> alerts;

  AiroAnalyticsDashboardCatalogResult validate() {
    final codes = <AiroAnalyticsDashboardCatalogCode>[];
    final metricIds = <String>{};
    final surfaces = <AiroAnalyticsDashboardSurface>{};
    for (final metric in metrics) {
      if (!metricIds.add(metric.metricId)) {
        codes.add(AiroAnalyticsDashboardCatalogCode.duplicateMetric);
      }
      if (!_isSnakeCase(metric.metricId)) {
        codes.add(AiroAnalyticsDashboardCatalogCode.metricIdInvalid);
      }
      if (metric.owner.trim().isEmpty) {
        codes.add(AiroAnalyticsDashboardCatalogCode.metricOwnerMissing);
      }
      if (metric.dashboardRequirement ==
          AiroAnalyticsDashboardRequirement.required) {
        surfaces.add(metric.surface);
      }
    }
    for (final surface in AiroAnalyticsDashboardSurface.values) {
      if (!surfaces.contains(surface)) {
        codes.add(AiroAnalyticsDashboardCatalogCode.requiredSurfaceMissing);
      }
    }
    for (final alert in alerts) {
      if (!metricIds.contains(alert.metricId)) {
        codes.add(AiroAnalyticsDashboardCatalogCode.alertMetricMissing);
      }
      if (!alert.threshold.isFinite || alert.threshold < 0) {
        codes.add(AiroAnalyticsDashboardCatalogCode.alertThresholdInvalid);
      }
      if (alert.evaluationWindowMinutes <= 0) {
        codes.add(AiroAnalyticsDashboardCatalogCode.alertWindowInvalid);
      }
      if (alert.runbookId.trim().isEmpty) {
        codes.add(AiroAnalyticsDashboardCatalogCode.alertRunbookMissing);
      }
    }
    return AiroAnalyticsDashboardCatalogResult(
      codes: codes.isEmpty
          ? const [AiroAnalyticsDashboardCatalogCode.accepted]
          : codes.toSet().toList(growable: false),
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'metrics': metrics
          .map((metric) => metric.toPublicMap())
          .toList(growable: false),
      'alerts': alerts
          .map((alert) => alert.toPublicMap())
          .toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [schemaVersion, metrics, alerts];
}

class AiroAnalyticsGatewayRateLimitState extends Equatable {
  const AiroAnalyticsGatewayRateLimitState({
    required this.windowStartedAt,
    required this.eventCount,
  });

  final DateTime windowStartedAt;
  final int eventCount;

  Map<String, Object?> toPublicMap() {
    return {
      'windowStartedAt': windowStartedAt.toIso8601String(),
      'eventCount': eventCount,
    };
  }

  @override
  List<Object?> get props => [windowStartedAt, eventCount];
}

class AiroAnalyticsGatewayDecision extends Equatable {
  AiroAnalyticsGatewayDecision({
    required List<AiroAnalyticsGatewayDecisionCode> codes,
    required this.gatewayId,
    required this.region,
    required this.eventName,
    required this.owner,
    required this.purpose,
    required this.retentionClass,
    required this.rateLimitState,
    List<AiroAnalyticsSchemaValidationCode> schemaCodes = const [],
  }) : codes = List.unmodifiable(codes),
       schemaCodes = List.unmodifiable(schemaCodes);

  final List<AiroAnalyticsGatewayDecisionCode> codes;
  final String gatewayId;
  final AiroAnalyticsGatewayRegion region;
  final String eventName;
  final String owner;
  final AiroAnalyticsPurpose purpose;
  final AiroAnalyticsRetentionClass? retentionClass;
  final AiroAnalyticsGatewayRateLimitState rateLimitState;
  final List<AiroAnalyticsSchemaValidationCode> schemaCodes;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == AiroAnalyticsGatewayDecisionCode.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'gatewayId': gatewayId,
      'region': region.stableId,
      'eventName': eventName,
      'owner': owner,
      'purpose': purpose.stableId,
      'retentionClass': retentionClass?.stableId,
      'rateLimitState': rateLimitState.toPublicMap(),
      'codes': codes.map((code) => code.stableId).toList(growable: false),
      'schemaCodes': schemaCodes
          .map((code) => code.stableId)
          .toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [
    codes,
    gatewayId,
    region,
    eventName,
    owner,
    purpose,
    retentionClass,
    rateLimitState,
    schemaCodes,
  ];
}

class AiroAnalyticsSelfHostedGatewayPolicy extends Equatable {
  AiroAnalyticsSelfHostedGatewayPolicy({
    required this.gatewayId,
    required this.schemaRegistry,
    required this.retentionPolicy,
    Set<AiroAnalyticsGatewayRegion> allowedRegions = const {
      AiroAnalyticsGatewayRegion.us,
      AiroAnalyticsGatewayRegion.eu,
      AiroAnalyticsGatewayRegion.india,
    },
    this.providerKind = AiroAnalyticsProviderKind.selfHosted,
    this.maxEventsPerMinute = 120,
    this.supportsRetentionPolicy = true,
    this.supportsDeletionRequests = true,
    this.schemaVersion = kAiroAnalyticsSchemaVersion,
  }) : allowedRegions = Set.unmodifiable(allowedRegions);

  final String schemaVersion;
  final String gatewayId;
  final AiroAnalyticsProviderKind providerKind;
  final AiroAnalyticsSchemaRegistry schemaRegistry;
  final AiroAnalyticsRetentionPolicy retentionPolicy;
  final Set<AiroAnalyticsGatewayRegion> allowedRegions;
  final int maxEventsPerMinute;
  final bool supportsRetentionPolicy;
  final bool supportsDeletionRequests;

  AiroAnalyticsGatewayDecision evaluate({
    required AiroAnalyticsEvent event,
    required AiroAnalyticsConsentState consent,
    required bool collectionEnabled,
    required AiroAnalyticsGatewayRegion region,
    required AiroAnalyticsGatewayRateLimitState rateLimitState,
  }) {
    final codes = <AiroAnalyticsGatewayDecisionCode>[];
    final schemaResult = schemaRegistry.validateEvent(event);
    final schema = schemaRegistry.schemaFor(event.name);

    if (providerKind != AiroAnalyticsProviderKind.selfHosted) {
      codes.add(AiroAnalyticsGatewayDecisionCode.providerKindInvalid);
    }
    if (!collectionEnabled) {
      codes.add(AiroAnalyticsGatewayDecisionCode.collectionDisabled);
    }
    if (consent.localOnly) {
      codes.add(AiroAnalyticsGatewayDecisionCode.localOnlyUploadBlocked);
    }
    if (!allowedRegions.contains(region)) {
      codes.add(AiroAnalyticsGatewayDecisionCode.regionNotAllowed);
    }
    if (maxEventsPerMinute <= 0 ||
        rateLimitState.eventCount >= maxEventsPerMinute) {
      codes.add(AiroAnalyticsGatewayDecisionCode.rateLimited);
    }
    if (!schemaResult.accepted) {
      codes.add(AiroAnalyticsGatewayDecisionCode.schemaRejected);
      if (schemaResult.privacyViolations.isNotEmpty) {
        codes.add(AiroAnalyticsGatewayDecisionCode.privacyRejected);
      }
    }
    if (!supportsRetentionPolicy ||
        schema == null ||
        retentionPolicy.ruleFor(schema.retentionClass) == null) {
      codes.add(AiroAnalyticsGatewayDecisionCode.retentionUnsupported);
    }
    if (!supportsDeletionRequests) {
      codes.add(AiroAnalyticsGatewayDecisionCode.deletionUnsupported);
    }

    return AiroAnalyticsGatewayDecision(
      gatewayId: gatewayId,
      region: region,
      eventName: event.name,
      owner: event.owner,
      purpose: event.purpose,
      retentionClass: schema?.retentionClass,
      rateLimitState: rateLimitState,
      codes: codes.isEmpty
          ? const [AiroAnalyticsGatewayDecisionCode.accepted]
          : codes.toSet().toList(growable: false),
      schemaCodes: schemaResult.codes,
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'gatewayId': gatewayId,
      'providerKind': providerKind.stableId,
      'allowedRegions':
          allowedRegions
              .map((region) => region.stableId)
              .toList(growable: false)
            ..sort(),
      'maxEventsPerMinute': maxEventsPerMinute,
      'supportsRetentionPolicy': supportsRetentionPolicy,
      'supportsDeletionRequests': supportsDeletionRequests,
      'registeredSchemaCount': schemaRegistry.schemas.length,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    gatewayId,
    providerKind,
    schemaRegistry,
    retentionPolicy,
    allowedRegions,
    maxEventsPerMinute,
    supportsRetentionPolicy,
    supportsDeletionRequests,
  ];
}

class AiroAnalyticsProductEditionProfile extends Equatable {
  AiroAnalyticsProductEditionProfile({
    required this.productProfile,
    required this.displayName,
    required Iterable<AiroAnalyticsPurpose> allowedPurposes,
    required Iterable<AiroAnalyticsEventFamily> eventFamilies,
    required Iterable<String> eventNames,
    required this.providerKind,
    required this.maxQueueEvents,
    required this.maxCrashReports,
    required this.localRetentionDays,
    this.externalUploadAllowed = false,
    this.localOnly = false,
    this.schemaVersion = kAiroAnalyticsSchemaVersion,
  }) : allowedPurposes = Set.unmodifiable(allowedPurposes),
       eventFamilies = Set.unmodifiable(eventFamilies),
       eventNames = Set.unmodifiable(eventNames);

  final String schemaVersion;
  final AiroAnalyticsProductProfile productProfile;
  final String displayName;
  final Set<AiroAnalyticsPurpose> allowedPurposes;
  final Set<AiroAnalyticsEventFamily> eventFamilies;
  final Set<String> eventNames;
  final AiroAnalyticsProviderKind providerKind;
  final int maxQueueEvents;
  final int maxCrashReports;
  final int localRetentionDays;
  final bool externalUploadAllowed;
  final bool localOnly;

  bool allowsPurpose(AiroAnalyticsPurpose purpose) {
    return allowedPurposes.contains(purpose);
  }

  bool allowsEventName(String eventName) {
    return eventNames.contains(eventName);
  }

  bool allowsEvent(AiroAnalyticsEvent event) {
    return allowsPurpose(event.purpose) && allowsEventName(event.name);
  }

  AiroAnalyticsConsentState effectiveConsent(
    AiroAnalyticsConsentState requestedConsent,
  ) {
    if (localOnly) {
      return const AiroAnalyticsConsentState.localOnly();
    }
    return AiroAnalyticsConsentState(
      operational:
          requestedConsent.operational &&
          allowedPurposes.contains(AiroAnalyticsPurpose.operational),
      product:
          requestedConsent.product &&
          allowedPurposes.contains(AiroAnalyticsPurpose.product),
      playbackQuality:
          requestedConsent.playbackQuality &&
          allowedPurposes.contains(AiroAnalyticsPurpose.playbackQuality),
      diagnostics:
          requestedConsent.diagnostics &&
          allowedPurposes.contains(AiroAnalyticsPurpose.diagnostics),
      crash:
          requestedConsent.crash &&
          allowedPurposes.contains(AiroAnalyticsPurpose.crash),
      personalized:
          requestedConsent.personalized &&
          allowedPurposes.contains(AiroAnalyticsPurpose.personalized),
      localOnly: requestedConsent.localOnly,
    );
  }

  AiroAnalyticsProductEditionProfile asLocalOnly({
    AiroAnalyticsProviderKind providerKind =
        AiroAnalyticsProviderKind.localDiagnostics,
  }) {
    return AiroAnalyticsProductEditionProfile(
      productProfile: productProfile,
      displayName: '$displayName Local Only',
      allowedPurposes: const {
        AiroAnalyticsPurpose.operational,
        AiroAnalyticsPurpose.diagnostics,
      }.intersection(allowedPurposes),
      eventFamilies: eventFamilies
          .where(
            (family) =>
                family.purpose == AiroAnalyticsPurpose.operational ||
                family.purpose == AiroAnalyticsPurpose.diagnostics,
          )
          .toSet(),
      eventNames: eventNames,
      providerKind: providerKind,
      maxQueueEvents: maxQueueEvents,
      maxCrashReports: maxCrashReports,
      localRetentionDays: localRetentionDays,
      externalUploadAllowed: false,
      localOnly: true,
      schemaVersion: schemaVersion,
    );
  }

  AiroAnalyticsServiceConfiguration toServiceConfiguration({
    AiroAnalyticsConsentState consent =
        const AiroAnalyticsConsentState.disabled(),
    bool collectionEnabled = false,
    bool providerSdkIsolated = true,
    bool nonBlocking = true,
    bool resettableInstallationId = true,
  }) {
    return AiroAnalyticsServiceConfiguration(
      providerKind: providerKind,
      productProfile: productProfile,
      consent: effectiveConsent(consent),
      collectionEnabled: collectionEnabled,
      maxQueueEvents: maxQueueEvents,
      externalUploadAllowed: externalUploadAllowed && !localOnly,
      providerSdkIsolated: providerSdkIsolated,
      nonBlocking: nonBlocking,
      resettableInstallationId: resettableInstallationId,
      schemaVersion: schemaVersion,
    );
  }

  AiroAnalyticsProfileValidationResult validate() {
    final codes = <AiroAnalyticsProfileValidationCode>[];
    if (!allowedPurposes.contains(AiroAnalyticsPurpose.operational)) {
      codes.add(AiroAnalyticsProfileValidationCode.allowedPurposeMissing);
    }
    for (final family in eventFamilies) {
      if (!allowedPurposes.contains(family.purpose)) {
        codes.add(
          AiroAnalyticsProfileValidationCode.eventFamilyPurposeNotAllowed,
        );
      }
    }
    if (localOnly) {
      final unsupported = allowedPurposes.difference(const {
        AiroAnalyticsPurpose.operational,
        AiroAnalyticsPurpose.diagnostics,
      });
      if (unsupported.isNotEmpty) {
        codes.add(AiroAnalyticsProfileValidationCode.unsupportedPurposeAllowed);
      }
      if (externalUploadAllowed) {
        codes.add(AiroAnalyticsProfileValidationCode.externalUploadInLocalOnly);
      }
    }
    if (externalUploadAllowed &&
        providerKind == AiroAnalyticsProviderKind.noOp) {
      codes.add(
        AiroAnalyticsProfileValidationCode.providerUploadWithoutProvider,
      );
    }
    if (maxQueueEvents < 0) {
      codes.add(AiroAnalyticsProfileValidationCode.queueBudgetInvalid);
    }
    if (maxCrashReports < 0) {
      codes.add(AiroAnalyticsProfileValidationCode.crashBudgetInvalid);
    }
    if (localRetentionDays < 0) {
      codes.add(AiroAnalyticsProfileValidationCode.localRetentionInvalid);
    }
    return AiroAnalyticsProfileValidationResult(
      codes: codes.isEmpty
          ? const [AiroAnalyticsProfileValidationCode.accepted]
          : codes.toSet().toList(growable: false),
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'productProfile': productProfile.stableId,
      'displayName': displayName,
      'allowedPurposes':
          allowedPurposes
              .map((purpose) => purpose.stableId)
              .toList(growable: false)
            ..sort(),
      'eventFamilies':
          eventFamilies.map((family) => family.stableId).toList(growable: false)
            ..sort(),
      'eventNames': eventNames.toList(growable: false)..sort(),
      'providerKind': providerKind.stableId,
      'maxQueueEvents': maxQueueEvents,
      'maxCrashReports': maxCrashReports,
      'localRetentionDays': localRetentionDays,
      'externalUploadAllowed': externalUploadAllowed,
      'localOnly': localOnly,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    productProfile,
    displayName,
    allowedPurposes,
    eventFamilies,
    eventNames,
    providerKind,
    maxQueueEvents,
    maxCrashReports,
    localRetentionDays,
    externalUploadAllowed,
    localOnly,
  ];
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

class AiroAnalyticsQueuedEventSummary extends Equatable {
  const AiroAnalyticsQueuedEventSummary({
    required this.name,
    required this.owner,
    required this.purpose,
    required this.priority,
    required this.schemaVersion,
  });

  factory AiroAnalyticsQueuedEventSummary.fromEvent(AiroAnalyticsEvent event) {
    return AiroAnalyticsQueuedEventSummary(
      name: event.name,
      owner: event.owner,
      purpose: event.purpose,
      priority: event.priority,
      schemaVersion: event.schemaVersion,
    );
  }

  final String name;
  final String owner;
  final AiroAnalyticsPurpose purpose;
  final AiroAnalyticsPriority priority;
  final String schemaVersion;

  Map<String, Object?> toPublicMap() {
    return {
      'name': name,
      'owner': owner,
      'purpose': purpose.stableId,
      'priority': priority.stableId,
      'schemaVersion': schemaVersion,
    };
  }

  @override
  List<Object?> get props => [name, owner, purpose, priority, schemaVersion];
}

class AiroAnalyticsQueueSnapshot extends Equatable {
  AiroAnalyticsQueueSnapshot({
    required this.maxEvents,
    required Iterable<AiroAnalyticsEvent> events,
  }) : events = List.unmodifiable(
         events.map(AiroAnalyticsQueuedEventSummary.fromEvent),
       );

  final int maxEvents;
  final List<AiroAnalyticsQueuedEventSummary> events;

  int get eventCount => events.length;

  Map<String, int> get priorityCounts {
    final counts = <String, int>{};
    for (final priority in AiroAnalyticsPriority.values) {
      counts[priority.stableId] = 0;
    }
    for (final event in events) {
      counts[event.priority.stableId] =
          (counts[event.priority.stableId] ?? 0) + 1;
    }
    return Map.unmodifiable(counts);
  }

  Map<String, Object?> toPublicMap() {
    return {
      'maxEvents': maxEvents,
      'eventCount': eventCount,
      'priorityCounts': priorityCounts,
      'events': events
          .map((event) => event.toPublicMap())
          .toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [maxEvents, events];
}

class AiroAnalyticsQueueOfferResult extends Equatable {
  const AiroAnalyticsQueueOfferResult({
    required this.code,
    required this.snapshot,
    this.evictedEvent,
  });

  final AiroAnalyticsQueueOfferCode code;
  final AiroAnalyticsQueueSnapshot snapshot;
  final AiroAnalyticsQueuedEventSummary? evictedEvent;

  bool get accepted => code != AiroAnalyticsQueueOfferCode.queueFull;

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'code': code.stableId,
      'snapshot': snapshot.toPublicMap(),
      'evictedEvent': evictedEvent?.toPublicMap(),
    };
  }

  @override
  List<Object?> get props => [code, snapshot, evictedEvent];
}

class AiroAnalyticsBoundedEventQueue {
  AiroAnalyticsBoundedEventQueue({required this.maxEvents});

  final int maxEvents;
  final List<AiroAnalyticsEvent> _events = [];

  List<AiroAnalyticsEvent> get events => List.unmodifiable(_events);

  AiroAnalyticsQueueSnapshot snapshot() {
    return AiroAnalyticsQueueSnapshot(maxEvents: maxEvents, events: _events);
  }

  AiroAnalyticsQueueOfferResult offer(AiroAnalyticsEvent event) {
    if (maxEvents <= 0) {
      return AiroAnalyticsQueueOfferResult(
        code: AiroAnalyticsQueueOfferCode.queueFull,
        snapshot: snapshot(),
      );
    }
    if (_events.length < maxEvents) {
      _events.add(event);
      return AiroAnalyticsQueueOfferResult(
        code: AiroAnalyticsQueueOfferCode.accepted,
        snapshot: snapshot(),
      );
    }

    final lowerPriorityIndex = _lowestPriorityIndexBelow(event.priority);
    if (lowerPriorityIndex == null) {
      return AiroAnalyticsQueueOfferResult(
        code: AiroAnalyticsQueueOfferCode.queueFull,
        snapshot: snapshot(),
      );
    }

    final evictedEvent = _events[lowerPriorityIndex];
    _events[lowerPriorityIndex] = event;
    return AiroAnalyticsQueueOfferResult(
      code: AiroAnalyticsQueueOfferCode.evictedLowerPriority,
      snapshot: snapshot(),
      evictedEvent: AiroAnalyticsQueuedEventSummary.fromEvent(evictedEvent),
    );
  }

  void removeWhere(bool Function(AiroAnalyticsEvent event) test) {
    _events.removeWhere(test);
  }

  void clear() {
    _events.clear();
  }

  int? _lowestPriorityIndexBelow(AiroAnalyticsPriority priority) {
    int? index;
    var lowestRank = _priorityRank(priority);
    for (var i = 0; i < _events.length; i += 1) {
      final rank = _priorityRank(_events[i].priority);
      if (rank < _priorityRank(priority) && rank < lowestRank) {
        lowestRank = rank;
        index = i;
      }
    }
    return index;
  }
}

class AiroAnalyticsProviderBackoffState extends Equatable {
  const AiroAnalyticsProviderBackoffState({
    required this.failureCount,
    this.nextRetryAt,
  });

  const AiroAnalyticsProviderBackoffState.inactive()
    : failureCount = 0,
      nextRetryAt = null;

  final int failureCount;
  final DateTime? nextRetryAt;

  bool isActiveAt(DateTime now) {
    final retryAt = nextRetryAt;
    return retryAt != null && now.isBefore(retryAt);
  }

  AiroAnalyticsProviderBackoffState recordFailure(
    DateTime now, {
    Duration baseDelay = const Duration(seconds: 30),
    Duration maxDelay = const Duration(minutes: 5),
  }) {
    final nextFailureCount = failureCount + 1;
    final exponent = (nextFailureCount - 1).clamp(0, 4).toInt();
    final multiplier = 1 << exponent;
    final delay = baseDelay * multiplier;
    return AiroAnalyticsProviderBackoffState(
      failureCount: nextFailureCount,
      nextRetryAt: now.add(delay.compareTo(maxDelay) > 0 ? maxDelay : delay),
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'failureCount': failureCount,
      'nextRetryAt': nextRetryAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [failureCount, nextRetryAt];
}

class AiroAnalyticsUploadDecision extends Equatable {
  const AiroAnalyticsUploadDecision({
    required this.code,
    required this.playbackActive,
    required this.providerBackoffState,
  });

  final AiroAnalyticsUploadDecisionCode code;
  final bool playbackActive;
  final AiroAnalyticsProviderBackoffState providerBackoffState;

  bool get eligible => code == AiroAnalyticsUploadDecisionCode.eligible;

  Map<String, Object?> toPublicMap() {
    return {
      'eligible': eligible,
      'code': code.stableId,
      'playbackActive': playbackActive,
      'providerBackoffState': providerBackoffState.toPublicMap(),
    };
  }

  @override
  List<Object?> get props => [code, playbackActive, providerBackoffState];
}

class AiroAnalyticsUploadGate {
  const AiroAnalyticsUploadGate._();

  static AiroAnalyticsUploadDecision evaluate({
    required AiroAnalyticsEvent event,
    required bool playbackActive,
    required AiroAnalyticsProviderBackoffState providerBackoffState,
    required DateTime now,
  }) {
    if (providerBackoffState.isActiveAt(now)) {
      return AiroAnalyticsUploadDecision(
        code: AiroAnalyticsUploadDecisionCode.providerBackoffActive,
        playbackActive: playbackActive,
        providerBackoffState: providerBackoffState,
      );
    }
    if (playbackActive && event.priority != AiroAnalyticsPriority.critical) {
      return AiroAnalyticsUploadDecision(
        code: AiroAnalyticsUploadDecisionCode.deferredDuringPlayback,
        playbackActive: playbackActive,
        providerBackoffState: providerBackoffState,
      );
    }
    return AiroAnalyticsUploadDecision(
      code: AiroAnalyticsUploadDecisionCode.eligible,
      playbackActive: playbackActive,
      providerBackoffState: providerBackoffState,
    );
  }
}

class AiroAnalyticsTrackResult extends Equatable {
  AiroAnalyticsTrackResult({
    required this.status,
    List<AiroAnalyticsPrivacyViolation> violations = const [],
    this.queueResult,
    this.uploadDecision,
  }) : violations = List.unmodifiable(violations);

  final AiroAnalyticsTrackStatus status;
  final List<AiroAnalyticsPrivacyViolation> violations;
  final AiroAnalyticsQueueOfferResult? queueResult;
  final AiroAnalyticsUploadDecision? uploadDecision;

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
      'queueResult': queueResult?.toPublicMap(),
      'uploadDecision': uploadDecision?.toPublicMap(),
    };
  }

  @override
  List<Object?> get props => [status, violations, queueResult, uploadDecision];
}

class AiroCrashReport extends Equatable {
  AiroCrashReport({
    required this.reportId,
    required this.occurredAt,
    required this.severity,
    required this.kind,
    required this.appVersion,
    required this.platform,
    required this.productProfile,
    required this.deviceTier,
    required this.activeModule,
    required this.memoryPressureBucket,
    this.decoderFamily,
    Map<String, Object?> context = const {},
    List<String> stackFrames = const [],
    List<String> nativeSymbols = const [],
    this.schemaVersion = kAiroAnalyticsSchemaVersion,
  }) : context = Map.unmodifiable(context),
       stackFrames = List.unmodifiable(stackFrames),
       nativeSymbols = List.unmodifiable(nativeSymbols);

  final String schemaVersion;
  final String reportId;
  final DateTime occurredAt;
  final AiroCrashSeverity severity;
  final AiroCrashKind kind;
  final String appVersion;
  final String platform;
  final AiroAnalyticsProductProfile productProfile;
  final String deviceTier;
  final String activeModule;
  final String memoryPressureBucket;
  final String? decoderFamily;
  final Map<String, Object?> context;
  final List<String> stackFrames;
  final List<String> nativeSymbols;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'reportId': reportId,
      'occurredAt': occurredAt.toIso8601String(),
      'severity': severity.stableId,
      'kind': kind.stableId,
      'appVersion': appVersion,
      'platform': platform,
      'productProfile': productProfile.stableId,
      'deviceTier': deviceTier,
      'activeModule': activeModule,
      'memoryPressureBucket': memoryPressureBucket,
      'decoderFamily': decoderFamily,
      'contextFieldNames': context.keys.toList(growable: false)..sort(),
      'stackFrameCount': stackFrames.length,
      'nativeSymbolCount': nativeSymbols.length,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    reportId,
    occurredAt,
    severity,
    kind,
    appVersion,
    platform,
    productProfile,
    deviceTier,
    activeModule,
    memoryPressureBucket,
    decoderFamily,
    context,
    stackFrames,
    nativeSymbols,
  ];
}

class AiroCrashRedactionResult extends Equatable {
  AiroCrashRedactionResult({
    required this.report,
    required Iterable<AiroCrashRedactionCode> codes,
    required Iterable<String> redactedContextFields,
    required this.redactedStackFrameCount,
    required this.redactedNativeSymbolCount,
  }) : codes = List.unmodifiable(codes),
       redactedContextFields = List.unmodifiable(redactedContextFields);

  final AiroCrashReport report;
  final List<AiroCrashRedactionCode> codes;
  final List<String> redactedContextFields;
  final int redactedStackFrameCount;
  final int redactedNativeSymbolCount;

  bool get accepted =>
      codes.isEmpty ||
      (codes.length == 1 && codes.single == AiroCrashRedactionCode.none);

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'report': report.toPublicMap(),
      'codes': codes.map((code) => code.stableId).toList(growable: false),
      'redactedContextFields': redactedContextFields,
      'redactedStackFrameCount': redactedStackFrameCount,
      'redactedNativeSymbolCount': redactedNativeSymbolCount,
    };
  }

  @override
  List<Object?> get props => [
    report,
    codes,
    redactedContextFields,
    redactedStackFrameCount,
    redactedNativeSymbolCount,
  ];
}

class AiroCrashReportResult extends Equatable {
  const AiroCrashReportResult({
    required this.status,
    required this.redactionResult,
  });

  final AiroCrashReportStatus status;
  final AiroCrashRedactionResult redactionResult;

  bool get accepted =>
      status == AiroCrashReportStatus.accepted ||
      status == AiroCrashReportStatus.storedLocalOnly;

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'status': status.stableId,
      'redactionResult': redactionResult.toPublicMap(),
    };
  }

  @override
  List<Object?> get props => [status, redactionResult];
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
    'prompt',
    'transcript',
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

class AiroCrashRedactionPolicy {
  const AiroCrashRedactionPolicy({
    this.prohibitedFields = _defaultCrashProhibitedFields,
  });

  static const AiroCrashRedactionPolicy standard = AiroCrashRedactionPolicy();

  static const Set<String> _defaultCrashProhibitedFields = {
    'url',
    'streamUrl',
    'playlistUrl',
    'signedUrl',
    'authorization',
    'authHeader',
    'cookie',
    'header',
    'localPath',
    'path',
    'localIp',
    'ipAddress',
    'providerDomain',
    'mediaTitle',
    'programTitle',
    'channelName',
    'query',
    'searchQuery',
    'prompt',
    'transcript',
    'providerPayload',
  };

  final Set<String> prohibitedFields;

  AiroCrashRedactionResult redact(AiroCrashReport report) {
    final codes = <AiroCrashRedactionCode>{};
    final redactedContextFields = <String>{};
    final sanitizedContext = <String, Object?>{};

    for (final entry in report.context.entries) {
      final field = entry.key;
      final normalized = AiroAnalyticsPrivacyFilter.normalizeFieldName(field);
      final value = entry.value;
      final fieldIsProhibited = prohibitedFields
          .map(AiroAnalyticsPrivacyFilter.normalizeFieldName)
          .contains(normalized);
      final valueCode = value is String
          ? AiroAnalyticsPrivacyFilter._classifyStringValue(value)
          : null;

      if (fieldIsProhibited) {
        codes.add(AiroCrashRedactionCode.prohibitedFieldName);
      }
      if (valueCode != null) {
        codes.add(_crashCodeForPrivacyCode(valueCode));
      }

      if (fieldIsProhibited || valueCode != null) {
        redactedContextFields.add(field);
        sanitizedContext[field] = 'redacted';
      } else {
        sanitizedContext[field] = value;
      }
    }

    final sanitizedStackFrames = [
      for (final _ in report.stackFrames) 'redacted_stack_frame',
    ];
    final sanitizedNativeSymbols = [
      for (final _ in report.nativeSymbols) 'redacted_native_symbol',
    ];
    if (sanitizedStackFrames.isNotEmpty) {
      codes.add(AiroCrashRedactionCode.stackFrameRedacted);
    }
    if (sanitizedNativeSymbols.isNotEmpty) {
      codes.add(AiroCrashRedactionCode.nativeSymbolRedacted);
    }

    return AiroCrashRedactionResult(
      report: AiroCrashReport(
        reportId: report.reportId,
        occurredAt: report.occurredAt,
        severity: report.severity,
        kind: report.kind,
        appVersion: report.appVersion,
        platform: report.platform,
        productProfile: report.productProfile,
        deviceTier: report.deviceTier,
        activeModule: report.activeModule,
        memoryPressureBucket: report.memoryPressureBucket,
        decoderFamily: report.decoderFamily,
        context: sanitizedContext,
        stackFrames: sanitizedStackFrames,
        nativeSymbols: sanitizedNativeSymbols,
        schemaVersion: report.schemaVersion,
      ),
      codes: codes.isEmpty ? const [AiroCrashRedactionCode.none] : codes,
      redactedContextFields: redactedContextFields.toList(growable: false)
        ..sort(),
      redactedStackFrameCount: sanitizedStackFrames.length,
      redactedNativeSymbolCount: sanitizedNativeSymbols.length,
    );
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

typedef AiroCrashProviderSender =
    Future<void> Function(AiroCrashRedactionResult result);

abstract class AiroCrashReportingService {
  Future<AiroCrashReportResult> report(AiroCrashReport report);
}

class AiroNoOpCrashReportingService implements AiroCrashReportingService {
  const AiroNoOpCrashReportingService({
    this.consent = const AiroAnalyticsConsentState.disabled(),
    this.redactionPolicy = AiroCrashRedactionPolicy.standard,
    this.collectionEnabled = true,
  });

  final AiroAnalyticsConsentState consent;
  final AiroCrashRedactionPolicy redactionPolicy;
  final bool collectionEnabled;

  @override
  Future<AiroCrashReportResult> report(AiroCrashReport report) async {
    final redaction = redactionPolicy.redact(report);
    return AiroCrashReportResult(
      status: _crashStatusForConsent(
        consent: consent,
        collectionEnabled: collectionEnabled,
        storesLocalDiagnostics: false,
      ),
      redactionResult: redaction,
    );
  }
}

class AiroLocalDiagnosticsCrashReportingService
    implements AiroCrashReportingService {
  AiroLocalDiagnosticsCrashReportingService({
    AiroAnalyticsConsentState consent =
        const AiroAnalyticsConsentState.localOnly(),
    this.redactionPolicy = AiroCrashRedactionPolicy.standard,
    bool collectionEnabled = true,
    this.maxReports = 50,
  }) : _consent = consent,
       _collectionEnabled = collectionEnabled;

  final AiroCrashRedactionPolicy redactionPolicy;
  final int maxReports;
  final List<AiroCrashRedactionResult> _reports = [];
  AiroAnalyticsConsentState _consent;
  bool _collectionEnabled;

  List<AiroCrashRedactionResult> get reports => List.unmodifiable(_reports);
  AiroAnalyticsConsentState get consent => _consent;
  bool get collectionEnabled => _collectionEnabled;

  @override
  Future<AiroCrashReportResult> report(AiroCrashReport report) async {
    final redaction = redactionPolicy.redact(report);
    final status = _crashStatusForConsent(
      consent: _consent,
      collectionEnabled: _collectionEnabled,
      storesLocalDiagnostics: true,
    );
    if (status == AiroCrashReportStatus.storedLocalOnly ||
        status == AiroCrashReportStatus.accepted) {
      if (_reports.length >= maxReports) {
        _reports.removeAt(0);
      }
      _reports.add(redaction);
    }
    return AiroCrashReportResult(status: status, redactionResult: redaction);
  }

  Future<void> updateConsent(AiroAnalyticsConsentState consent) async {
    _consent = consent;
    if (!consent.crash && !consent.diagnostics) {
      _reports.clear();
    }
  }

  Future<void> setCollectionEnabled(bool enabled) async {
    _collectionEnabled = enabled;
    if (!enabled) {
      _reports.clear();
    }
  }
}

class AiroProviderBackedCrashReportingService
    implements AiroCrashReportingService {
  AiroProviderBackedCrashReportingService({
    required AiroCrashProviderSender sender,
    AiroAnalyticsConsentState consent =
        const AiroAnalyticsConsentState.disabled(),
    this.redactionPolicy = AiroCrashRedactionPolicy.standard,
    bool collectionEnabled = false,
  }) : _sender = sender,
       _consent = consent,
       _collectionEnabled = collectionEnabled;

  final AiroCrashProviderSender _sender;
  final AiroCrashRedactionPolicy redactionPolicy;
  AiroAnalyticsConsentState _consent;
  bool _collectionEnabled;

  AiroAnalyticsConsentState get consent => _consent;
  bool get collectionEnabled => _collectionEnabled;

  @override
  Future<AiroCrashReportResult> report(AiroCrashReport report) async {
    final redaction = redactionPolicy.redact(report);
    final status = _crashStatusForConsent(
      consent: _consent,
      collectionEnabled: _collectionEnabled,
      storesLocalDiagnostics: false,
    );
    if (status != AiroCrashReportStatus.accepted) {
      return AiroCrashReportResult(status: status, redactionResult: redaction);
    }

    try {
      await _sender(redaction);
      return AiroCrashReportResult(
        status: AiroCrashReportStatus.accepted,
        redactionResult: redaction,
      );
    } catch (_) {
      return AiroCrashReportResult(
        status: AiroCrashReportStatus.providerUnavailable,
        redactionResult: redaction,
      );
    }
  }

  Future<void> updateConsent(AiroAnalyticsConsentState consent) async {
    _consent = consent;
  }

  Future<void> setCollectionEnabled(bool enabled) async {
    _collectionEnabled = enabled;
  }
}

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
       _collectionEnabled = collectionEnabled,
       _queue = AiroAnalyticsBoundedEventQueue(maxEvents: maxEvents);

  final AiroAnalyticsPrivacyFilter? privacyFilter;
  final int maxEvents;
  final AiroAnalyticsBoundedEventQueue _queue;
  AiroAnalyticsConsentState _consent;
  bool _collectionEnabled;
  int _resetGeneration = 0;

  List<AiroAnalyticsEvent> get events => _queue.events;
  AiroAnalyticsQueueSnapshot get queueSnapshot => _queue.snapshot();
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
    final offer = _queue.offer(event);
    if (!offer.accepted) {
      return AiroAnalyticsTrackResult(
        status: AiroAnalyticsTrackStatus.droppedQueueFull,
        queueResult: offer,
      );
    }

    return AiroAnalyticsTrackResult(
      status: result.status,
      violations: result.violations,
      queueResult: offer,
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
    final previousConsent = _consent;
    _consent = consent;
    final previousCount = _queue.events.length;
    _queue.removeWhere((event) {
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
      removedEventCount: previousCount - _queue.events.length,
      collectionEnabled: _collectionEnabled,
      resetGeneration: _resetGeneration,
    );
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    _collectionEnabled = enabled;
    if (!enabled) {
      _queue.clear();
    }
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> reset() async {
    _queue.clear();
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
    bool playbackActive = false,
    AiroAnalyticsProviderBackoffState providerBackoffState =
        const AiroAnalyticsProviderBackoffState.inactive(),
    DateTime Function()? clock,
  }) : _sender = sender,
       _consent = consent,
       _collectionEnabled = collectionEnabled,
       _playbackActive = playbackActive,
       _providerBackoffState = providerBackoffState,
       _clock = clock ?? _utcNow;

  final AiroAnalyticsProviderSender _sender;
  final AiroAnalyticsPrivacyFilter? privacyFilter;
  final DateTime Function() _clock;
  AiroAnalyticsConsentState _consent;
  bool _collectionEnabled;
  bool _playbackActive;
  AiroAnalyticsProviderBackoffState _providerBackoffState;
  int _resetGeneration = 0;

  AiroAnalyticsConsentState get consent => _consent;
  bool get collectionEnabled => _collectionEnabled;
  bool get playbackActive => _playbackActive;
  AiroAnalyticsProviderBackoffState get providerBackoffState =>
      _providerBackoffState;
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

    final decision = AiroAnalyticsUploadGate.evaluate(
      event: event,
      playbackActive: _playbackActive,
      providerBackoffState: _providerBackoffState,
      now: _clock(),
    );
    if (!decision.eligible) {
      final status =
          decision.code ==
              AiroAnalyticsUploadDecisionCode.deferredDuringPlayback
          ? AiroAnalyticsTrackStatus.deferredByPlayback
          : AiroAnalyticsTrackStatus.providerBackoffActive;
      return AiroAnalyticsTrackResult(status: status, uploadDecision: decision);
    }

    try {
      await _sender(event);
      _providerBackoffState =
          const AiroAnalyticsProviderBackoffState.inactive();
      return AiroAnalyticsTrackResult(
        status: result.status,
        violations: result.violations,
        uploadDecision: decision,
      );
    } catch (_) {
      _providerBackoffState = _providerBackoffState.recordFailure(_clock());
      return AiroAnalyticsTrackResult(
        status: AiroAnalyticsTrackStatus.providerUnavailable,
        uploadDecision: AiroAnalyticsUploadGate.evaluate(
          event: event,
          playbackActive: _playbackActive,
          providerBackoffState: _providerBackoffState,
          now: _clock(),
        ),
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

  void setPlaybackActive(bool active) {
    _playbackActive = active;
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

class AiroTvAnalyticsRetentionPolicies {
  const AiroTvAnalyticsRetentionPolicies._();

  static AiroAnalyticsRetentionPolicy standard() {
    return AiroAnalyticsRetentionPolicy(
      rules: [
        AiroAnalyticsRetentionRule(
          retentionClass: AiroAnalyticsRetentionClass.operational30Days,
          rawRetentionDays: 30,
          deleteOnConsentWithdrawal: false,
          exportable: true,
          allowedRoles: const {
            AiroAnalyticsAccessRole.privacyOfficer,
            AiroAnalyticsAccessRole.securityAuditor,
            AiroAnalyticsAccessRole.releaseEngineer,
          },
          allowedPurposes: const {
            AiroAnalyticsAccessPurpose.privacyRequest,
            AiroAnalyticsAccessPurpose.securityInvestigation,
            AiroAnalyticsAccessPurpose.releaseQuality,
          },
        ),
        AiroAnalyticsRetentionRule(
          retentionClass: AiroAnalyticsRetentionClass.product90Days,
          rawRetentionDays: 90,
          deleteOnConsentWithdrawal: true,
          exportable: true,
          allowedRoles: const {
            AiroAnalyticsAccessRole.productAnalyst,
            AiroAnalyticsAccessRole.privacyOfficer,
          },
          allowedPurposes: const {
            AiroAnalyticsAccessPurpose.productMeasurement,
            AiroAnalyticsAccessPurpose.privacyRequest,
          },
        ),
        AiroAnalyticsRetentionRule(
          retentionClass: AiroAnalyticsRetentionClass.diagnostics30Days,
          rawRetentionDays: 30,
          deleteOnConsentWithdrawal: true,
          exportable: true,
          allowedRoles: const {
            AiroAnalyticsAccessRole.privacyOfficer,
            AiroAnalyticsAccessRole.securityAuditor,
            AiroAnalyticsAccessRole.releaseEngineer,
          },
          allowedPurposes: const {
            AiroAnalyticsAccessPurpose.privacyRequest,
            AiroAnalyticsAccessPurpose.securityInvestigation,
            AiroAnalyticsAccessPurpose.releaseQuality,
          },
        ),
        AiroAnalyticsRetentionRule(
          retentionClass: AiroAnalyticsRetentionClass.crash90Days,
          rawRetentionDays: 90,
          deleteOnConsentWithdrawal: true,
          exportable: true,
          allowedRoles: const {
            AiroAnalyticsAccessRole.privacyOfficer,
            AiroAnalyticsAccessRole.securityAuditor,
            AiroAnalyticsAccessRole.releaseEngineer,
          },
          allowedPurposes: const {
            AiroAnalyticsAccessPurpose.privacyRequest,
            AiroAnalyticsAccessPurpose.securityInvestigation,
            AiroAnalyticsAccessPurpose.releaseQuality,
          },
        ),
        AiroAnalyticsRetentionRule(
          retentionClass: AiroAnalyticsRetentionClass.aggregateOnly,
          rawRetentionDays: 0,
          deleteOnConsentWithdrawal: false,
          exportable: false,
          allowedRoles: const {
            AiroAnalyticsAccessRole.productAnalyst,
            AiroAnalyticsAccessRole.privacyOfficer,
            AiroAnalyticsAccessRole.securityAuditor,
            AiroAnalyticsAccessRole.releaseEngineer,
          },
          allowedPurposes: const {
            AiroAnalyticsAccessPurpose.productMeasurement,
            AiroAnalyticsAccessPurpose.privacyRequest,
            AiroAnalyticsAccessPurpose.securityInvestigation,
            AiroAnalyticsAccessPurpose.releaseQuality,
          },
        ),
      ],
    );
  }
}

class AiroTvAnalyticsDashboardCatalogs {
  const AiroTvAnalyticsDashboardCatalogs._();

  static AiroAnalyticsDashboardCatalog standard() {
    return AiroAnalyticsDashboardCatalog(
      metrics: const [
        AiroAnalyticsDashboardMetricSpec(
          metricId: 'weekly_active_receivers',
          owner: 'product',
          purpose: AiroAnalyticsPurpose.product,
          retentionClass: AiroAnalyticsRetentionClass.aggregateOnly,
          surface: AiroAnalyticsDashboardSurface.executive,
          dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
        ),
        AiroAnalyticsDashboardMetricSpec(
          metricId: 'playback_startup_p95_bucket',
          owner: 'media',
          purpose: AiroAnalyticsPurpose.playbackQuality,
          retentionClass: AiroAnalyticsRetentionClass.product90Days,
          surface: AiroAnalyticsDashboardSurface.playbackQuality,
          dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
          alertable: true,
        ),
        AiroAnalyticsDashboardMetricSpec(
          metricId: 'legacy_decoder_fallback_rate',
          owner: 'platform_media',
          purpose: AiroAnalyticsPurpose.diagnostics,
          retentionClass: AiroAnalyticsRetentionClass.diagnostics30Days,
          surface: AiroAnalyticsDashboardSurface.legacyDevice,
          dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
          alertable: true,
        ),
        AiroAnalyticsDashboardMetricSpec(
          metricId: 'pairing_success_rate',
          owner: 'device_ecosystem',
          purpose: AiroAnalyticsPurpose.operational,
          retentionClass: AiroAnalyticsRetentionClass.operational30Days,
          surface: AiroAnalyticsDashboardSurface.deviceEcosystem,
          dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
          alertable: true,
        ),
        AiroAnalyticsDashboardMetricSpec(
          metricId: 'subscription_conversion_rate',
          owner: 'growth',
          purpose: AiroAnalyticsPurpose.product,
          retentionClass: AiroAnalyticsRetentionClass.product90Days,
          surface: AiroAnalyticsDashboardSurface.subscription,
          dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
          alertable: true,
        ),
        AiroAnalyticsDashboardMetricSpec(
          metricId: 'crash_rate_by_profile',
          owner: 'sre',
          purpose: AiroAnalyticsPurpose.crash,
          retentionClass: AiroAnalyticsRetentionClass.crash90Days,
          surface: AiroAnalyticsDashboardSurface.regression,
          dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
          alertable: true,
        ),
        AiroAnalyticsDashboardMetricSpec(
          metricId: 'provider_outage_rate',
          owner: 'sre',
          purpose: AiroAnalyticsPurpose.operational,
          retentionClass: AiroAnalyticsRetentionClass.operational30Days,
          surface: AiroAnalyticsDashboardSurface.regression,
          dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
          alertable: true,
        ),
        AiroAnalyticsDashboardMetricSpec(
          metricId: 'privacy_deletion_latency_bucket',
          owner: 'privacy',
          purpose: AiroAnalyticsPurpose.operational,
          retentionClass: AiroAnalyticsRetentionClass.operational30Days,
          surface: AiroAnalyticsDashboardSurface.regression,
          dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
          alertable: true,
        ),
      ],
      alerts: const [
        AiroAnalyticsOperationalAlertRule(
          alertId: 'playback_startup_regression',
          metricId: 'playback_startup_p95_bucket',
          severity: AiroAnalyticsAlertSeverity.warning,
          comparison: AiroAnalyticsAlertComparison.greaterThan,
          threshold: 3,
          evaluationWindowMinutes: 30,
          runbookId: 'runbook_playback_startup_regression',
        ),
        AiroAnalyticsOperationalAlertRule(
          alertId: 'crash_spike_by_profile',
          metricId: 'crash_rate_by_profile',
          severity: AiroAnalyticsAlertSeverity.critical,
          comparison: AiroAnalyticsAlertComparison.greaterThan,
          threshold: 0.02,
          evaluationWindowMinutes: 15,
          runbookId: 'runbook_crash_spike',
        ),
        AiroAnalyticsOperationalAlertRule(
          alertId: 'legacy_decoder_fallback_spike',
          metricId: 'legacy_decoder_fallback_rate',
          severity: AiroAnalyticsAlertSeverity.warning,
          comparison: AiroAnalyticsAlertComparison.greaterThan,
          threshold: 0.15,
          evaluationWindowMinutes: 60,
          runbookId: 'runbook_legacy_decoder_fallback',
        ),
        AiroAnalyticsOperationalAlertRule(
          alertId: 'pairing_success_regression',
          metricId: 'pairing_success_rate',
          severity: AiroAnalyticsAlertSeverity.warning,
          comparison: AiroAnalyticsAlertComparison.lessThan,
          threshold: 0.92,
          evaluationWindowMinutes: 30,
          runbookId: 'runbook_pairing_success',
        ),
        AiroAnalyticsOperationalAlertRule(
          alertId: 'provider_outage_regression',
          metricId: 'provider_outage_rate',
          severity: AiroAnalyticsAlertSeverity.critical,
          comparison: AiroAnalyticsAlertComparison.greaterThan,
          threshold: 0.05,
          evaluationWindowMinutes: 15,
          runbookId: 'runbook_provider_outage',
        ),
        AiroAnalyticsOperationalAlertRule(
          alertId: 'privacy_deletion_latency_breach',
          metricId: 'privacy_deletion_latency_bucket',
          severity: AiroAnalyticsAlertSeverity.critical,
          comparison: AiroAnalyticsAlertComparison.greaterThan,
          threshold: 24,
          evaluationWindowMinutes: 60,
          runbookId: 'runbook_privacy_deletion_latency',
        ),
      ],
    );
  }
}

class AiroTvAnalyticsSelfHostedGateways {
  const AiroTvAnalyticsSelfHostedGateways._();

  static AiroAnalyticsSelfHostedGatewayPolicy standard() {
    return AiroAnalyticsSelfHostedGatewayPolicy(
      gatewayId: 'airo_tv_self_hosted_gateway',
      schemaRegistry: AiroTvAnalyticsSchemas.registry(),
      retentionPolicy: AiroTvAnalyticsRetentionPolicies.standard(),
      allowedRegions: const {
        AiroAnalyticsGatewayRegion.us,
        AiroAnalyticsGatewayRegion.eu,
        AiroAnalyticsGatewayRegion.india,
      },
      maxEventsPerMinute: 120,
    );
  }
}

class AiroTvAnalyticsProductEditionProfiles {
  const AiroTvAnalyticsProductEditionProfiles._();

  static const Set<String> _playbackEventNames = {
    'playback_startup_completed',
    'playback_buffering_summary',
    'playback_failover_completed',
    'playback_quality_sample',
    'playback_completion_summary',
  };

  static const Set<String> _deviceEcosystemEventNames = {
    'pairing_completed',
    'handoff_completed',
    'device_discovery_summary',
    'command_route_latency',
    'delegation_task_completed',
    'companion_availability_summary',
  };

  static const Set<String> _diagnosticEventNames = {'legacy_decoder_fallback'};

  static const Set<String> _productEventNames = {'subscription_conversion'};

  static AiroAnalyticsProductEditionProfile fullTv() {
    return AiroAnalyticsProductEditionProfile(
      productProfile: AiroAnalyticsProductProfile.fullTv,
      displayName: 'Full TV',
      allowedPurposes: const {
        AiroAnalyticsPurpose.operational,
        AiroAnalyticsPurpose.product,
        AiroAnalyticsPurpose.playbackQuality,
        AiroAnalyticsPurpose.diagnostics,
        AiroAnalyticsPurpose.crash,
        AiroAnalyticsPurpose.personalized,
      },
      eventFamilies: const {
        AiroAnalyticsEventFamily.operationalCore,
        AiroAnalyticsEventFamily.deviceEcosystem,
        AiroAnalyticsEventFamily.delegation,
        AiroAnalyticsEventFamily.playbackQuality,
        AiroAnalyticsEventFamily.diagnostics,
        AiroAnalyticsEventFamily.crashReporting,
        AiroAnalyticsEventFamily.productGrowth,
        AiroAnalyticsEventFamily.personalization,
      },
      eventNames: const {
        ..._playbackEventNames,
        ..._deviceEcosystemEventNames,
        ..._diagnosticEventNames,
        ..._productEventNames,
      },
      providerKind: AiroAnalyticsProviderKind.vendorAdapter,
      maxQueueEvents: 500,
      maxCrashReports: 50,
      localRetentionDays: 30,
      externalUploadAllowed: true,
    );
  }

  static AiroAnalyticsProductEditionProfile standardTv() {
    return AiroAnalyticsProductEditionProfile(
      productProfile: AiroAnalyticsProductProfile.standardTv,
      displayName: 'Standard TV',
      allowedPurposes: const {
        AiroAnalyticsPurpose.operational,
        AiroAnalyticsPurpose.product,
        AiroAnalyticsPurpose.playbackQuality,
        AiroAnalyticsPurpose.diagnostics,
        AiroAnalyticsPurpose.crash,
      },
      eventFamilies: const {
        AiroAnalyticsEventFamily.operationalCore,
        AiroAnalyticsEventFamily.deviceEcosystem,
        AiroAnalyticsEventFamily.delegation,
        AiroAnalyticsEventFamily.playbackQuality,
        AiroAnalyticsEventFamily.diagnostics,
        AiroAnalyticsEventFamily.crashReporting,
        AiroAnalyticsEventFamily.productGrowth,
      },
      eventNames: const {
        ..._playbackEventNames,
        ..._deviceEcosystemEventNames,
        ..._diagnosticEventNames,
        ..._productEventNames,
      },
      providerKind: AiroAnalyticsProviderKind.vendorAdapter,
      maxQueueEvents: 350,
      maxCrashReports: 40,
      localRetentionDays: 30,
      externalUploadAllowed: true,
    );
  }

  static AiroAnalyticsProductEditionProfile liteReceiver() {
    return AiroAnalyticsProductEditionProfile(
      productProfile: AiroAnalyticsProductProfile.liteReceiver,
      displayName: 'Lite Receiver',
      allowedPurposes: const {
        AiroAnalyticsPurpose.operational,
        AiroAnalyticsPurpose.playbackQuality,
        AiroAnalyticsPurpose.diagnostics,
        AiroAnalyticsPurpose.crash,
      },
      eventFamilies: const {
        AiroAnalyticsEventFamily.operationalCore,
        AiroAnalyticsEventFamily.deviceEcosystem,
        AiroAnalyticsEventFamily.delegation,
        AiroAnalyticsEventFamily.playbackQuality,
        AiroAnalyticsEventFamily.diagnostics,
        AiroAnalyticsEventFamily.crashReporting,
      },
      eventNames: const {
        ..._playbackEventNames,
        ..._deviceEcosystemEventNames,
        ..._diagnosticEventNames,
      },
      providerKind: AiroAnalyticsProviderKind.vendorAdapter,
      maxQueueEvents: 150,
      maxCrashReports: 20,
      localRetentionDays: 14,
      externalUploadAllowed: true,
    );
  }

  static AiroAnalyticsProductEditionProfile embeddedReceiver() {
    return AiroAnalyticsProductEditionProfile(
      productProfile: AiroAnalyticsProductProfile.embeddedReceiver,
      displayName: 'Embedded Receiver',
      allowedPurposes: const {
        AiroAnalyticsPurpose.operational,
        AiroAnalyticsPurpose.diagnostics,
      },
      eventFamilies: const {
        AiroAnalyticsEventFamily.operationalCore,
        AiroAnalyticsEventFamily.deviceEcosystem,
        AiroAnalyticsEventFamily.delegation,
        AiroAnalyticsEventFamily.diagnostics,
      },
      eventNames: const {
        ..._deviceEcosystemEventNames,
        ..._diagnosticEventNames,
      },
      providerKind: AiroAnalyticsProviderKind.localDiagnostics,
      maxQueueEvents: 50,
      maxCrashReports: 10,
      localRetentionDays: 7,
      localOnly: true,
    );
  }

  static AiroAnalyticsProductEditionProfile mobileCompanion() {
    return AiroAnalyticsProductEditionProfile(
      productProfile: AiroAnalyticsProductProfile.mobileCompanion,
      displayName: 'Mobile Companion',
      allowedPurposes: const {
        AiroAnalyticsPurpose.operational,
        AiroAnalyticsPurpose.product,
        AiroAnalyticsPurpose.diagnostics,
        AiroAnalyticsPurpose.crash,
      },
      eventFamilies: const {
        AiroAnalyticsEventFamily.operationalCore,
        AiroAnalyticsEventFamily.deviceEcosystem,
        AiroAnalyticsEventFamily.delegation,
        AiroAnalyticsEventFamily.diagnostics,
        AiroAnalyticsEventFamily.crashReporting,
        AiroAnalyticsEventFamily.productGrowth,
      },
      eventNames: const {
        ..._deviceEcosystemEventNames,
        ..._diagnosticEventNames,
        ..._productEventNames,
      },
      providerKind: AiroAnalyticsProviderKind.vendorAdapter,
      maxQueueEvents: 250,
      maxCrashReports: 30,
      localRetentionDays: 30,
      externalUploadAllowed: true,
    );
  }

  static AiroAnalyticsProductEditionProfile desktopCompanion() {
    return AiroAnalyticsProductEditionProfile(
      productProfile: AiroAnalyticsProductProfile.desktopCompanion,
      displayName: 'Desktop Companion',
      allowedPurposes: const {
        AiroAnalyticsPurpose.operational,
        AiroAnalyticsPurpose.product,
        AiroAnalyticsPurpose.diagnostics,
        AiroAnalyticsPurpose.crash,
      },
      eventFamilies: const {
        AiroAnalyticsEventFamily.operationalCore,
        AiroAnalyticsEventFamily.deviceEcosystem,
        AiroAnalyticsEventFamily.delegation,
        AiroAnalyticsEventFamily.diagnostics,
        AiroAnalyticsEventFamily.crashReporting,
        AiroAnalyticsEventFamily.productGrowth,
      },
      eventNames: const {
        ..._deviceEcosystemEventNames,
        ..._diagnosticEventNames,
        ..._productEventNames,
      },
      providerKind: AiroAnalyticsProviderKind.vendorAdapter,
      maxQueueEvents: 250,
      maxCrashReports: 30,
      localRetentionDays: 30,
      externalUploadAllowed: true,
    );
  }
}

class AiroTvAnalyticsSchemas {
  const AiroTvAnalyticsSchemas._();

  static AiroAnalyticsSchemaRegistry registry() {
    return AiroAnalyticsSchemaRegistry(
      schemas: [
        playbackStartupCompleted(),
        playbackBufferingSummary(),
        playbackFailoverCompleted(),
        playbackQualitySample(),
        playbackCompletionSummary(),
        pairingCompleted(),
        handoffCompleted(),
        deviceDiscoverySummary(),
        commandRouteLatency(),
        delegationTaskCompleted(),
        companionAvailabilitySummary(),
        legacyDecoderFallback(),
        subscriptionConversion(),
      ],
    );
  }

  static const Set<String> _playbackProhibitedFields = {
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
    'localPath',
    'path',
    'localIp',
    'ipAddress',
    'query',
    'searchQuery',
    'voiceTranscript',
  };

  static AiroAnalyticsEventSchema playbackStartupCompleted() {
    return AiroAnalyticsEventSchema(
      name: 'playback_startup_completed',
      owner: 'media',
      purpose: AiroAnalyticsPurpose.playbackQuality,
      retentionClass: AiroAnalyticsRetentionClass.product90Days,
      dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
      prohibitedFields: _playbackProhibitedFields,
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

  static AiroAnalyticsEventSchema playbackBufferingSummary() {
    return AiroAnalyticsEventSchema(
      name: 'playback_buffering_summary',
      owner: 'media',
      purpose: AiroAnalyticsPurpose.playbackQuality,
      retentionClass: AiroAnalyticsRetentionClass.product90Days,
      dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
      prohibitedFields: _playbackProhibitedFields,
      allowedFields: const [
        AiroAnalyticsFieldSchema(
          name: 'source_type',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'stall_count_bucket',
          kind: AiroAnalyticsFieldKind.bucket,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'stall_duration_bucket',
          kind: AiroAnalyticsFieldKind.bucket,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'resolution_bucket',
          kind: AiroAnalyticsFieldKind.bucket,
        ),
      ],
    );
  }

  static AiroAnalyticsEventSchema playbackFailoverCompleted() {
    return AiroAnalyticsEventSchema(
      name: 'playback_failover_completed',
      owner: 'media',
      purpose: AiroAnalyticsPurpose.playbackQuality,
      retentionClass: AiroAnalyticsRetentionClass.product90Days,
      dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
      prohibitedFields: _playbackProhibitedFields,
      allowedFields: const [
        AiroAnalyticsFieldSchema(
          name: 'source_type',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'failover_reason',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'route_type',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'decoder_type',
          kind: AiroAnalyticsFieldKind.category,
        ),
      ],
    );
  }

  static AiroAnalyticsEventSchema playbackQualitySample() {
    return AiroAnalyticsEventSchema(
      name: 'playback_quality_sample',
      owner: 'media',
      purpose: AiroAnalyticsPurpose.playbackQuality,
      retentionClass: AiroAnalyticsRetentionClass.product90Days,
      dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
      prohibitedFields: _playbackProhibitedFields,
      allowedFields: const [
        AiroAnalyticsFieldSchema(
          name: 'source_type',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'bitrate_bucket',
          kind: AiroAnalyticsFieldKind.bucket,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'resolution_bucket',
          kind: AiroAnalyticsFieldKind.bucket,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'decoder_type',
          kind: AiroAnalyticsFieldKind.category,
        ),
      ],
    );
  }

  static AiroAnalyticsEventSchema playbackCompletionSummary() {
    return AiroAnalyticsEventSchema(
      name: 'playback_completion_summary',
      owner: 'media',
      purpose: AiroAnalyticsPurpose.playbackQuality,
      retentionClass: AiroAnalyticsRetentionClass.product90Days,
      dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
      prohibitedFields: _playbackProhibitedFields,
      allowedFields: const [
        AiroAnalyticsFieldSchema(
          name: 'source_type',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'completion_bucket',
          kind: AiroAnalyticsFieldKind.bucket,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'exit_reason',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'resolution_bucket',
          kind: AiroAnalyticsFieldKind.bucket,
        ),
      ],
    );
  }

  static const Set<String> _deviceEcosystemProhibitedFields = {
    'deviceId',
    'deviceName',
    'hostname',
    'ssid',
    'bssid',
    'macAddress',
    'localIp',
    'ipAddress',
    'channel',
    'mediaTitle',
    'streamUrl',
    'playlistUrl',
    'prompt',
    'transcript',
    'providerPayload',
    'contact',
    'email',
  };

  static AiroAnalyticsEventSchema pairingCompleted() {
    return AiroAnalyticsEventSchema(
      name: 'pairing_completed',
      owner: 'device_ecosystem',
      purpose: AiroAnalyticsPurpose.operational,
      retentionClass: AiroAnalyticsRetentionClass.operational30Days,
      dashboardRequirement: AiroAnalyticsDashboardRequirement.optional,
      prohibitedFields: _deviceEcosystemProhibitedFields,
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
        AiroAnalyticsFieldSchema(
          name: 'result_category',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
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
      prohibitedFields: _deviceEcosystemProhibitedFields,
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
        AiroAnalyticsFieldSchema(
          name: 'route_type',
          kind: AiroAnalyticsFieldKind.category,
        ),
        AiroAnalyticsFieldSchema(
          name: 'command_latency_bucket',
          kind: AiroAnalyticsFieldKind.bucket,
        ),
      ],
    );
  }

  static AiroAnalyticsEventSchema deviceDiscoverySummary() {
    return AiroAnalyticsEventSchema(
      name: 'device_discovery_summary',
      owner: 'device_ecosystem',
      purpose: AiroAnalyticsPurpose.operational,
      retentionClass: AiroAnalyticsRetentionClass.operational30Days,
      dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
      prohibitedFields: _deviceEcosystemProhibitedFields,
      allowedFields: const [
        AiroAnalyticsFieldSchema(
          name: 'source_profile',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'discovery_method',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'availability_category',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'device_count_bucket',
          kind: AiroAnalyticsFieldKind.bucket,
          required: true,
        ),
      ],
    );
  }

  static AiroAnalyticsEventSchema commandRouteLatency() {
    return AiroAnalyticsEventSchema(
      name: 'command_route_latency',
      owner: 'device_ecosystem',
      purpose: AiroAnalyticsPurpose.operational,
      retentionClass: AiroAnalyticsRetentionClass.operational30Days,
      dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
      prohibitedFields: _deviceEcosystemProhibitedFields,
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
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'command_category',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'latency_bucket',
          kind: AiroAnalyticsFieldKind.bucket,
          required: true,
        ),
      ],
    );
  }

  static AiroAnalyticsEventSchema delegationTaskCompleted() {
    return AiroAnalyticsEventSchema(
      name: 'delegation_task_completed',
      owner: 'delegation',
      purpose: AiroAnalyticsPurpose.operational,
      retentionClass: AiroAnalyticsRetentionClass.operational30Days,
      dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
      prohibitedFields: _deviceEcosystemProhibitedFields,
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
          name: 'task_category',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'result_category',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'latency_bucket',
          kind: AiroAnalyticsFieldKind.bucket,
        ),
      ],
    );
  }

  static AiroAnalyticsEventSchema companionAvailabilitySummary() {
    return AiroAnalyticsEventSchema(
      name: 'companion_availability_summary',
      owner: 'device_ecosystem',
      purpose: AiroAnalyticsPurpose.operational,
      retentionClass: AiroAnalyticsRetentionClass.operational30Days,
      dashboardRequirement: AiroAnalyticsDashboardRequirement.required,
      prohibitedFields: _deviceEcosystemProhibitedFields,
      allowedFields: const [
        AiroAnalyticsFieldSchema(
          name: 'companion_profile',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'availability_category',
          kind: AiroAnalyticsFieldKind.category,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'route_health_bucket',
          kind: AiroAnalyticsFieldKind.bucket,
          required: true,
        ),
        AiroAnalyticsFieldSchema(
          name: 'queue_depth_bucket',
          kind: AiroAnalyticsFieldKind.bucket,
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

class AiroTvPlaybackQualityTelemetrySuites {
  const AiroTvPlaybackQualityTelemetrySuites._();

  static AiroAnalyticsSchemaFixtureSuite standard() {
    return AiroAnalyticsSchemaFixtureSuite(
      suiteId: 'airo-tv-playback-quality-telemetry',
      cases: [
        AiroAnalyticsSchemaFixtureCase(
          caseId: 'startup-bucketed',
          event: AiroAnalyticsEvent(
            name: 'playback_startup_completed',
            owner: 'media',
            purpose: AiroAnalyticsPurpose.playbackQuality,
            params: const {
              'source_type': 'iptv',
              'startup_bucket': '1_3s',
              'decoder_type': 'hardware',
              'resolution_bucket': '1080p',
            },
          ),
          expectedCodes: const [AiroAnalyticsSchemaValidationCode.accepted],
        ),
        AiroAnalyticsSchemaFixtureCase(
          caseId: 'buffering-bucketed',
          event: AiroAnalyticsEvent(
            name: 'playback_buffering_summary',
            owner: 'media',
            purpose: AiroAnalyticsPurpose.playbackQuality,
            params: const {
              'source_type': 'iptv',
              'stall_count_bucket': '1_2',
              'stall_duration_bucket': '3_10s',
              'resolution_bucket': '1080p',
            },
          ),
          expectedCodes: const [AiroAnalyticsSchemaValidationCode.accepted],
        ),
        AiroAnalyticsSchemaFixtureCase(
          caseId: 'failover-categorized',
          event: AiroAnalyticsEvent(
            name: 'playback_failover_completed',
            owner: 'media',
            purpose: AiroAnalyticsPurpose.playbackQuality,
            params: const {
              'source_type': 'iptv',
              'failover_reason': 'decoder_error',
              'route_type': 'phone_local',
              'decoder_type': 'software',
            },
          ),
          expectedCodes: const [AiroAnalyticsSchemaValidationCode.accepted],
        ),
        AiroAnalyticsSchemaFixtureCase(
          caseId: 'bitrate-resolution-bucketed',
          event: AiroAnalyticsEvent(
            name: 'playback_quality_sample',
            owner: 'media',
            purpose: AiroAnalyticsPurpose.playbackQuality,
            params: const {
              'source_type': 'iptv',
              'bitrate_bucket': '3_6_mbps',
              'resolution_bucket': '1080p',
              'decoder_type': 'hardware',
            },
          ),
          expectedCodes: const [AiroAnalyticsSchemaValidationCode.accepted],
        ),
        AiroAnalyticsSchemaFixtureCase(
          caseId: 'completion-bucketed',
          event: AiroAnalyticsEvent(
            name: 'playback_completion_summary',
            owner: 'media',
            purpose: AiroAnalyticsPurpose.playbackQuality,
            params: const {
              'source_type': 'iptv',
              'completion_bucket': '90_100pct',
              'exit_reason': 'user_exit',
              'resolution_bucket': '1080p',
            },
          ),
          expectedCodes: const [AiroAnalyticsSchemaValidationCode.accepted],
        ),
        AiroAnalyticsSchemaFixtureCase(
          caseId: 'raw-bitrate-rejected',
          event: AiroAnalyticsEvent(
            name: 'playback_quality_sample',
            owner: 'media',
            purpose: AiroAnalyticsPurpose.playbackQuality,
            params: const {
              'source_type': 'iptv',
              'bitrate_bucket': 4500000,
              'resolution_bucket': '1080p',
            },
          ),
          expectedCodes: const [
            AiroAnalyticsSchemaValidationCode.fieldKindMismatch,
          ],
        ),
        AiroAnalyticsSchemaFixtureCase(
          caseId: 'source-url-rejected',
          event: AiroAnalyticsEvent(
            name: 'playback_startup_completed',
            owner: 'media',
            purpose: AiroAnalyticsPurpose.playbackQuality,
            params: const {
              'source_type': 'https://example.com/live.m3u8',
              'startup_bucket': '1_3s',
            },
          ),
          expectedCodes: const [
            AiroAnalyticsSchemaValidationCode.fieldKindMismatch,
            AiroAnalyticsSchemaValidationCode.privacyViolation,
          ],
        ),
        AiroAnalyticsSchemaFixtureCase(
          caseId: 'completion-required-field-rejected',
          event: AiroAnalyticsEvent(
            name: 'playback_completion_summary',
            owner: 'media',
            purpose: AiroAnalyticsPurpose.playbackQuality,
            params: const {'source_type': 'iptv', 'exit_reason': 'user_exit'},
          ),
          expectedCodes: const [
            AiroAnalyticsSchemaValidationCode.requiredFieldMissing,
          ],
        ),
      ],
    );
  }
}

class AiroTvDeviceEcosystemTelemetrySuites {
  const AiroTvDeviceEcosystemTelemetrySuites._();

  static AiroAnalyticsSchemaFixtureSuite standard() {
    return AiroAnalyticsSchemaFixtureSuite(
      suiteId: 'airo-tv-device-ecosystem-telemetry',
      cases: [
        AiroAnalyticsSchemaFixtureCase(
          caseId: 'pairing-completed-safe',
          event: AiroAnalyticsEvent(
            name: 'pairing_completed',
            owner: 'device_ecosystem',
            purpose: AiroAnalyticsPurpose.operational,
            params: const {
              'source_profile': 'mobile_companion',
              'target_profile': 'lite_receiver',
              'route_type': 'lan',
              'result_category': 'success',
            },
          ),
          expectedCodes: const [AiroAnalyticsSchemaValidationCode.accepted],
        ),
        AiroAnalyticsSchemaFixtureCase(
          caseId: 'handoff-bucketed-safe',
          event: AiroAnalyticsEvent(
            name: 'handoff_completed',
            owner: 'media',
            purpose: AiroAnalyticsPurpose.operational,
            params: const {
              'source_profile': 'mobile_companion',
              'target_profile': 'lite_receiver',
              'route_type': 'phone_local',
              'command_latency_bucket': '100_300ms',
              'result_category': 'success',
            },
          ),
          expectedCodes: const [AiroAnalyticsSchemaValidationCode.accepted],
        ),
        AiroAnalyticsSchemaFixtureCase(
          caseId: 'discovery-summary-safe',
          event: AiroAnalyticsEvent(
            name: 'device_discovery_summary',
            owner: 'device_ecosystem',
            purpose: AiroAnalyticsPurpose.operational,
            params: const {
              'source_profile': 'full_tv',
              'discovery_method': 'mdns',
              'availability_category': 'companion_available',
              'device_count_bucket': '1_3',
            },
          ),
          expectedCodes: const [AiroAnalyticsSchemaValidationCode.accepted],
        ),
        AiroAnalyticsSchemaFixtureCase(
          caseId: 'command-route-latency-safe',
          event: AiroAnalyticsEvent(
            name: 'command_route_latency',
            owner: 'device_ecosystem',
            purpose: AiroAnalyticsPurpose.operational,
            params: const {
              'source_profile': 'mobile_companion',
              'target_profile': 'full_tv',
              'route_type': 'lan',
              'command_category': 'playback',
              'latency_bucket': '0_150ms',
            },
          ),
          expectedCodes: const [AiroAnalyticsSchemaValidationCode.accepted],
        ),
        AiroAnalyticsSchemaFixtureCase(
          caseId: 'delegation-completed-safe',
          event: AiroAnalyticsEvent(
            name: 'delegation_task_completed',
            owner: 'delegation',
            purpose: AiroAnalyticsPurpose.operational,
            params: const {
              'source_profile': 'lite_receiver',
              'target_profile': 'mobile_companion',
              'task_category': 'semantic_search',
              'result_category': 'success',
              'latency_bucket': '1_3s',
            },
          ),
          expectedCodes: const [AiroAnalyticsSchemaValidationCode.accepted],
        ),
        AiroAnalyticsSchemaFixtureCase(
          caseId: 'companion-availability-safe',
          event: AiroAnalyticsEvent(
            name: 'companion_availability_summary',
            owner: 'device_ecosystem',
            purpose: AiroAnalyticsPurpose.operational,
            params: const {
              'companion_profile': 'mobile_companion',
              'availability_category': 'online',
              'route_health_bucket': 'healthy',
              'queue_depth_bucket': '0',
            },
          ),
          expectedCodes: const [AiroAnalyticsSchemaValidationCode.accepted],
        ),
        AiroAnalyticsSchemaFixtureCase(
          caseId: 'discovery-local-address-rejected',
          event: AiroAnalyticsEvent(
            name: 'device_discovery_summary',
            owner: 'device_ecosystem',
            purpose: AiroAnalyticsPurpose.operational,
            params: const {
              'source_profile': 'full_tv',
              'discovery_method': 'mdns',
              'availability_category': 'companion_available',
              'device_count_bucket': '1_3',
              'localIp': '192.168.1.10',
            },
          ),
          expectedCodes: const [
            AiroAnalyticsSchemaValidationCode.fieldNotAllowed,
            AiroAnalyticsSchemaValidationCode.privacyViolation,
          ],
        ),
        AiroAnalyticsSchemaFixtureCase(
          caseId: 'command-raw-latency-rejected',
          event: AiroAnalyticsEvent(
            name: 'command_route_latency',
            owner: 'device_ecosystem',
            purpose: AiroAnalyticsPurpose.operational,
            params: const {
              'source_profile': 'mobile_companion',
              'target_profile': 'full_tv',
              'route_type': 'lan',
              'command_category': 'playback',
              'latency_bucket': 87,
            },
          ),
          expectedCodes: const [
            AiroAnalyticsSchemaValidationCode.fieldKindMismatch,
          ],
        ),
        AiroAnalyticsSchemaFixtureCase(
          caseId: 'delegation-prompt-rejected',
          event: AiroAnalyticsEvent(
            name: 'delegation_task_completed',
            owner: 'delegation',
            purpose: AiroAnalyticsPurpose.operational,
            params: const {
              'source_profile': 'lite_receiver',
              'target_profile': 'mobile_companion',
              'task_category': 'semantic_search',
              'result_category': 'success',
              'prompt': 'find private playlist',
            },
          ),
          expectedCodes: const [
            AiroAnalyticsSchemaValidationCode.fieldNotAllowed,
            AiroAnalyticsSchemaValidationCode.privacyViolation,
          ],
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

AiroCrashReportStatus _crashStatusForConsent({
  required AiroAnalyticsConsentState consent,
  required bool collectionEnabled,
  required bool storesLocalDiagnostics,
}) {
  if (!collectionEnabled) {
    return AiroCrashReportStatus.droppedByCollectionDisabled;
  }
  if (consent.localOnly) {
    return storesLocalDiagnostics
        ? AiroCrashReportStatus.storedLocalOnly
        : AiroCrashReportStatus.uploadBlockedLocalOnly;
  }
  if (consent.crash) {
    return AiroCrashReportStatus.accepted;
  }
  if (storesLocalDiagnostics && consent.diagnostics) {
    return AiroCrashReportStatus.storedLocalOnly;
  }
  return AiroCrashReportStatus.droppedByConsent;
}

AiroCrashRedactionCode _crashCodeForPrivacyCode(AiroAnalyticsPrivacyCode code) {
  return switch (code) {
    AiroAnalyticsPrivacyCode.prohibitedFieldName =>
      AiroCrashRedactionCode.prohibitedFieldName,
    AiroAnalyticsPrivacyCode.urlValue => AiroCrashRedactionCode.urlValue,
    AiroAnalyticsPrivacyCode.localPathValue =>
      AiroCrashRedactionCode.localPathValue,
    AiroAnalyticsPrivacyCode.localIpValue =>
      AiroCrashRedactionCode.localIpValue,
    AiroAnalyticsPrivacyCode.credentialLikeValue =>
      AiroCrashRedactionCode.credentialLikeValue,
  };
}

int _priorityRank(AiroAnalyticsPriority priority) {
  return switch (priority) {
    AiroAnalyticsPriority.low => 0,
    AiroAnalyticsPriority.normal => 1,
    AiroAnalyticsPriority.high => 2,
    AiroAnalyticsPriority.critical => 3,
  };
}

DateTime _utcNow() => DateTime.now().toUtc();

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
