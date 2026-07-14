import 'package:equatable/equatable.dart';

import 'compact_epg_models.dart';

const String kDistributedEpgWorkerSchemaVersion = '1.0.0';
const int kDistributedEpgWorkerProtocolVersion = 1;
const int kDistributedEpgDefaultMaxSnapshotBytes = 256 * 1024;
const int kDistributedEpgDefaultMaxChannelCount = 250;
const int kDistributedEpgDefaultMaxEntryCount = 500;
const Duration kDistributedEpgDefaultMaxWindow = Duration(hours: 24);
const Duration kDistributedEpgDefaultMaxSnapshotAge = Duration(minutes: 15);

enum DistributedEpgWorkerRole {
  downloader('downloader'),
  parser('parser'),
  normalizer('normalizer'),
  compactor('compactor'),
  cacheHost('cache_host'),
  consumer('consumer');

  const DistributedEpgWorkerRole(this.stableId);

  final String stableId;
}

enum DistributedEpgTaskKind {
  compactSnapshot('compact_snapshot'),
  incrementalPatch('incremental_patch'),
  cacheWarmup('cache_warmup'),
  cachePrune('cache_prune');

  const DistributedEpgTaskKind(this.stableId);

  final String stableId;
}

enum DistributedEpgPayloadFormat {
  compactJson('compact_json'),
  protobufEnvelope('protobuf_envelope'),
  binaryDelta('binary_delta');

  const DistributedEpgPayloadFormat(this.stableId);

  final String stableId;
}

enum DistributedEpgTransferMode {
  fullSnapshot('full_snapshot'),
  incrementalPatch('incremental_patch'),
  currentNextOnly('current_next_only');

  const DistributedEpgTransferMode(this.stableId);

  final String stableId;
}

enum DistributedEpgWorkerEventState {
  queued('queued'),
  running('running'),
  snapshotReady('snapshot_ready'),
  cancelled('cancelled'),
  failed('failed');

  const DistributedEpgWorkerEventState(this.stableId);

  final String stableId;
}

enum DistributedEpgWorkerBlockerCode {
  accepted('accepted'),
  schemaMismatch('schema_mismatch'),
  protocolTooOld('protocol_too_old'),
  protocolTooNew('protocol_too_new'),
  missingRequiredRole('missing_required_role'),
  unsupportedTask('unsupported_task'),
  unsupportedFormat('unsupported_format'),
  unsupportedTransferMode('unsupported_transfer_mode'),
  invalidWindow('invalid_window'),
  windowTooLarge('window_too_large'),
  tooManyChannels('too_many_channels'),
  tooManyEntries('too_many_entries'),
  snapshotTooLarge('snapshot_too_large'),
  staleSnapshot('stale_snapshot'),
  expiredSnapshot('expired_snapshot'),
  futureSnapshot('future_snapshot'),
  windowNotCovered('window_not_covered'),
  unsafeStableId('unsafe_stable_id'),
  cacheBudgetExceeded('cache_budget_exceeded'),
  workerUnavailable('worker_unavailable'),
  cancelled('cancelled');

  const DistributedEpgWorkerBlockerCode(this.stableId);

  final String stableId;
}

enum DistributedEpgStableValueRejectionCode {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value'),
  invalidStableId('invalid_stable_id');

  const DistributedEpgStableValueRejectionCode(this.stableId);

  final String stableId;
}

class DistributedEpgStableValue extends Equatable {
  const DistributedEpgStableValue._(this.value);

  factory DistributedEpgStableValue.stable(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return DistributedEpgStableValue._(value.trim());
  }

  final String value;

  static DistributedEpgStableValueRejectionCode? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return DistributedEpgStableValueRejectionCode.empty;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return DistributedEpgStableValueRejectionCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return DistributedEpgStableValueRejectionCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return DistributedEpgStableValueRejectionCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return DistributedEpgStableValueRejectionCode.credentialLikeValue;
    }
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_.-]*$').hasMatch(trimmed)) {
      return DistributedEpgStableValueRejectionCode.invalidStableId;
    }
    return null;
  }

  @override
  String toString() => 'DistributedEpgStableValue(redacted)';

  @override
  List<Object?> get props => [value];
}

