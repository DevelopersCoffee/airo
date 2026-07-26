import 'watch_progress_models.dart';

class AiroResumeResolver {
  const AiroResumeResolver();

  AiroWatchProgressRecord? resolve({
    required String profileId,
    required Iterable<AiroWatchProgressRecord> records,
    required DateTime now,
  }) {
    final eligible = records
        .where(
          (record) =>
              record.key.profileId == profileId &&
              !record.isDeleted &&
              !record.isExpired(now) &&
              record.status == AiroWatchProgressStatus.inProgress &&
              record.position > Duration.zero &&
              record.duration > Duration.zero &&
              record.position < record.duration,
        )
        .toList();
    eligible.sort((left, right) {
      final updated = right.updatedAt.compareTo(left.updatedAt);
      if (updated != 0) return updated;
      final revision = right.revision.value.compareTo(left.revision.value);
      if (revision != 0) return revision;
      return left.key.stableKey.compareTo(right.key.stableKey);
    });
    return eligible.firstOrNull;
  }
}
