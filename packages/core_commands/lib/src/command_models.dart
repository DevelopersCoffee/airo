import 'package:core_pairing/core_pairing.dart';
import 'package:equatable/equatable.dart';

const String kAiroCommandSchemaVersion = '1.0.0';
const int kAiroCommandProtocolVersion = 1;

enum AiroCommandKind {
  playback('playback'),
  navigation('navigation'),
  textInput('text_input'),
  aiDelegation('ai_delegation'),
  device('device');

  const AiroCommandKind(this.stableId);

  final String stableId;
}

enum AiroCommandAction {
  play('play'),
  pause('pause'),
  stop('stop'),
  seek('seek'),
  select('select'),
  back('back'),
  home('home'),
  focus('focus'),
  submitTextHandle('submit_text_handle'),
  searchHandle('search_handle'),
  askAssistantHandle('ask_assistant_handle'),
  refreshCapabilities('refresh_capabilities'),
  diagnosticsPing('diagnostics_ping');

  const AiroCommandAction(this.stableId);

  final String stableId;
}

enum AiroCommandPrivacyCode {
  prohibitedFieldName('prohibited_field_name'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value');

  const AiroCommandPrivacyCode(this.stableId);

  final String stableId;
}

enum AiroCommandValidationCode {
  accepted('accepted'),
  schemaMismatch('schema_mismatch'),
  protocolTooOld('protocol_too_old'),
  protocolTooNew('protocol_too_new'),
  expired('expired'),
  targetMismatch('target_mismatch'),
  scopeMissing('scope_missing'),
  duplicateIdempotencyKey('duplicate_idempotency_key'),
  unsafePayload('unsafe_payload');

  const AiroCommandValidationCode(this.stableId);

  final String stableId;
}

enum AiroCommandResultStatus {
  accepted('accepted'),
  inProgress('in_progress'),
  rejected('rejected'),
  expired('expired'),
  duplicate('duplicate'),
  unsupported('unsupported'),
  completed('completed'),
  failed('failed'),
  conflict('conflict'),
  authRequired('auth_required'),
  receiverUnavailable('receiver_unavailable');

  const AiroCommandResultStatus(this.stableId);

  final String stableId;
}

enum AiroCommandDeliveryPath {
  lan('lan'),
  cloud('cloud'),
  localLoopback('local_loopback'),
  recoveryReplay('recovery_replay');

  const AiroCommandDeliveryPath(this.stableId);

  final String stableId;
}

enum AiroCommandLifecycleAction {
  execute('execute'),
  duplicate('duplicate'),
  reject('reject'),
  noOp('no_op');

  const AiroCommandLifecycleAction(this.stableId);

  final String stableId;
}

enum AiroCommandLifecycleCode {
  accepted('accepted'),
  expired('expired'),
  targetMismatch('target_mismatch'),
  scopeMissing('scope_missing'),
  unsafePayload('unsafe_payload'),
  duplicateCommandId('duplicate_command_id'),
  duplicateIdempotencyKey('duplicate_idempotency_key'),
  staleExpectedRevision('stale_expected_revision'),
  revisionConflict('revision_conflict'),
  receiverUnavailable('receiver_unavailable'),
  unsupportedAction('unsupported_action'),
  storeUnavailable('store_unavailable');

  const AiroCommandLifecycleCode(this.stableId);

  final String stableId;
}

class AiroCommandPrivacyViolation extends Equatable {
  const AiroCommandPrivacyViolation({required this.code, required this.field});

  final AiroCommandPrivacyCode code;
  final String field;

  @override
  List<Object?> get props => [code, field];
}

class AiroCommandPrivacyResult extends Equatable {
  AiroCommandPrivacyResult({
    required List<AiroCommandPrivacyViolation> violations,
  }) : violations = List.unmodifiable(violations);

  final List<AiroCommandPrivacyViolation> violations;

  bool get accepted => violations.isEmpty;

  @override
  List<Object?> get props => [violations];
}

class AiroCommandPrivacyFilter {
  AiroCommandPrivacyFilter({
    Set<String> prohibitedFields = _defaultProhibitedFields,
  }) : prohibitedFields = Set.unmodifiable(
         prohibitedFields.map(_normalizeFieldName),
       );

