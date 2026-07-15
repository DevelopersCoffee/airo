import 'package:core_sessions/core_sessions.dart';
import 'package:equatable/equatable.dart';

const String kAiroWatchProgressSchemaVersion = '1.0.0';

enum AiroWatchProgressSyncMode {
  disabled('disabled'),
  localOnly('local_only'),
  cloudOptIn('cloud_opt_in'),
  cloudEnabled('cloud_enabled');

  const AiroWatchProgressSyncMode(this.stableId);

  final String stableId;
}

enum AiroWatchProgressSyncTarget {
  local('local'),
  cloud('cloud');

  const AiroWatchProgressSyncTarget(this.stableId);

  final String stableId;
}

enum AiroWatchProgressStatus {
  inProgress('in_progress'),
  completed('completed'),
  abandoned('abandoned'),
  hidden('hidden');

  const AiroWatchProgressStatus(this.stableId);

  final String stableId;
}

enum AiroWatchProgressDecisionAction {
  accept('accept'),
  ignoreStale('ignore_stale'),
  conflict('conflict'),
  deny('deny'),
  delete('delete'),
  noOp('no_op');

  const AiroWatchProgressDecisionAction(this.stableId);

  final String stableId;
}

enum AiroWatchProgressCode {
  accepted('accepted'),
  syncDisabled('sync_disabled'),
  localOnlyCloudBlocked('local_only_cloud_blocked'),
  cloudOptInRequired('cloud_opt_in_required'),
  unsafeStableId('unsafe_stable_id'),
  invalidDuration('invalid_duration'),
  invalidPosition('invalid_position'),
  invalidCompletion('invalid_completion'),
  expiredRecord('expired_record'),
  retentionExceeded('retention_exceeded'),
  profileMismatch('profile_mismatch'),
  mediaMismatch('media_mismatch'),
  sourceMismatch('source_mismatch'),
  staleRevision('stale_revision'),
  revisionConflict('revision_conflict'),
  deleteTombstone('delete_tombstone'),
  repositoryUnavailable('repository_unavailable');

  const AiroWatchProgressCode(this.stableId);

  final String stableId;
}

enum AiroWatchProgressStableIdRejection {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value');

  const AiroWatchProgressStableIdRejection(this.stableId);

  final String stableId;
}

class AiroWatchProgressStableIdPolicy {
  const AiroWatchProgressStableIdPolicy();

  AiroWatchProgressStableIdRejection? rejectionFor(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return AiroWatchProgressStableIdRejection.empty;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroWatchProgressStableIdRejection.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroWatchProgressStableIdRejection.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroWatchProgressStableIdRejection.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroWatchProgressStableIdRejection.credentialLikeValue;
    }
    return null;
  }

  bool isSafe(String value) => rejectionFor(value) == null;
}

class AiroWatchProgressKey extends Equatable {
  const AiroWatchProgressKey({
    required this.profileId,
    required this.mediaId,
    required this.sourceId,
    required this.resolverId,
    this.schemaVersion = kAiroWatchProgressSchemaVersion,
  });

  final String schemaVersion;
  final String profileId;
  final String mediaId;
  final String sourceId;
  final String resolverId;

  String get stableKey => '$profileId::$mediaId::$sourceId::$resolverId';

  Iterable<String> stableIds() => [profileId, mediaId, sourceId, resolverId];

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'profileId': profileId,
      'mediaId': mediaId,
      'sourceId': sourceId,
      'resolverId': resolverId,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    profileId,
    mediaId,
    sourceId,
    resolverId,
  ];
}

class AiroWatchProgressRecord extends Equatable {
  const AiroWatchProgressRecord({
    required this.progressId,
    required this.key,
    required this.position,
    required this.duration,
    required this.status,
    required this.revision,
    required this.updatedByNodeId,
    required this.updatedByDeviceId,
    required this.updatedAt,
    required this.retentionExpiresAt,
    this.cloudEligible = false,
    this.deletedAt,
    this.schemaVersion = kAiroWatchProgressSchemaVersion,
  });

  final String schemaVersion;
  final String progressId;
  final AiroWatchProgressKey key;
  final Duration position;
  final Duration duration;
  final AiroWatchProgressStatus status;
  final AiroSessionRevision revision;
  final String updatedByNodeId;
  final String updatedByDeviceId;
  final DateTime updatedAt;
  final DateTime retentionExpiresAt;
  final bool cloudEligible;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  bool isExpired(DateTime now) => !now.isBefore(retentionExpiresAt);