class DistributedEpgWorkerCapability extends Equatable {
  DistributedEpgWorkerCapability({
    required this.workerId,
    required Set<DistributedEpgWorkerRole> roles,
    required Set<DistributedEpgTaskKind> supportedTasks,
    required Set<DistributedEpgPayloadFormat> supportedFormats,
    required Set<DistributedEpgTransferMode> supportedTransferModes,
    this.maxWindow = kDistributedEpgDefaultMaxWindow,
    this.maxChannelCount = kDistributedEpgDefaultMaxChannelCount,
    this.maxEntryCount = kDistributedEpgDefaultMaxEntryCount,
    this.maxSnapshotBytes = kDistributedEpgDefaultMaxSnapshotBytes,
    this.cacheBudgetBytes = kDistributedEpgDefaultMaxSnapshotBytes,
    this.schemaVersion = kDistributedEpgWorkerSchemaVersion,
    this.protocolVersion = kDistributedEpgWorkerProtocolVersion,
  }) : roles = Set.unmodifiable(roles),
       supportedTasks = Set.unmodifiable(supportedTasks),
       supportedFormats = Set.unmodifiable(supportedFormats),
       supportedTransferModes = Set.unmodifiable(supportedTransferModes);

  final String schemaVersion;
  final int protocolVersion;
  final DistributedEpgStableValue workerId;
  final Set<DistributedEpgWorkerRole> roles;
  final Set<DistributedEpgTaskKind> supportedTasks;
  final Set<DistributedEpgPayloadFormat> supportedFormats;
  final Set<DistributedEpgTransferMode> supportedTransferModes;
  final Duration maxWindow;
  final int maxChannelCount;
  final int maxEntryCount;
  final int maxSnapshotBytes;
  final int cacheBudgetBytes;

  bool supportsRequest(DistributedEpgSyncRequest request) {
    return supportedTasks.contains(request.taskKind) &&
        supportedFormats.contains(request.payloadFormat) &&
        supportedTransferModes.contains(request.transferMode);
  }

  @override
  String toString() {
    return 'DistributedEpgWorkerCapability('
        'workerId: ${workerId.value}, '
        'roles: ${roles.map((role) => role.stableId).join(',')}, '
        'tasks: ${supportedTasks.map((task) => task.stableId).join(',')}, '
        'formats: ${supportedFormats.map((format) => format.stableId).join(',')}, '
        'transferModes: ${supportedTransferModes.map((mode) => mode.stableId).join(',')}'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    workerId,
    roles,
    supportedTasks,
    supportedFormats,
    supportedTransferModes,
    maxWindow,
    maxChannelCount,
    maxEntryCount,
    maxSnapshotBytes,
    cacheBudgetBytes,
  ];
}

class DistributedEpgSyncRequest extends Equatable {
  DistributedEpgSyncRequest({
    required this.requestId,
    required this.sourceRef,
    required this.requestedAt,
    required this.windowStart,
    required this.windowEnd,
    required Iterable<String> channelIds,
    required this.taskKind,
    required this.payloadFormat,
    required this.transferMode,
    this.schemaVersion = kDistributedEpgWorkerSchemaVersion,
    this.protocolVersion = kDistributedEpgWorkerProtocolVersion,
  }) : channelIds = List.unmodifiable(channelIds);

  final String schemaVersion;
  final int protocolVersion;
  final DistributedEpgStableValue requestId;
  final CompactEpgSourceRef sourceRef;
  final DateTime requestedAt;
  final DateTime windowStart;
  final DateTime windowEnd;
  final List<String> channelIds;
  final DistributedEpgTaskKind taskKind;
  final DistributedEpgPayloadFormat payloadFormat;
  final DistributedEpgTransferMode transferMode;

  Duration get window => windowEnd.difference(windowStart);

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    requestId,
    sourceRef,
    requestedAt,
    windowStart,
    windowEnd,
    channelIds,
    taskKind,
    payloadFormat,
    transferMode,
  ];
}

class DistributedEpgSnapshotManifest extends Equatable {
  const DistributedEpgSnapshotManifest({
    required this.snapshotId,
    required this.sourceRef,
    required this.generatedAt,
    required this.expiresAt,
    required this.windowStart,
    required this.windowEnd,
    required this.channelCount,
    required this.entryCount,
    required this.payloadBytes,
    required this.payloadFormat,
    required this.transferMode,
    required this.sequence,
    this.incremental = false,
    this.schemaVersion = kDistributedEpgWorkerSchemaVersion,
    this.protocolVersion = kDistributedEpgWorkerProtocolVersion,
  });

