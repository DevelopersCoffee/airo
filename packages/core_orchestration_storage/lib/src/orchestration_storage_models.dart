import 'package:core_commands/core_commands.dart';
import 'package:core_device_identity/core_device_identity.dart';
import 'package:core_presence/core_presence.dart';
import 'package:core_sessions/core_sessions.dart';
import 'package:core_watch_progress/core_watch_progress.dart';
import 'package:equatable/equatable.dart';

const String kAiroOrchestrationStorageSchemaVersion = '1.0.0';

enum AiroOrchestrationStorageCollection {
  deviceRegistry('device_registry'),
  presenceLeases('presence_leases'),
  playbackSessions('playback_sessions'),
  sessionControllers('session_controllers'),
  commandLifecycle('command_lifecycle'),
  watchProgress('watch_progress');

  const AiroOrchestrationStorageCollection(this.stableId);

  final String stableId;
}

enum AiroOrchestrationStorageHealthStatus {
  available('available'),
  degraded('degraded'),
  unavailable('unavailable');

  const AiroOrchestrationStorageHealthStatus(this.stableId);

  final String stableId;
}

enum AiroSessionControllerMembershipAction {
  accept('accept'),
  ignoreExpired('ignore_expired'),
  revoke('revoke'),
  noOp('no_op');

  const AiroSessionControllerMembershipAction(this.stableId);

  final String stableId;
}

enum AiroSessionControllerMembershipCode {
  accepted('accepted'),
  expiredMember('expired_member'),
  revokedMember('revoked_member'),
  permissionMissing('permission_missing'),
  storeUnavailable('store_unavailable');

  const AiroSessionControllerMembershipCode(this.stableId);

  final String stableId;
}

class AiroOrchestrationStorageManifest extends Equatable {
  AiroOrchestrationStorageManifest({
    required this.manifestId,
    required Set<AiroOrchestrationStorageCollection> enabledCollections,
    this.providerAvailable = true,
    this.schemaVersion = kAiroOrchestrationStorageSchemaVersion,
  }) : enabledCollections = Set.unmodifiable(enabledCollections);

  final String schemaVersion;
  final String manifestId;
  final Set<AiroOrchestrationStorageCollection> enabledCollections;
  final bool providerAvailable;

  bool supports(AiroOrchestrationStorageCollection collection) {
    return enabledCollections.contains(collection);
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'manifestId': manifestId,
      'enabledCollections': enabledCollections
          .map((collection) => collection.stableId)
          .toList(growable: false),
      'providerAvailable': providerAvailable,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    manifestId,
    enabledCollections,
    providerAvailable,
  ];
}

class AiroOrchestrationCollectionHealth extends Equatable {
  const AiroOrchestrationCollectionHealth({
    required this.collection,
    required this.status,
    required this.recordCount,
    required this.checkedAt,
    this.reasonCode,
    this.schemaVersion = kAiroOrchestrationStorageSchemaVersion,
  });

  final String schemaVersion;
  final AiroOrchestrationStorageCollection collection;
  final AiroOrchestrationStorageHealthStatus status;
  final int recordCount;
  final DateTime checkedAt;
  final String? reasonCode;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'collection': collection.stableId,
      'status': status.stableId,
      'recordCount': recordCount,
      'checkedAt': checkedAt.toIso8601String(),
      'reasonCode': reasonCode,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    collection,
    status,
    recordCount,
    checkedAt,
    reasonCode,
  ];
}

class AiroOrchestrationStorageHealth extends Equatable {
  AiroOrchestrationStorageHealth({
    required this.status,
    required Iterable<AiroOrchestrationCollectionHealth> collections,
    required this.checkedAt,
    this.schemaVersion = kAiroOrchestrationStorageSchemaVersion,
  }) : collections = List.unmodifiable(collections);

  final String schemaVersion;
  final AiroOrchestrationStorageHealthStatus status;
  final List<AiroOrchestrationCollectionHealth> collections;
  final DateTime checkedAt;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'status': status.stableId,
      'checkedAt': checkedAt.toIso8601String(),
      'collections': collections
          .map((collection) => collection.toPublicMap())
          .toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [schemaVersion, status, collections, checkedAt];
}

class AiroSessionControllerMembershipDecision extends Equatable {
  AiroSessionControllerMembershipDecision({
    required this.action,
    required Iterable<AiroSessionControllerMembershipCode> codes,
    required this.member,
  }) : codes = List.unmodifiable(codes);

  final AiroSessionControllerMembershipAction action;
  final List<AiroSessionControllerMembershipCode> codes;
  final AiroUniversalSessionMember member;

  bool get accepted =>
      action == AiroSessionControllerMembershipAction.accept &&
      codes.length == 1 &&
      codes.single == AiroSessionControllerMembershipCode.accepted;

