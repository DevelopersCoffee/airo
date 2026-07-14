import 'package:core_sessions/core_sessions.dart';
import 'package:core_watch_progress/core_watch_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 14, 12);

  group('AiroWatchProgressPolicy', () {
    test('accepts local progress but blocks cloud in local-only mode', () {
      const policy = AiroWatchProgressPolicy(
        syncMode: AiroWatchProgressSyncMode.localOnly,
      );
      final record = _record(now);

      final local = policy.evaluate(incoming: record, now: now);
      final cloud = policy.evaluate(
        incoming: record,
        now: now,
        target: AiroWatchProgressSyncTarget.cloud,
      );

      expect(local.accepted, isTrue);
      expect(cloud.action, AiroWatchProgressDecisionAction.deny);
      expect(cloud.has(AiroWatchProgressCode.localOnlyCloudBlocked), isTrue);
    });

    test('requires per-record cloud eligibility in opt-in mode', () {
      const policy = AiroWatchProgressPolicy(
        syncMode: AiroWatchProgressSyncMode.cloudOptIn,
      );
      final blocked = policy.evaluate(
        incoming: _record(now, cloudEligible: false),
        now: now,
        target: AiroWatchProgressSyncTarget.cloud,
      );
      final accepted = policy.evaluate(
        incoming: _record(now, cloudEligible: true),
        now: now,
        target: AiroWatchProgressSyncTarget.cloud,
      );

      expect(blocked.has(AiroWatchProgressCode.cloudOptInRequired), isTrue);
      expect(accepted.accepted, isTrue);
    });

    test('accepts newer revisions, ignores stale, and reports conflicts', () {
      const policy = AiroWatchProgressPolicy(
        syncMode: AiroWatchProgressSyncMode.cloudEnabled,
      );
      final current = _record(now, revisionValue: 2);
      final newer = policy.evaluate(
        incoming: _record(now, revisionValue: 3),
        current: current,
        now: now,
      );
      final stale = policy.evaluate(
        incoming: _record(now, revisionValue: 1),
        current: current,
        now: now,
      );
      final conflict = policy.evaluate(
        incoming: _record(
          now,
          revisionValue: 2,
          reporterNodeId: 'receiver-node-2',
        ),
        current: current,
        now: now,
      );

      expect(newer.accepted, isTrue);
      expect(stale.action, AiroWatchProgressDecisionAction.ignoreStale);
      expect(stale.codes, [AiroWatchProgressCode.staleRevision]);
      expect(conflict.action, AiroWatchProgressDecisionAction.conflict);
      expect(conflict.codes, [AiroWatchProgressCode.revisionConflict]);
    });

    test('rejects unsafe identifiers and invalid progress shape', () {
      const policy = AiroWatchProgressPolicy(
        syncMode: AiroWatchProgressSyncMode.cloudEnabled,
      );
      final unsafe = policy.evaluate(
        incoming: _record(
          now,
          key: const AiroWatchProgressKey(
            profileId: 'profile-1',
            mediaId: 'https://example.test/movie',
            sourceId: 'source-1',
            resolverId: 'resolver-1',
          ),
        ),
        now: now,
      );
      final invalid = policy.evaluate(
        incoming: _record(
          now,
          position: const Duration(minutes: 70),
          duration: const Duration(minutes: 60),
          status: AiroWatchProgressStatus.completed,
        ),
        now: now,
      );

      expect(unsafe.has(AiroWatchProgressCode.unsafeStableId), isTrue);
      expect(invalid.has(AiroWatchProgressCode.invalidPosition), isTrue);
      expect(invalid.has(AiroWatchProgressCode.invalidCompletion), isFalse);
    });

    test(
      'rejects incomplete completion state and retention-expired records',
      () {
        const policy = AiroWatchProgressPolicy(
          syncMode: AiroWatchProgressSyncMode.cloudEnabled,
          retentionWindow: Duration(days: 30),
        );
        final incomplete = policy.evaluate(
          incoming: _record(
            now,
            position: const Duration(minutes: 10),
            duration: const Duration(minutes: 60),
            status: AiroWatchProgressStatus.completed,
          ),
          now: now,
        );
        final expired = policy.evaluate(
          incoming: _record(
            now,
            updatedAt: now.subtract(const Duration(days: 31)),
            retentionExpiresAt: now.subtract(const Duration(days: 1)),
          ),
          now: now,
        );

        expect(incomplete.has(AiroWatchProgressCode.invalidCompletion), isTrue);
        expect(expired.has(AiroWatchProgressCode.expiredRecord), isTrue);
        expect(expired.has(AiroWatchProgressCode.retentionExceeded), isTrue);
      },
    );

    test('accepts delete tombstones without exposing media details', () {
      const policy = AiroWatchProgressPolicy(
        syncMode: AiroWatchProgressSyncMode.cloudEnabled,
      );
      final record = _record(now);
      final tombstone = record.tombstone(
        revision: _revision(now, value: 2),
        deletedAt: now.add(const Duration(seconds: 1)),
        retentionExpiresAt: now.add(const Duration(days: 7)),
      );
      final decision = policy.evaluate(incoming: tombstone, now: now);

      expect(decision.action, AiroWatchProgressDecisionAction.delete);
      expect(decision.codes, [AiroWatchProgressCode.deleteTombstone]);
      expect(tombstone.toString(), isNot(contains('Some Movie')));
      expect(tombstone.toPublicMap()['completionPercent'], 50);
    });

    test('diagnostic map carries stable IDs and revision only', () {
      const policy = AiroWatchProgressPolicy(
        syncMode: AiroWatchProgressSyncMode.cloudEnabled,
      );
      final decision = policy.evaluate(incoming: _record(now), now: now);

      expect(decision.toDiagnosticMap(), {
        'schemaVersion': kAiroWatchProgressSchemaVersion,
        'action': 'accept',
        'codes': ['accepted'],
        'progressId': 'progress-1',
        'revision': 1,
        'currentRevision': null,
        'profileId': 'profile-1',
        'mediaId': 'media-1',
        'sourceId': 'source-1',
      });
    });
  });

  group('AiroWatchProgressRepository', () {
    test(
      'fake repository upserts, lists, ignores stale, and deletes',
      () async {
        final repository = AiroFakeWatchProgressRepository(
          policy: const AiroWatchProgressPolicy(
            syncMode: AiroWatchProgressSyncMode.cloudEnabled,
          ),
        );
        final first = await repository.upsert(record: _record(now), now: now);
        final stale = await repository.upsert(
          record: _record(now, revisionValue: 0),
          now: now,
        );
        final deleted = await repository.delete(
          key: _key(),
          revision: _revision(now, value: 2),
          updatedByDeviceId: 'tv-device-1',
          deletedAt: now.add(const Duration(seconds: 1)),
          retentionExpiresAt: now.add(const Duration(days: 7)),
          now: now.add(const Duration(seconds: 1)),
        );
        final latest = await repository.latestFor(_key());
        final list = await repository.list(profileId: 'profile-1');

        expect(first.accepted, isTrue);
        expect(stale.action, AiroWatchProgressDecisionAction.ignoreStale);
        expect(deleted.action, AiroWatchProgressDecisionAction.delete);
        expect(latest?.isDeleted, isTrue);
        expect(list, hasLength(1));
      },
    );

    test('no-op repository fails closed', () async {
      const repository = AiroNoOpWatchProgressRepository();

      final decision = await repository.upsert(record: _record(now), now: now);

      expect(decision.action, AiroWatchProgressDecisionAction.noOp);
      expect(decision.codes, [AiroWatchProgressCode.repositoryUnavailable]);
      expect(await repository.latestFor(_key()), isNull);
      expect(await repository.list(), isEmpty);
    });
  });
}