  static final AiroCommandPrivacyFilter standard = AiroCommandPrivacyFilter();

  static const Set<String> _defaultProhibitedFields = {
    'playlist',
    'playlistName',
    'playlistUrl',
    'mediaUrl',
    'sourceUrl',
    'streamUrl',
    'signedUrl',
    'url',
    'credential',
    'authorization',
    'authHeader',
    'cookie',
    'history',
    'viewingHistory',
    'localIp',
    'ipAddress',
    'localPath',
    'path',
    'query',
    'searchText',
    'voiceTranscript',
    'diagnostics',
    'analytics',
    'rawText',
  };

  final Set<String> prohibitedFields;

  AiroCommandPrivacyResult validate(Map<String, String> values) {
    final violations = <AiroCommandPrivacyViolation>[];

    for (final entry in values.entries) {
      final field = entry.key;
      if (prohibitedFields.contains(_normalizeFieldName(field))) {
        violations.add(
          AiroCommandPrivacyViolation(
            code: AiroCommandPrivacyCode.prohibitedFieldName,
            field: field,
          ),
        );
      }

      final code = _classifyStringValue(entry.value);
      if (code != null) {
        violations.add(AiroCommandPrivacyViolation(code: code, field: field));
      }
    }

    return AiroCommandPrivacyResult(violations: violations);
  }

  static String _normalizeFieldName(String field) {
    return field.replaceAll(RegExp('[^A-Za-z0-9]'), '').toLowerCase();
  }

  static AiroCommandPrivacyCode? _classifyStringValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroCommandPrivacyCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroCommandPrivacyCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroCommandPrivacyCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroCommandPrivacyCode.credentialLikeValue;
    }

    return null;
  }
}

class AiroCommandPayload extends Equatable {
  AiroCommandPayload.safe(Map<String, String> values)
    : values = Map.unmodifiable(values) {
    final result = AiroCommandPrivacyFilter.standard.validate(values);
    if (!result.accepted) {
      throw ArgumentError.value(
        values.keys.toList(growable: false),
        'values',
        result.violations.map((violation) => violation.code.stableId).join(','),
      );
    }
  }

  const AiroCommandPayload.empty() : values = const {};

  final Map<String, String> values;

  bool get isEmpty => values.isEmpty;

  @override
  String toString() => 'AiroCommandPayload(redactedKeys: ${values.keys})';

  @override
  List<Object?> get props => [values];
}

class AiroCommandEnvelope extends Equatable {
  const AiroCommandEnvelope({
    required this.commandId,
    required this.sessionId,
    required this.senderNodeId,
    required this.targetNodeId,
    required this.kind,
    required this.action,
    required this.requiredScope,
    required this.issuedAt,
    required this.expiresAt,
    required this.idempotencyKey,
    AiroCommandPayload? payload,
    this.expectedRevision,
    this.deliveryPath = AiroCommandDeliveryPath.lan,
    this.schemaVersion = kAiroCommandSchemaVersion,
    this.protocolVersion = kAiroCommandProtocolVersion,
  }) : payload = payload ?? const AiroCommandPayload.empty();

  final String schemaVersion;
  final int protocolVersion;
  final String commandId;
  final String sessionId;
  final String senderNodeId;
  final String targetNodeId;
  final AiroCommandKind kind;
  final AiroCommandAction action;
  final AiroPairingScope requiredScope;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String idempotencyKey;
  final AiroCommandPayload payload;
  final int? expectedRevision;
  final AiroCommandDeliveryPath deliveryPath;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'protocolVersion': protocolVersion,
      'commandId': commandId,
      'sessionId': sessionId,
      'senderNodeId': senderNodeId,
      'targetNodeId': targetNodeId,
      'kind': kind.stableId,
      'action': action.stableId,
      'requiredScope': requiredScope.stableId,
      'issuedAt': issuedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'idempotencyKey': idempotencyKey,
      'expectedRevision': expectedRevision,
      'deliveryPath': deliveryPath.stableId,
      'payloadKeys': payload.values.keys.toList(growable: false),
    };
  }

  @override
  String toString() {
    return 'AiroCommandEnvelope('
        'commandId: $commandId, '
        'sessionId: $sessionId, '
        'senderNodeId: $senderNodeId, '
        'targetNodeId: $targetNodeId, '
        'kind: ${kind.stableId}, '
        'action: ${action.stableId}, '
        'requiredScope: ${requiredScope.stableId}, '
        'expiresAt: $expiresAt, '
        'payload: $payload'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    commandId,
    sessionId,
    senderNodeId,
    targetNodeId,
    kind,
    action,
    requiredScope,
    issuedAt,
    expiresAt,
    idempotencyKey,
    payload,
    expectedRevision,
    deliveryPath,
  ];
}