  final String schemaVersion;
  final int protocolVersion;
  final DistributedEpgStableValue snapshotId;
  final CompactEpgSourceRef sourceRef;
  final DateTime generatedAt;
  final DateTime expiresAt;
  final DateTime windowStart;
  final DateTime windowEnd;
  final int channelCount;
  final int entryCount;
  final int payloadBytes;
  final DistributedEpgPayloadFormat payloadFormat;
  final DistributedEpgTransferMode transferMode;
  final int sequence;
  final bool incremental;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  bool coversWindow(DateTime start, DateTime end) {
    return !windowStart.isAfter(start) && !windowEnd.isBefore(end);
  }

  Map<String, Object?> toDiagnosticMap() {
    return {
      'snapshotId': snapshotId.value,
      'generatedAt': generatedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'windowStart': windowStart.toIso8601String(),
      'windowEnd': windowEnd.toIso8601String(),
      'channelCount': channelCount,
      'entryCount': entryCount,
      'payloadBytes': payloadBytes,
      'payloadFormat': payloadFormat.stableId,
      'transferMode': transferMode.stableId,
      'sequence': sequence,
      'incremental': incremental,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    snapshotId,
    sourceRef,
    generatedAt,
    expiresAt,
    windowStart,
    windowEnd,
    channelCount,
    entryCount,
    payloadBytes,
    payloadFormat,
    transferMode,
    sequence,
    incremental,
  ];
}

class DistributedEpgWorkerValidationResult extends Equatable {
  DistributedEpgWorkerValidationResult({
    required this.workerId,
    required Iterable<DistributedEpgWorkerBlockerCode> codes,
    this.requestId,
    this.snapshotId,
  }) : codes = List.unmodifiable(codes);

  final DistributedEpgStableValue workerId;
  final DistributedEpgStableValue? requestId;
  final DistributedEpgStableValue? snapshotId;
  final List<DistributedEpgWorkerBlockerCode> codes;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == DistributedEpgWorkerBlockerCode.accepted;