  double get completionRatio {
    if (duration.inMilliseconds <= 0) return 0;
    final ratio = position.inMilliseconds / duration.inMilliseconds;
    return ratio.clamp(0, 1).toDouble();
  }

  int get completionPercent => (completionRatio * 100).round();

  AiroWatchProgressRecord tombstone({
    required AiroSessionRevision revision,
    required DateTime deletedAt,
    required DateTime retentionExpiresAt,
  }) {
    return AiroWatchProgressRecord(
      progressId: progressId,
      key: key,
      position: position,
      duration: duration,
      status: AiroWatchProgressStatus.hidden,
      revision: revision,
      updatedByNodeId: revision.reporterNodeId,
      updatedByDeviceId: updatedByDeviceId,
      updatedAt: deletedAt,
      retentionExpiresAt: retentionExpiresAt,
      cloudEligible: cloudEligible,
      deletedAt: deletedAt,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'progressId': progressId,
      'key': key.toPublicMap(),
      'positionMs': position.inMilliseconds,
      'durationMs': duration.inMilliseconds,
      'completionPercent': completionPercent,
      'status': status.stableId,
      'revision': revision.value,
      'revisionReporterNodeId': revision.reporterNodeId,
      'updatedByNodeId': updatedByNodeId,
      'updatedByDeviceId': updatedByDeviceId,
      'updatedAt': updatedAt.toIso8601String(),
      'retentionExpiresAt': retentionExpiresAt.toIso8601String(),
      'cloudEligible': cloudEligible,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'AiroWatchProgressRecord('
        'progressId: $progressId, '
        'profileId: ${key.profileId}, '
        'mediaId: ${key.mediaId}, '
        'sourceId: ${key.sourceId}, '
        'status: ${status.stableId}, '
        'revision: ${revision.value}, '
        'completionPercent: $completionPercent, '
        'deleted: $isDeleted'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    progressId,
    key,
    position,
    duration,
    status,
    revision,
    updatedByNodeId,
    updatedByDeviceId,
    updatedAt,
    retentionExpiresAt,
    cloudEligible,
    deletedAt,
  ];
}

class AiroWatchProgressDecision extends Equatable {
  AiroWatchProgressDecision({
    required this.action,
    required Iterable<AiroWatchProgressCode> codes,
    required this.record,
    this.current,
    this.schemaVersion = kAiroWatchProgressSchemaVersion,
  }) : codes = List.unmodifiable(codes);

  final String schemaVersion;
  final AiroWatchProgressDecisionAction action;
  final List<AiroWatchProgressCode> codes;
  final AiroWatchProgressRecord record;
  final AiroWatchProgressRecord? current;

  bool get accepted =>
      action == AiroWatchProgressDecisionAction.accept &&
      codes.length == 1 &&
      codes.single == AiroWatchProgressCode.accepted;

  bool has(AiroWatchProgressCode code) => codes.contains(code);

  Map<String, Object?> toDiagnosticMap() {
    return {
      'schemaVersion': schemaVersion,
      'action': action.stableId,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
      'progressId': record.progressId,
      'revision': record.revision.value,
      'currentRevision': current?.revision.value,
      'profileId': record.key.profileId,
      'mediaId': record.key.mediaId,
      'sourceId': record.key.sourceId,
    };
  }

  @override
  List<Object?> get props => [schemaVersion, action, codes, record, current];
}

class AiroWatchProgressPolicy extends Equatable {
  const AiroWatchProgressPolicy({
    required this.syncMode,
    this.retentionWindow = const Duration(days: 90),
    this.completionThreshold = 0.9,
    this.stableIdPolicy = const AiroWatchProgressStableIdPolicy(),
  });

  final AiroWatchProgressSyncMode syncMode;
  final Duration retentionWindow;
  final double completionThreshold;
  final AiroWatchProgressStableIdPolicy stableIdPolicy;