class AiroCommandValidationPolicy extends Equatable {
  AiroCommandValidationPolicy({
    required Set<AiroPairingScope> grantedScopes,
    this.targetNodeId,
    Set<String> seenIdempotencyKeys = const {},
    this.acceptedSchemaVersion = kAiroCommandSchemaVersion,
    this.minProtocolVersion = kAiroCommandProtocolVersion,
    this.maxProtocolVersion = kAiroCommandProtocolVersion,
  }) : grantedScopes = Set.unmodifiable(grantedScopes),
       seenIdempotencyKeys = Set.unmodifiable(seenIdempotencyKeys);

  final String acceptedSchemaVersion;
  final int minProtocolVersion;
  final int maxProtocolVersion;
  final String? targetNodeId;
  final Set<AiroPairingScope> grantedScopes;
  final Set<String> seenIdempotencyKeys;

  AiroCommandValidationResult evaluate({
    required AiroCommandEnvelope envelope,
    required DateTime now,
  }) {
    final blockers = <AiroCommandValidationBlocker>[];

    if (envelope.schemaVersion != acceptedSchemaVersion) {
      blockers.add(
        const AiroCommandValidationBlocker(
          code: AiroCommandValidationCode.schemaMismatch,
        ),
      );
    }
    if (envelope.protocolVersion < minProtocolVersion) {
      blockers.add(
        const AiroCommandValidationBlocker(
          code: AiroCommandValidationCode.protocolTooOld,
        ),
      );
    }
    if (envelope.protocolVersion > maxProtocolVersion) {
      blockers.add(
        const AiroCommandValidationBlocker(
          code: AiroCommandValidationCode.protocolTooNew,
        ),
      );
    }
    if (envelope.isExpired(now)) {
      blockers.add(
        const AiroCommandValidationBlocker(
          code: AiroCommandValidationCode.expired,
        ),
      );
    }
    if (targetNodeId != null && envelope.targetNodeId != targetNodeId) {
      blockers.add(
        const AiroCommandValidationBlocker(
          code: AiroCommandValidationCode.targetMismatch,
        ),
      );
    }
    if (!grantedScopes.contains(envelope.requiredScope)) {
      blockers.add(
        const AiroCommandValidationBlocker(
          code: AiroCommandValidationCode.scopeMissing,
        ),
      );
    }
    if (seenIdempotencyKeys.contains(envelope.idempotencyKey)) {
      blockers.add(
        const AiroCommandValidationBlocker(
          code: AiroCommandValidationCode.duplicateIdempotencyKey,
        ),
      );
    }
    final privacy = AiroCommandPrivacyFilter.standard.validate(
      envelope.payload.values,
    );
    if (!privacy.accepted) {
      blockers.add(
        const AiroCommandValidationBlocker(
          code: AiroCommandValidationCode.unsafePayload,
        ),
      );
    }

    return AiroCommandValidationResult(blockers: blockers);
  }

  @override
  List<Object?> get props => [
    acceptedSchemaVersion,
    minProtocolVersion,
    maxProtocolVersion,
    targetNodeId,
    grantedScopes,
    seenIdempotencyKeys,
  ];
}

class AiroCommandValidationBlocker extends Equatable {
  const AiroCommandValidationBlocker({required this.code});