  @override
  List<Object?> get props => [action, codes, member];
}

abstract interface class AiroSessionControllerMembershipStore {
  Future<AiroSessionControllerMembershipDecision> upsert({
    required String sessionId,
    required AiroUniversalSessionMember member,
    required DateTime now,
  });

  Future<List<AiroUniversalSessionMember>> list({
    required String sessionId,
    required DateTime now,
  });

  Future<AiroSessionControllerMembershipDecision> revoke({
    required String sessionId,
    required String nodeId,
    required DateTime now,
  });
}

class AiroNoOpSessionControllerMembershipStore
    implements AiroSessionControllerMembershipStore {
  const AiroNoOpSessionControllerMembershipStore();

  @override
  Future<List<AiroUniversalSessionMember>> list({
    required String sessionId,
    required DateTime now,
  }) async {
    return const [];
  }

  @override
  Future<AiroSessionControllerMembershipDecision> revoke({
    required String sessionId,
    required String nodeId,
    required DateTime now,
  }) async {
    final member = _placeholderMember(nodeId: nodeId, now: now);
    return AiroSessionControllerMembershipDecision(
      action: AiroSessionControllerMembershipAction.noOp,
      codes: const [AiroSessionControllerMembershipCode.storeUnavailable],
      member: member,
    );
  }

  @override
  Future<AiroSessionControllerMembershipDecision> upsert({
    required String sessionId,
    required AiroUniversalSessionMember member,
    required DateTime now,
  }) async {
    return AiroSessionControllerMembershipDecision(
      action: AiroSessionControllerMembershipAction.noOp,
      codes: const [AiroSessionControllerMembershipCode.storeUnavailable],
      member: member,
    );
  }
}

class AiroFakeSessionControllerMembershipStore
    implements AiroSessionControllerMembershipStore {
  final Map<String, List<AiroUniversalSessionMember>> _membersBySession = {};

  @override
  Future<List<AiroUniversalSessionMember>> list({
    required String sessionId,
    required DateTime now,
  }) async {
    final members = _membersBySession[sessionId] ?? const [];
    return List.unmodifiable(
      members.where((member) {
        return !member.isExpired(now) && !member.isRevoked(now);
      }),
    );
  }

  @override
  Future<AiroSessionControllerMembershipDecision> revoke({
    required String sessionId,
    required String nodeId,
    required DateTime now,
  }) async {
    final members =
        _membersBySession[sessionId] ?? <AiroUniversalSessionMember>[];
    final index = members.indexWhere((member) => member.nodeId == nodeId);
    final current = index >= 0
        ? members[index]
        : _placeholderMember(nodeId: nodeId, now: now);
    final revoked = _copyMember(current, revokedAt: now);
    if (index >= 0) {
      members[index] = revoked;
    } else {
      _membersBySession[sessionId] = [...members, revoked];
    }
    return AiroSessionControllerMembershipDecision(
      action: AiroSessionControllerMembershipAction.revoke,
      codes: const [AiroSessionControllerMembershipCode.revokedMember],
      member: revoked,
    );
  }

  @override
  Future<AiroSessionControllerMembershipDecision> upsert({
    required String sessionId,
    required AiroUniversalSessionMember member,
    required DateTime now,
  }) async {
    final codes = <AiroSessionControllerMembershipCode>[];
    if (member.isExpired(now)) {
      codes.add(AiroSessionControllerMembershipCode.expiredMember);
    }
    if (member.isRevoked(now)) {
      codes.add(AiroSessionControllerMembershipCode.revokedMember);
    }
    if (member.permissions.isEmpty) {
      codes.add(AiroSessionControllerMembershipCode.permissionMissing);
    }
    if (codes.isNotEmpty) {
      return AiroSessionControllerMembershipDecision(
        action: AiroSessionControllerMembershipAction.ignoreExpired,
        codes: codes,
        member: member,
      );
    }
    final members = _membersBySession.putIfAbsent(sessionId, () => []);
    final index = members.indexWhere(
      (stored) => stored.nodeId == member.nodeId,
    );
    if (index >= 0) {
      members[index] = member;
    } else {
      members.add(member);
    }
    return AiroSessionControllerMembershipDecision(
      action: AiroSessionControllerMembershipAction.accept,
      codes: const [AiroSessionControllerMembershipCode.accepted],
      member: member,
    );
  }
}