  AiroWatchProgressDecision evaluate({
    required AiroWatchProgressRecord incoming,
    required DateTime now,
    AiroWatchProgressRecord? current,
    AiroWatchProgressSyncTarget target = AiroWatchProgressSyncTarget.local,
  }) {
    final codes = <AiroWatchProgressCode>[];
    _evaluateMode(codes, incoming, target);
    _evaluateShape(codes, incoming, now);
    _evaluateCurrent(codes, incoming, current);

    if (incoming.isDeleted && codes.isEmpty) {
      return AiroWatchProgressDecision(
        action: AiroWatchProgressDecisionAction.delete,
        codes: const [AiroWatchProgressCode.deleteTombstone],
        record: incoming,
        current: current,
      );
    }
    if (codes.isEmpty) {
      return AiroWatchProgressDecision(
        action: AiroWatchProgressDecisionAction.accept,
        codes: const [AiroWatchProgressCode.accepted],
        record: incoming,
        current: current,
      );
    }
    if (codes.length == 1 &&
        codes.single == AiroWatchProgressCode.staleRevision) {
      return AiroWatchProgressDecision(
        action: AiroWatchProgressDecisionAction.ignoreStale,
        codes: codes,
        record: incoming,
        current: current,
      );
    }
    if (codes.length == 1 &&
        codes.single == AiroWatchProgressCode.revisionConflict) {
      return AiroWatchProgressDecision(
        action: AiroWatchProgressDecisionAction.conflict,
        codes: codes,
        record: incoming,
        current: current,
      );
    }
    return AiroWatchProgressDecision(
      action: AiroWatchProgressDecisionAction.deny,
      codes: codes,
      record: incoming,
      current: current,
    );
  }

  void _evaluateMode(
    List<AiroWatchProgressCode> codes,
    AiroWatchProgressRecord incoming,
    AiroWatchProgressSyncTarget target,
  ) {
    if (syncMode == AiroWatchProgressSyncMode.disabled) {
      codes.add(AiroWatchProgressCode.syncDisabled);
    }
    if (target == AiroWatchProgressSyncTarget.cloud) {
      if (syncMode == AiroWatchProgressSyncMode.localOnly) {
        codes.add(AiroWatchProgressCode.localOnlyCloudBlocked);
      }
      if (syncMode == AiroWatchProgressSyncMode.cloudOptIn &&
          !incoming.cloudEligible) {
        codes.add(AiroWatchProgressCode.cloudOptInRequired);
      }
    }
  }

  void _evaluateShape(
    List<AiroWatchProgressCode> codes,
    AiroWatchProgressRecord incoming,
    DateTime now,
  ) {
    if (incoming.key.stableIds().any(
          (value) => !stableIdPolicy.isSafe(value),
        ) ||
        !stableIdPolicy.isSafe(incoming.progressId) ||
        !stableIdPolicy.isSafe(incoming.updatedByNodeId) ||
        !stableIdPolicy.isSafe(incoming.updatedByDeviceId)) {
      codes.add(AiroWatchProgressCode.unsafeStableId);
    }
    if (incoming.duration <= Duration.zero) {
      codes.add(AiroWatchProgressCode.invalidDuration);
    }
    if (incoming.position < Duration.zero ||
        incoming.position > incoming.duration) {
      codes.add(AiroWatchProgressCode.invalidPosition);
    }
    if (incoming.status == AiroWatchProgressStatus.completed &&
        incoming.completionRatio < completionThreshold) {
      codes.add(AiroWatchProgressCode.invalidCompletion);
    }
    if (incoming.isExpired(now)) {
      codes.add(AiroWatchProgressCode.expiredRecord);
    }
    if (now.difference(incoming.updatedAt) > retentionWindow) {
      codes.add(AiroWatchProgressCode.retentionExceeded);
    }
  }

  void _evaluateCurrent(
    List<AiroWatchProgressCode> codes,
    AiroWatchProgressRecord incoming,
    AiroWatchProgressRecord? current,
  ) {
    if (current == null) return;
    if (incoming.key.profileId != current.key.profileId) {
      codes.add(AiroWatchProgressCode.profileMismatch);
    }
    if (incoming.key.mediaId != current.key.mediaId) {
      codes.add(AiroWatchProgressCode.mediaMismatch);
    }
    if (incoming.key.sourceId != current.key.sourceId ||
        incoming.key.resolverId != current.key.resolverId) {
      codes.add(AiroWatchProgressCode.sourceMismatch);
    }
    if (incoming.revision.conflictsWith(current.revision)) {
      codes.add(AiroWatchProgressCode.revisionConflict);
    } else if (current.revision.isNewerThan(incoming.revision)) {
      codes.add(AiroWatchProgressCode.staleRevision);
    }
  }

  @override
  List<Object?> get props => [
    syncMode,
    retentionWindow,
    completionThreshold,
    stableIdPolicy,
  ];
}

abstract interface class AiroWatchProgressRepository {
  Future<AiroWatchProgressDecision> upsert({
    required AiroWatchProgressRecord record,
    required DateTime now,
    AiroWatchProgressSyncTarget target,
  });