  final AiroCommandValidationCode code;

  @override
  List<Object?> get props => [code];
}

class AiroCommandValidationResult extends Equatable {
  AiroCommandValidationResult({
    required List<AiroCommandValidationBlocker> blockers,
  }) : blockers = List.unmodifiable(blockers);

  final List<AiroCommandValidationBlocker> blockers;

  bool get accepted => blockers.isEmpty;

  bool has(AiroCommandValidationCode code) {
    return blockers.any((blocker) => blocker.code == code);
  }

  @override
  List<Object?> get props => [blockers];
}

class AiroCommandResult extends Equatable {
  const AiroCommandResult({
    required this.commandId,
    required this.status,
    required this.completedAt,
    AiroCommandPayload? payload,
    this.code,
    this.schemaVersion = kAiroCommandSchemaVersion,
  }) : payload = payload ?? const AiroCommandPayload.empty();

  final String schemaVersion;
  final String commandId;
  final AiroCommandResultStatus status;
  final String? code;
  final DateTime completedAt;
  final AiroCommandPayload payload;

  @override
  String toString() {
    return 'AiroCommandResult('
        'commandId: $commandId, '
        'status: ${status.stableId}, '
        'code: $code, '
        'completedAt: $completedAt, '
        'payload: $payload'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    commandId,
    status,
    code,
    completedAt,
    payload,
  ];
}

class AiroCommandLifecycleRecord extends Equatable {
  const AiroCommandLifecycleRecord({
    required this.commandId,
    required this.sessionId,
    required this.idempotencyKey,
    required this.senderNodeId,
    required this.targetNodeId,
    required this.action,
    required this.status,
    required this.revision,
    required this.deliveryPath,
    required this.updatedAt,
    this.resultCode,
    this.schemaVersion = kAiroCommandSchemaVersion,
  });

  final String schemaVersion;
  final String commandId;
  final String sessionId;
  final String idempotencyKey;
  final String senderNodeId;
  final String targetNodeId;
  final AiroCommandAction action;
  final AiroCommandResultStatus status;
  final int revision;
  final AiroCommandDeliveryPath deliveryPath;
  final DateTime updatedAt;
  final String? resultCode;

  bool get terminal {
    return switch (status) {
      AiroCommandResultStatus.completed ||
      AiroCommandResultStatus.rejected ||
      AiroCommandResultStatus.expired ||
      AiroCommandResultStatus.duplicate ||
      AiroCommandResultStatus.unsupported ||
      AiroCommandResultStatus.failed ||
      AiroCommandResultStatus.conflict ||
      AiroCommandResultStatus.authRequired ||
      AiroCommandResultStatus.receiverUnavailable => true,
      AiroCommandResultStatus.accepted ||
      AiroCommandResultStatus.inProgress => false,
    };
  }

  AiroCommandResult toResult({DateTime? completedAt}) {
    return AiroCommandResult(
      commandId: commandId,
      status: status,
      code: resultCode,
      completedAt: completedAt ?? updatedAt,
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'commandId': commandId,
      'sessionId': sessionId,
      'idempotencyKey': idempotencyKey,
      'senderNodeId': senderNodeId,
      'targetNodeId': targetNodeId,
      'action': action.stableId,
      'status': status.stableId,
      'revision': revision,
      'deliveryPath': deliveryPath.stableId,
      'updatedAt': updatedAt.toIso8601String(),
      'resultCode': resultCode,
    };
  }

  @override
  String toString() {
    return 'AiroCommandLifecycleRecord('
        'commandId: $commandId, '
        'sessionId: $sessionId, '
        'senderNodeId: $senderNodeId, '
        'targetNodeId: $targetNodeId, '
        'action: ${action.stableId}, '
        'status: ${status.stableId}, '
        'revision: $revision, '
        'deliveryPath: ${deliveryPath.stableId}, '
        'updatedAt: $updatedAt'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    commandId,
    sessionId,
    idempotencyKey,
    senderNodeId,
    targetNodeId,
    action,
    status,
    revision,
    deliveryPath,
    updatedAt,
    resultCode,
  ];
}