  Map<String, Object?> toDiagnosticMap() {
    return {
      'workerId': workerId.value,
      'requestId': requestId?.value,
      'snapshotId': snapshotId?.value,
      'accepted': accepted,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [workerId, requestId, snapshotId, codes];
}

class DistributedEpgWorkerPolicy extends Equatable {
  DistributedEpgWorkerPolicy({
    Set<DistributedEpgWorkerRole> requiredRoles = const {
      DistributedEpgWorkerRole.compactor,
      DistributedEpgWorkerRole.cacheHost,
    },
    this.acceptedSchemaVersion = kDistributedEpgWorkerSchemaVersion,
    this.minProtocolVersion = kDistributedEpgWorkerProtocolVersion,
    this.maxProtocolVersion = kDistributedEpgWorkerProtocolVersion,
    this.maxSnapshotAge = kDistributedEpgDefaultMaxSnapshotAge,
  }) : requiredRoles = Set.unmodifiable(requiredRoles);

  final String acceptedSchemaVersion;
  final int minProtocolVersion;
  final int maxProtocolVersion;
  final Duration maxSnapshotAge;
  final Set<DistributedEpgWorkerRole> requiredRoles;

  DistributedEpgWorkerValidationResult validateRequest({
    required DistributedEpgWorkerCapability capability,
    required DistributedEpgSyncRequest request,
  }) {
    final codes = <DistributedEpgWorkerBlockerCode>[];
    _addVersionCodes(
      schemaVersion: capability.schemaVersion,
      protocolVersion: capability.protocolVersion,
      codes: codes,
    );
    _addVersionCodes(
      schemaVersion: request.schemaVersion,
      protocolVersion: request.protocolVersion,
      codes: codes,
    );

    if (!capability.roles.containsAll(requiredRoles)) {
      codes.add(DistributedEpgWorkerBlockerCode.missingRequiredRole);
    }
    if (!capability.supportedTasks.contains(request.taskKind)) {
      codes.add(DistributedEpgWorkerBlockerCode.unsupportedTask);
    }
    if (!capability.supportedFormats.contains(request.payloadFormat)) {
      codes.add(DistributedEpgWorkerBlockerCode.unsupportedFormat);
    }
    if (!capability.supportedTransferModes.contains(request.transferMode)) {
      codes.add(DistributedEpgWorkerBlockerCode.unsupportedTransferMode);
    }
    if (!request.windowEnd.isAfter(request.windowStart)) {
      codes.add(DistributedEpgWorkerBlockerCode.invalidWindow);
    }
    if (request.window > capability.maxWindow) {
      codes.add(DistributedEpgWorkerBlockerCode.windowTooLarge);
    }
    if (request.channelIds.length > capability.maxChannelCount) {
      codes.add(DistributedEpgWorkerBlockerCode.tooManyChannels);
    }
    if (DistributedEpgStableValue.validate(request.sourceRef.value) != null) {
      codes.add(DistributedEpgWorkerBlockerCode.unsafeStableId);
    }

    return DistributedEpgWorkerValidationResult(
      workerId: capability.workerId,
      requestId: request.requestId,
      codes: codes.isEmpty
          ? const [DistributedEpgWorkerBlockerCode.accepted]
          : codes,
    );
  }

  DistributedEpgWorkerValidationResult validateSnapshot({
    required DistributedEpgWorkerCapability capability,
    required DistributedEpgSyncRequest request,
    required DistributedEpgSnapshotManifest manifest,
    required DateTime now,
  }) {
    final codes = <DistributedEpgWorkerBlockerCode>[];
    _addVersionCodes(
      schemaVersion: manifest.schemaVersion,
      protocolVersion: manifest.protocolVersion,
      codes: codes,
    );

    if (manifest.payloadFormat != request.payloadFormat) {
      codes.add(DistributedEpgWorkerBlockerCode.unsupportedFormat);
    }
    if (manifest.transferMode != request.transferMode) {
      codes.add(DistributedEpgWorkerBlockerCode.unsupportedTransferMode);
    }
    if (manifest.channelCount > capability.maxChannelCount) {
      codes.add(DistributedEpgWorkerBlockerCode.tooManyChannels);
    }
    if (manifest.entryCount > capability.maxEntryCount) {
      codes.add(DistributedEpgWorkerBlockerCode.tooManyEntries);
    }
    if (manifest.payloadBytes > capability.maxSnapshotBytes) {
      codes.add(DistributedEpgWorkerBlockerCode.snapshotTooLarge);
    }
    if (manifest.payloadBytes > capability.cacheBudgetBytes) {
      codes.add(DistributedEpgWorkerBlockerCode.cacheBudgetExceeded);
    }
    if (manifest.generatedAt.isAfter(now)) {
      codes.add(DistributedEpgWorkerBlockerCode.futureSnapshot);
    }
    if (manifest.generatedAt.isBefore(now.subtract(maxSnapshotAge))) {
      codes.add(DistributedEpgWorkerBlockerCode.staleSnapshot);
    }
    if (manifest.isExpired(now)) {
      codes.add(DistributedEpgWorkerBlockerCode.expiredSnapshot);
    }
    if (!manifest.coversWindow(request.windowStart, request.windowEnd)) {
      codes.add(DistributedEpgWorkerBlockerCode.windowNotCovered);
    }
    if (manifest.sequence <= 0 ||
        !manifest.windowEnd.isAfter(manifest.windowStart)) {
      codes.add(DistributedEpgWorkerBlockerCode.invalidWindow);
    }

    return DistributedEpgWorkerValidationResult(
      workerId: capability.workerId,
      requestId: request.requestId,
      snapshotId: manifest.snapshotId,
      codes: codes.isEmpty
          ? const [DistributedEpgWorkerBlockerCode.accepted]
          : codes,
    );
  }

  void _addVersionCodes({
    required String schemaVersion,
    required int protocolVersion,
    required List<DistributedEpgWorkerBlockerCode> codes,
  }) {
    if (schemaVersion != acceptedSchemaVersion) {
      codes.add(DistributedEpgWorkerBlockerCode.schemaMismatch);
    }
    if (protocolVersion < minProtocolVersion) {
      codes.add(DistributedEpgWorkerBlockerCode.protocolTooOld);
    }
    if (protocolVersion > maxProtocolVersion) {
      codes.add(DistributedEpgWorkerBlockerCode.protocolTooNew);
    }
  }

  @override
  List<Object?> get props => [
    acceptedSchemaVersion,
    minProtocolVersion,
    maxProtocolVersion,
    maxSnapshotAge,
    requiredRoles,
  ];
}

class DistributedEpgWorkerEvent extends Equatable {
  const DistributedEpgWorkerEvent({
    required this.requestId,
    required this.state,
    this.progressPercent = 0,
    this.manifest,
    this.validation,
  });

  final DistributedEpgStableValue requestId;
  final DistributedEpgWorkerEventState state;
  final int progressPercent;
  final DistributedEpgSnapshotManifest? manifest;
  final DistributedEpgWorkerValidationResult? validation;

  @override
  List<Object?> get props => [
    requestId,
    state,
    progressPercent,
    manifest,
    validation,
  ];
}

abstract interface class DistributedEpgWorker {
  Stream<DistributedEpgWorkerEvent> run(DistributedEpgSyncRequest request);

  Future<void> cancel(DistributedEpgStableValue requestId);
}

class NoOpDistributedEpgWorker implements DistributedEpgWorker {
  const NoOpDistributedEpgWorker(this.capability);

  final DistributedEpgWorkerCapability capability;

  @override
  Stream<DistributedEpgWorkerEvent> run(
    DistributedEpgSyncRequest request,
  ) async* {
    yield DistributedEpgWorkerEvent(
      requestId: request.requestId,
      state: DistributedEpgWorkerEventState.failed,
      validation: DistributedEpgWorkerValidationResult(
        workerId: capability.workerId,
        requestId: request.requestId,
        codes: const [DistributedEpgWorkerBlockerCode.workerUnavailable],
      ),
    );
  }

  @override
  Future<void> cancel(DistributedEpgStableValue requestId) async {}
}

class FakeDistributedEpgWorker implements DistributedEpgWorker {
  FakeDistributedEpgWorker({
    required this.capability,
    required this.policy,
    Map<DistributedEpgStableValue, DistributedEpgSnapshotManifest> snapshots =
        const {},
  }) : _snapshots = Map.unmodifiable(snapshots);

  final DistributedEpgWorkerCapability capability;
  final DistributedEpgWorkerPolicy policy;
  final Map<DistributedEpgStableValue, DistributedEpgSnapshotManifest>
  _snapshots;
  final Set<DistributedEpgStableValue> _cancelled = {};

  @override
  Stream<DistributedEpgWorkerEvent> run(
    DistributedEpgSyncRequest request,
  ) async* {
    final requestValidation = policy.validateRequest(
      capability: capability,
      request: request,
    );
    yield DistributedEpgWorkerEvent(
      requestId: request.requestId,
      state: DistributedEpgWorkerEventState.queued,
      validation: requestValidation,
    );
    if (!requestValidation.accepted) {
      yield DistributedEpgWorkerEvent(
        requestId: request.requestId,
        state: DistributedEpgWorkerEventState.failed,
        validation: requestValidation,
      );
      return;
    }
    if (_cancelled.contains(request.requestId)) {
      yield DistributedEpgWorkerEvent(
        requestId: request.requestId,
        state: DistributedEpgWorkerEventState.cancelled,
        validation: DistributedEpgWorkerValidationResult(
          workerId: capability.workerId,
          requestId: request.requestId,
          codes: const [DistributedEpgWorkerBlockerCode.cancelled],
        ),
      );
      return;
    }

    yield DistributedEpgWorkerEvent(
      requestId: request.requestId,
      state: DistributedEpgWorkerEventState.running,
      progressPercent: 50,
    );

    final manifest =
        _snapshots[request.requestId] ?? _defaultManifestFor(request);
    final snapshotValidation = policy.validateSnapshot(
      capability: capability,
      request: request,
      manifest: manifest,
      now: manifest.generatedAt,
    );
    yield DistributedEpgWorkerEvent(
      requestId: request.requestId,
      state: snapshotValidation.accepted
          ? DistributedEpgWorkerEventState.snapshotReady
          : DistributedEpgWorkerEventState.failed,
      progressPercent: snapshotValidation.accepted ? 100 : 50,
      manifest: snapshotValidation.accepted ? manifest : null,
      validation: snapshotValidation,
    );
  }

  @override
  Future<void> cancel(DistributedEpgStableValue requestId) async {
    _cancelled.add(requestId);
  }

  DistributedEpgSnapshotManifest _defaultManifestFor(
    DistributedEpgSyncRequest request,
  ) {
    return DistributedEpgSnapshotManifest(
      snapshotId: DistributedEpgStableValue.stable(
        '${request.requestId.value}-snapshot',
      ),
      sourceRef: request.sourceRef,
      generatedAt: request.requestedAt,
      expiresAt: request.requestedAt.add(const Duration(minutes: 10)),
      windowStart: request.windowStart,
      windowEnd: request.windowEnd,
      channelCount: request.channelIds.length,
      entryCount: request.channelIds.length * 2,
      payloadBytes: request.channelIds.length * 128,
      payloadFormat: request.payloadFormat,
      transferMode: request.transferMode,
      sequence: 1,
      incremental:
          request.transferMode == DistributedEpgTransferMode.incrementalPatch,
    );
  }
}