AiroWatchProgressKey _key() {
  return const AiroWatchProgressKey(
    profileId: 'profile-1',
    mediaId: 'media-1',
    sourceId: 'source-1',
    resolverId: 'resolver-1',
  );
}

AiroWatchProgressRecord _record(
  DateTime now, {
  AiroWatchProgressKey? key,
  Duration position = const Duration(minutes: 30),
  Duration duration = const Duration(minutes: 60),
  AiroWatchProgressStatus status = AiroWatchProgressStatus.inProgress,
  int revisionValue = 1,
  String reporterNodeId = 'receiver-node-1',
  bool cloudEligible = true,
  DateTime? updatedAt,
  DateTime? retentionExpiresAt,
}) {
  return AiroWatchProgressRecord(
    progressId: 'progress-1',
    key: key ?? _key(),
    position: position,
    duration: duration,
    status: status,
    revision: _revision(
      now,
      value: revisionValue,
      reporterNodeId: reporterNodeId,
    ),
    updatedByNodeId: reporterNodeId,
    updatedByDeviceId: 'tv-device-1',
    updatedAt: updatedAt ?? now,
    retentionExpiresAt: retentionExpiresAt ?? now.add(const Duration(days: 90)),
    cloudEligible: cloudEligible,
  );
}

AiroSessionRevision _revision(
  DateTime now, {
  required int value,
  String reporterNodeId = 'receiver-node-1',
}) {
  return AiroSessionRevision(
    value: value,
    updatedAt: now.add(Duration(seconds: value)),
    reporterNodeId: reporterNodeId,
  );
}