class AiroCommandLifecycleDecision extends Equatable {
  AiroCommandLifecycleDecision({
    required this.action,
    required Iterable<AiroCommandLifecycleCode> codes,
    required this.result,
    this.existingRecord,
  }) : codes = List.unmodifiable(codes);

  final AiroCommandLifecycleAction action;
  final List<AiroCommandLifecycleCode> codes;
  final AiroCommandResult result;
  final AiroCommandLifecycleRecord? existingRecord;

  bool get accepted =>
      action == AiroCommandLifecycleAction.execute &&
      codes.length == 1 &&
      codes.single == AiroCommandLifecycleCode.accepted;

  Map<String, Object?> toDiagnosticMap() {
    return {
      'commandId': result.commandId,
      'action': action.stableId,
      'status': result.status.stableId,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
      'existingStatus': existingRecord?.status.stableId,
    };
  }

  @override
  List<Object?> get props => [action, codes, result, existingRecord];
}

class AiroCommandLifecyclePolicy extends Equatable {
  AiroCommandLifecyclePolicy({
    required Set<AiroPairingScope> grantedScopes,
    Set<AiroCommandAction> supportedActions = const {
      AiroCommandAction.play,
      AiroCommandAction.pause,
      AiroCommandAction.stop,
      AiroCommandAction.seek,
      AiroCommandAction.select,
      AiroCommandAction.back,
      AiroCommandAction.home,
      AiroCommandAction.focus,
      AiroCommandAction.submitTextHandle,
      AiroCommandAction.searchHandle,
      AiroCommandAction.askAssistantHandle,
      AiroCommandAction.refreshCapabilities,
      AiroCommandAction.diagnosticsPing,
    },
    this.targetNodeId,
    this.receiverAvailable = true,
  }) : grantedScopes = Set.unmodifiable(grantedScopes),
       supportedActions = Set.unmodifiable(supportedActions);

  final String? targetNodeId;
  final Set<AiroPairingScope> grantedScopes;
  final Set<AiroCommandAction> supportedActions;
  final bool receiverAvailable;

  AiroCommandLifecycleDecision evaluate({
    required AiroCommandEnvelope envelope,
    required DateTime now,
    int? currentRevision,
    Iterable<AiroCommandLifecycleRecord> records = const [],
  }) {
    final codes = <AiroCommandLifecycleCode>[];
    final duplicate = _duplicateFor(envelope, records);

    if (envelope.isExpired(now)) {
      codes.add(AiroCommandLifecycleCode.expired);
    }
    if (targetNodeId != null && envelope.targetNodeId != targetNodeId) {
      codes.add(AiroCommandLifecycleCode.targetMismatch);
    }
    if (!grantedScopes.contains(envelope.requiredScope)) {
      codes.add(AiroCommandLifecycleCode.scopeMissing);
    }
    final privacy = AiroCommandPrivacyFilter.standard.validate(
      envelope.payload.values,
    );
    if (!privacy.accepted) {
      codes.add(AiroCommandLifecycleCode.unsafePayload);
    }
    if (!supportedActions.contains(envelope.action)) {
      codes.add(AiroCommandLifecycleCode.unsupportedAction);
    }
    if (!receiverAvailable) {
      codes.add(AiroCommandLifecycleCode.receiverUnavailable);
    }
    if (duplicate != null) {
      if (duplicate.commandId == envelope.commandId) {
        codes.add(AiroCommandLifecycleCode.duplicateCommandId);
      }
      if (duplicate.idempotencyKey == envelope.idempotencyKey) {
        codes.add(AiroCommandLifecycleCode.duplicateIdempotencyKey);
      }
    }

    final expectedRevision = envelope.expectedRevision;
    if (currentRevision != null && expectedRevision != null) {
      if (expectedRevision < currentRevision) {
        codes.add(AiroCommandLifecycleCode.staleExpectedRevision);
      } else if (expectedRevision == currentRevision && duplicate == null) {
        final conflicting = records.any(
          (record) =>
              record.sessionId == envelope.sessionId &&
              record.revision == expectedRevision &&
              record.senderNodeId != envelope.senderNodeId,
        );
        if (conflicting) {
          codes.add(AiroCommandLifecycleCode.revisionConflict);
        }
      }
    }

    return _decisionFor(
      envelope: envelope,
      now: now,
      codes: codes,
      duplicate: duplicate,
    );
  }