class AiroOrchestrationStorageSnapshot extends Equatable {
  AiroOrchestrationStorageSnapshot({
    required Iterable<AiroRegisteredDeviceRecord> devices,
    required Iterable<AiroPresenceLease> presenceLeases,
    required Iterable<AiroUniversalPlaybackSessionSnapshot> sessions,
    required Map<String, List<AiroUniversalSessionMember>> controllerMembers,
    required Iterable<AiroCommandLifecycleRecord> commands,
    required Iterable<AiroWatchProgressRecord> progressRecords,
    required this.capturedAt,
    this.schemaVersion = kAiroOrchestrationStorageSchemaVersion,
  }) : devices = List.unmodifiable(devices),
       presenceLeases = List.unmodifiable(presenceLeases),
       sessions = List.unmodifiable(sessions),
       controllerMembers =
           Map<String, List<AiroUniversalSessionMember>>.unmodifiable(
             controllerMembers.map(
               (key, value) => MapEntry(
                 key,
                 List<AiroUniversalSessionMember>.unmodifiable(value),
               ),
             ),
           ),
       commands = List.unmodifiable(commands),
       progressRecords = List.unmodifiable(progressRecords);

  final String schemaVersion;
  final List<AiroRegisteredDeviceRecord> devices;
  final List<AiroPresenceLease> presenceLeases;
  final List<AiroUniversalPlaybackSessionSnapshot> sessions;
  final Map<String, List<AiroUniversalSessionMember>> controllerMembers;
  final List<AiroCommandLifecycleRecord> commands;
  final List<AiroWatchProgressRecord> progressRecords;
  final DateTime capturedAt;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'capturedAt': capturedAt.toIso8601String(),
      'deviceCount': devices.length,
      'presenceLeaseCount': presenceLeases.length,
      'sessionCount': sessions.length,
      'sessionControllerCount': controllerMembers.values.fold<int>(
        0,
        (total, members) => total + members.length,
      ),
      'commandCount': commands.length,
      'progressCount': progressRecords.length,
      'sessionIds': sessions.map((session) => session.sessionId).toList(),
      'commandIds': commands.map((command) => command.commandId).toList(),
      'progressIds': progressRecords
          .map((progress) => progress.progressId)
          .toList(),
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    devices,
    presenceLeases,
    sessions,
    controllerMembers,
    commands,
    progressRecords,
    capturedAt,
  ];
}

abstract interface class AiroOrchestrationStorage {
  AiroOrchestrationStorageManifest get manifest;
  AiroDeviceIdentityRegistry get devices;
  AiroPresenceStore get presence;
  AiroUniversalPlaybackSessionRepository get sessions;
  AiroSessionControllerMembershipStore get controllers;
  AiroCommandLifecycleStore get commands;
  AiroWatchProgressRepository get progress;

  Future<AiroOrchestrationStorageHealth> health({required DateTime now});

  Future<AiroOrchestrationStorageSnapshot> snapshot({required DateTime now});
}

class AiroNoOpOrchestrationStorage implements AiroOrchestrationStorage {
  AiroNoOpOrchestrationStorage({AiroOrchestrationStorageManifest? manifest})
    : manifest =
          manifest ??
          AiroOrchestrationStorageManifest(
            manifestId: 'noop-orchestration-storage',
            enabledCollections: const {},
            providerAvailable: false,
          );

  @override
  final AiroOrchestrationStorageManifest manifest;

  @override
  final AiroDeviceIdentityRegistry devices =
      const AiroNoOpDeviceIdentityRegistry();

  @override
  final AiroPresenceStore presence = const AiroNoOpPresenceStore();

  @override
  final AiroUniversalPlaybackSessionRepository sessions =
      const AiroNoOpUniversalPlaybackSessionRepository();

  @override
  final AiroSessionControllerMembershipStore controllers =
      const AiroNoOpSessionControllerMembershipStore();

  @override
  final AiroCommandLifecycleStore commands =
      const AiroNoOpCommandLifecycleStore();

  @override
  final AiroWatchProgressRepository progress =
      const AiroNoOpWatchProgressRepository();

  @override
  Future<AiroOrchestrationStorageHealth> health({required DateTime now}) async {
    return AiroOrchestrationStorageHealth(
      status: AiroOrchestrationStorageHealthStatus.unavailable,
      checkedAt: now,
      collections: AiroOrchestrationStorageCollection.values.map(
        (collection) => AiroOrchestrationCollectionHealth(
          collection: collection,
          status: AiroOrchestrationStorageHealthStatus.unavailable,
          recordCount: 0,
          checkedAt: now,
          reasonCode: 'provider_unavailable',
        ),
      ),
    );
  }

  @override
  Future<AiroOrchestrationStorageSnapshot> snapshot({
    required DateTime now,
  }) async {
    return AiroOrchestrationStorageSnapshot(
      devices: const [],
      presenceLeases: const [],
      sessions: const [],
      controllerMembers: const {},
      commands: const [],
      progressRecords: const [],
      capturedAt: now,
    );
  }
}

