import 'package:core_sessions/core_sessions.dart';
import 'package:core_watch_progress/core_watch_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 27, 12);

  AiroWatchProgressRecord record({
    required String mediaId,
    String profileId = 'profile-1',
    AiroWatchProgressStatus status = AiroWatchProgressStatus.inProgress,
    Duration position = const Duration(minutes: 10),
    DateTime? updatedAt,
    DateTime? expiresAt,
    DateTime? deletedAt,
    int revision = 1,
  }) {
    return AiroWatchProgressRecord(
      progressId: 'progress-$mediaId',
      key: AiroWatchProgressKey(
        profileId: profileId,
        mediaId: mediaId,
        sourceId: 'source',
        resolverId: 'resolver',
      ),
      position: position,
      duration: const Duration(hours: 1),
      status: status,
      revision: AiroSessionRevision(
        value: revision,
        updatedAt: updatedAt ?? now,
        reporterNodeId: 'node-$revision',
      ),
      updatedByNodeId: 'node-$revision',
      updatedByDeviceId: 'device-$revision',
      updatedAt: updatedAt ?? now,
      retentionExpiresAt: expiresAt ?? now.add(const Duration(days: 30)),
      deletedAt: deletedAt,
    );
  }

  test('selects newest unfinished row from a reconciled device snapshot', () {
    final result = const AiroResumeResolver().resolve(
      profileId: 'profile-1',
      records: [
        record(
          mediaId: 'tv-record',
          updatedAt: now.subtract(const Duration(minutes: 2)),
        ),
        record(
          mediaId: 'phone-record',
          updatedAt: now.subtract(const Duration(minutes: 1)),
        ),
      ],
      now: now,
    );

    expect(result?.key.mediaId, 'phone-record');
    expect(result?.updatedByDeviceId, 'device-1');
  });

  test('filters other profiles, terminal states, tombstones, and expiry', () {
    final result = const AiroResumeResolver().resolve(
      profileId: 'profile-1',
      records: [
        record(mediaId: 'other', profileId: 'profile-2'),
        record(mediaId: 'complete', status: AiroWatchProgressStatus.completed),
        record(mediaId: 'hidden', status: AiroWatchProgressStatus.hidden),
        record(
          mediaId: 'deleted',
          deletedAt: now.subtract(const Duration(minutes: 1)),
        ),
        record(mediaId: 'expired', expiresAt: now),
      ],
      now: now,
    );

    expect(result, isNull);
  });

  test('ties break by revision then stable key', () {
    final resolver = const AiroResumeResolver();
    final revisionWinner = resolver.resolve(
      profileId: 'profile-1',
      records: [
        record(mediaId: 'a', revision: 1),
        record(mediaId: 'z', revision: 2),
      ],
      now: now,
    );
    final keyWinner = resolver.resolve(
      profileId: 'profile-1',
      records: [
        record(mediaId: 'z', revision: 1),
        record(mediaId: 'a', revision: 1),
      ],
      now: now,
    );

    expect(revisionWinner?.key.mediaId, 'z');
    expect(keyWinner?.key.mediaId, 'a');
  });
}