  AiroCommandLifecycleRecord? _duplicateFor(
    AiroCommandEnvelope envelope,
    Iterable<AiroCommandLifecycleRecord> records,
  ) {
    for (final record in records) {
      if (record.commandId == envelope.commandId ||
          record.idempotencyKey == envelope.idempotencyKey) {
        return record;
      }
    }
    return null;
  }

  AiroCommandLifecycleDecision _decisionFor({
    required AiroCommandEnvelope envelope,
    required DateTime now,
    required List<AiroCommandLifecycleCode> codes,
    required AiroCommandLifecycleRecord? duplicate,
  }) {
    if (duplicate != null &&
        codes.every(
          (code) =>
              code == AiroCommandLifecycleCode.duplicateCommandId ||
              code == AiroCommandLifecycleCode.duplicateIdempotencyKey,
        )) {
      return AiroCommandLifecycleDecision(
        action: AiroCommandLifecycleAction.duplicate,
        codes: codes,
        existingRecord: duplicate,
        result: AiroCommandResult(
          commandId: envelope.commandId,
          status: AiroCommandResultStatus.duplicate,
          code: 'duplicate_command',
          completedAt: now,
        ),
      );
    }
    if (codes.isEmpty) {
      return AiroCommandLifecycleDecision(
        action: AiroCommandLifecycleAction.execute,
        codes: const [AiroCommandLifecycleCode.accepted],
        result: AiroCommandResult(
          commandId: envelope.commandId,
          status: AiroCommandResultStatus.accepted,
          completedAt: now,
        ),
      );
    }
    return AiroCommandLifecycleDecision(
      action: AiroCommandLifecycleAction.reject,
      codes: codes,
      existingRecord: duplicate,
      result: AiroCommandResult(
        commandId: envelope.commandId,
        status: _statusFor(codes),
        code: codes.map((code) => code.stableId).join(','),
        completedAt: now,
      ),
    );
  }

  AiroCommandResultStatus _statusFor(List<AiroCommandLifecycleCode> codes) {
    if (codes.contains(AiroCommandLifecycleCode.expired)) {
      return AiroCommandResultStatus.expired;
    }
    if (codes.contains(AiroCommandLifecycleCode.scopeMissing)) {
      return AiroCommandResultStatus.authRequired;
    }
    if (codes.contains(AiroCommandLifecycleCode.revisionConflict)) {
      return AiroCommandResultStatus.conflict;
    }
    if (codes.contains(AiroCommandLifecycleCode.receiverUnavailable)) {
      return AiroCommandResultStatus.receiverUnavailable;
    }
    if (codes.contains(AiroCommandLifecycleCode.unsupportedAction)) {
      return AiroCommandResultStatus.unsupported;
    }
    return AiroCommandResultStatus.rejected;
  }

  @override
  List<Object?> get props => [
    targetNodeId,
    grantedScopes,
    supportedActions,
    receiverAvailable,
  ];
}

abstract interface class AiroCommandLifecycleStore {
  Future<AiroCommandLifecycleDecision> accept({
    required AiroCommandEnvelope envelope,
    required DateTime now,
    int? currentRevision,
  });

  Future<AiroCommandLifecycleRecord?> recordResult({
    required AiroCommandResult result,
    required DateTime now,
  });

  Future<List<AiroCommandLifecycleRecord>> list();
}

class AiroNoOpCommandLifecycleStore implements AiroCommandLifecycleStore {
  const AiroNoOpCommandLifecycleStore();