class AiroFakeOrchestrationStorage implements AiroOrchestrationStorage {
  AiroFakeOrchestrationStorage({
    required this.manifest,
    required this.devices,
    required this.presence,
    required this.sessions,
    required this.controllers,
    required this.commands,
    required this.progress,
    Iterable<String> trackedSessionIds = const {},
  }) : trackedSessionIds = Set.of(trackedSessionIds);

  @override
  final AiroOrchestrationStorageManifest manifest;

  @override
  final AiroDeviceIdentityRegistry devices;

  @override
  final AiroPresenceStore presence;

  @override
  final AiroUniversalPlaybackSessionRepository sessions;

  @override
  final AiroSessionControllerMembershipStore controllers;

  @override
  final AiroCommandLifecycleStore commands;

  @override
  final AiroWatchProgressRepository progress;

  final Set<String> trackedSessionIds;

  @override
  Future<AiroOrchestrationStorageHealth> health({required DateTime now}) async {
    final devicesList = await devices.list();
    final leases = await presence.activeLeases(now: now);
    final commandsList = await commands.list();
    final progressList = await progress.list();
    final sessionSnapshots = await _sessions(now);
    final memberCount = await _memberCount(now);

    final counts = {
      AiroOrchestrationStorageCollection.deviceRegistry: devicesList.length,
      AiroOrchestrationStorageCollection.presenceLeases: leases.length,
      AiroOrchestrationStorageCollection.playbackSessions:
          sessionSnapshots.length,
      AiroOrchestrationStorageCollection.sessionControllers: memberCount,
      AiroOrchestrationStorageCollection.commandLifecycle: commandsList.length,
      AiroOrchestrationStorageCollection.watchProgress: progressList.length,
    };
    final collectionHealth = AiroOrchestrationStorageCollection.values.map((
      collection,
    ) {
      final supported =
          manifest.supports(collection) && manifest.providerAvailable;
      return AiroOrchestrationCollectionHealth(
        collection: collection,
        status: supported
            ? AiroOrchestrationStorageHealthStatus.available
            : AiroOrchestrationStorageHealthStatus.unavailable,
        recordCount: counts[collection] ?? 0,
        checkedAt: now,
        reasonCode: supported ? null : 'collection_unavailable',
      );
    });
    return AiroOrchestrationStorageHealth(
      status: manifest.providerAvailable
          ? AiroOrchestrationStorageHealthStatus.available
          : AiroOrchestrationStorageHealthStatus.unavailable,
      collections: collectionHealth,
      checkedAt: now,
    );
  }

  @override
  Future<AiroOrchestrationStorageSnapshot> snapshot({
    required DateTime now,
  }) async {
    final sessionSnapshots = await _sessions(now);
    final members = <String, List<AiroUniversalSessionMember>>{};
    for (final sessionId in trackedSessionIds) {
      final listed = await controllers.list(sessionId: sessionId, now: now);
      if (listed.isNotEmpty) members[sessionId] = listed;
    }
    return AiroOrchestrationStorageSnapshot(
      devices: await devices.list(),
      presenceLeases: await presence.activeLeases(now: now),
      sessions: sessionSnapshots,
      controllerMembers: members,
      commands: await commands.list(),
      progressRecords: await progress.list(),
      capturedAt: now,
    );
  }

  Future<List<AiroUniversalPlaybackSessionSnapshot>> _sessions(
    DateTime now,
  ) async {
    final snapshots = <AiroUniversalPlaybackSessionSnapshot>[];
    for (final sessionId in trackedSessionIds) {
      final snapshot = await sessions.recoverLatest(
        sessionId: sessionId,
        now: now,
      );
      if (snapshot != null) snapshots.add(snapshot);
    }
    return snapshots;
  }

  Future<int> _memberCount(DateTime now) async {
    var count = 0;
    for (final sessionId in trackedSessionIds) {
      count += (await controllers.list(sessionId: sessionId, now: now)).length;
    }
    return count;
  }
}

AiroUniversalSessionMember _placeholderMember({
  required String nodeId,
  required DateTime now,
}) {
  return AiroUniversalSessionMember(
    memberId: 'missing-$nodeId',
    nodeId: nodeId,
    deviceId: 'missing-device',
    role: AiroUniversalSessionMemberRole.observer,
    permissions: const {},
    joinedAt: now,
    revokedAt: now,
  );
}

AiroUniversalSessionMember _copyMember(
  AiroUniversalSessionMember member, {
  DateTime? revokedAt,
}) {
  return AiroUniversalSessionMember(
    schemaVersion: member.schemaVersion,
    memberId: member.memberId,
    nodeId: member.nodeId,
    deviceId: member.deviceId,
    role: member.role,
    permissions: member.permissions,
    joinedAt: member.joinedAt,
    expiresAt: member.expiresAt,
    revokedAt: revokedAt ?? member.revokedAt,
  );
}