  Future<AiroWatchProgressDecision> delete({
    required AiroWatchProgressKey key,
    required AiroSessionRevision revision,
    required String updatedByDeviceId,
    required DateTime deletedAt,
    required DateTime retentionExpiresAt,
    required DateTime now,
  });

  Future<AiroWatchProgressRecord?> latestFor(AiroWatchProgressKey key);

  Future<List<AiroWatchProgressRecord>> list({String? profileId});
}

class AiroNoOpWatchProgressRepository implements AiroWatchProgressRepository {
  const AiroNoOpWatchProgressRepository();

  @override
  Future<AiroWatchProgressDecision> upsert({
    required AiroWatchProgressRecord record,
    required DateTime now,
    AiroWatchProgressSyncTarget target = AiroWatchProgressSyncTarget.local,
  }) async {
    return AiroWatchProgressDecision(
      action: AiroWatchProgressDecisionAction.noOp,
      codes: const [AiroWatchProgressCode.repositoryUnavailable],
      record: record,
    );
  }

  @override
  Future<AiroWatchProgressDecision> delete({
    required AiroWatchProgressKey key,
    required AiroSessionRevision revision,
    required String updatedByDeviceId,
    required DateTime deletedAt,
    required DateTime retentionExpiresAt,
    required DateTime now,
  }) async {
    final record = AiroWatchProgressRecord(
      progressId: key.stableKey,
      key: key,
      position: Duration.zero,
      duration: const Duration(seconds: 1),
      status: AiroWatchProgressStatus.hidden,
      revision: revision,
      updatedByNodeId: revision.reporterNodeId,
      updatedByDeviceId: updatedByDeviceId,
      updatedAt: deletedAt,
      retentionExpiresAt: retentionExpiresAt,
      deletedAt: deletedAt,
    );
    return AiroWatchProgressDecision(
      action: AiroWatchProgressDecisionAction.noOp,
      codes: const [AiroWatchProgressCode.repositoryUnavailable],
      record: record,
    );
  }

  @override
  Future<AiroWatchProgressRecord?> latestFor(AiroWatchProgressKey key) async {
    return null;
  }

  @override
  Future<List<AiroWatchProgressRecord>> list({String? profileId}) async {
    return const [];
  }
}

class AiroFakeWatchProgressRepository implements AiroWatchProgressRepository {
  AiroFakeWatchProgressRepository({required this.policy});

  final AiroWatchProgressPolicy policy;
  final Map<String, AiroWatchProgressRecord> _records = {};

  @override
  Future<AiroWatchProgressDecision> upsert({
    required AiroWatchProgressRecord record,
    required DateTime now,
    AiroWatchProgressSyncTarget target = AiroWatchProgressSyncTarget.local,
  }) async {
    final current = _records[record.key.stableKey];
    final decision = policy.evaluate(
      incoming: record,
      current: current,
      now: now,
      target: target,
    );
    if (decision.action == AiroWatchProgressDecisionAction.accept ||
        decision.action == AiroWatchProgressDecisionAction.delete) {
      _records[record.key.stableKey] = record;
    }
    return decision;
  }

  @override
  Future<AiroWatchProgressDecision> delete({
    required AiroWatchProgressKey key,
    required AiroSessionRevision revision,
    required String updatedByDeviceId,
    required DateTime deletedAt,
    required DateTime retentionExpiresAt,
    required DateTime now,
  }) async {
    final current = _records[key.stableKey];
    final base =
        current ??
        AiroWatchProgressRecord(
          progressId: key.stableKey,
          key: key,
          position: Duration.zero,
          duration: const Duration(seconds: 1),
          status: AiroWatchProgressStatus.hidden,
          revision: revision,
          updatedByNodeId: revision.reporterNodeId,
          updatedByDeviceId: updatedByDeviceId,
          updatedAt: deletedAt,
          retentionExpiresAt: retentionExpiresAt,
        );
    return upsert(
      record: base.tombstone(
        revision: revision,
        deletedAt: deletedAt,
        retentionExpiresAt: retentionExpiresAt,
      ),
      now: now,
    );
  }

  @override
  Future<AiroWatchProgressRecord?> latestFor(AiroWatchProgressKey key) async {
    return _records[key.stableKey];
  }

  @override
  Future<List<AiroWatchProgressRecord>> list({String? profileId}) async {
    final values = _records.values.where(
      (record) => profileId == null || record.key.profileId == profileId,
    );
    return List.unmodifiable(values);
  }
}