  @override
  Future<AiroCommandLifecycleDecision> accept({
    required AiroCommandEnvelope envelope,
    required DateTime now,
    int? currentRevision,
  }) async {
    return AiroCommandLifecycleDecision(
      action: AiroCommandLifecycleAction.noOp,
      codes: const [AiroCommandLifecycleCode.storeUnavailable],
      result: AiroCommandResult(
        commandId: envelope.commandId,
        status: AiroCommandResultStatus.receiverUnavailable,
        code: AiroCommandLifecycleCode.storeUnavailable.stableId,
        completedAt: now,
      ),
    );
  }

  @override
  Future<List<AiroCommandLifecycleRecord>> list() async => const [];

  @override
  Future<AiroCommandLifecycleRecord?> recordResult({
    required AiroCommandResult result,
    required DateTime now,
  }) async {
    return null;
  }
}

class AiroFakeCommandLifecycleStore implements AiroCommandLifecycleStore {
  AiroFakeCommandLifecycleStore({required this.policy});

  final AiroCommandLifecyclePolicy policy;
  final List<AiroCommandLifecycleRecord> _records = [];

  @override
  Future<AiroCommandLifecycleDecision> accept({
    required AiroCommandEnvelope envelope,
    required DateTime now,
    int? currentRevision,
  }) async {
    final decision = policy.evaluate(
      envelope: envelope,
      now: now,
      currentRevision: currentRevision,
      records: _records,
    );
    if (decision.accepted) {
      _records.add(
        AiroCommandLifecycleRecord(
          commandId: envelope.commandId,
          sessionId: envelope.sessionId,
          idempotencyKey: envelope.idempotencyKey,
          senderNodeId: envelope.senderNodeId,
          targetNodeId: envelope.targetNodeId,
          action: envelope.action,
          status: AiroCommandResultStatus.accepted,
          revision: envelope.expectedRevision ?? currentRevision ?? 0,
          deliveryPath: envelope.deliveryPath,
          updatedAt: now,
        ),
      );
    }
    return decision;
  }

  @override
  Future<List<AiroCommandLifecycleRecord>> list() async {
    return List.unmodifiable(_records);
  }

  @override
  Future<AiroCommandLifecycleRecord?> recordResult({
    required AiroCommandResult result,
    required DateTime now,
  }) async {
    final index = _records.indexWhere(
      (record) => record.commandId == result.commandId,
    );
    if (index < 0) return null;
    final current = _records[index];
    final updated = AiroCommandLifecycleRecord(
      commandId: current.commandId,
      sessionId: current.sessionId,
      idempotencyKey: current.idempotencyKey,
      senderNodeId: current.senderNodeId,
      targetNodeId: current.targetNodeId,
      action: current.action,
      status: result.status,
      revision: current.revision,
      deliveryPath: current.deliveryPath,
      updatedAt: now,
      resultCode: result.code,
    );
    _records[index] = updated;
    return updated;
  }
}

abstract class AiroCommandDispatcher {
  Future<AiroCommandResult> dispatch(AiroCommandEnvelope envelope);
}

class AiroNoOpCommandDispatcher implements AiroCommandDispatcher {
  const AiroNoOpCommandDispatcher();

  @override
  Future<AiroCommandResult> dispatch(AiroCommandEnvelope envelope) async {
    return AiroCommandResult(
      commandId: envelope.commandId,
      status: AiroCommandResultStatus.unsupported,
      code: 'dispatcher_unavailable',
      completedAt: DateTime.now().toUtc(),
    );
  }
}

class AiroFakeCommandDispatcher implements AiroCommandDispatcher {
  AiroFakeCommandDispatcher({
    Map<String, AiroCommandResult> cannedResults = const {},
  }) : cannedResults = Map.unmodifiable(cannedResults);

  final Map<String, AiroCommandResult> cannedResults;
  final List<AiroCommandEnvelope> _dispatched = [];

  List<AiroCommandEnvelope> get dispatched => List.unmodifiable(_dispatched);

  @override
  Future<AiroCommandResult> dispatch(AiroCommandEnvelope envelope) async {
    _dispatched.add(envelope);
    return cannedResults[envelope.commandId] ??
        AiroCommandResult(
          commandId: envelope.commandId,
          status: AiroCommandResultStatus.accepted,
          completedAt: DateTime.now().toUtc(),
        );
  }
}
