import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'LifeTrackRepository interface is implementable with Result signatures',
    () async {
      final repository = _FakeLifeTrackRepository();
      final track = LifeTrack(
        id: 'track-1',
        title: 'Track',
        category: LifeTrackCategory.finance,
        status: TrackStatus.draft,
        milestones: const [],
        createdAt: DateTime.utc(2026, 6, 29),
        updatedAt: DateTime.utc(2026, 6, 29),
      );

      expect((await repository.createTrack(track)).value, track);
      expect((await repository.getTrack('track-1')).value.id, 'track-1');
      expect((await repository.listTracks()).value, [track]);
      expect(await repository.watchTracks().first, [track]);
    },
  );
}

class _FakeLifeTrackRepository implements LifeTrackRepository {
  LifeTrack? _track;

  @override
  Future<Result<LifeTrack>> createTrack(LifeTrack track) async {
    _track = track;
    return Ok(track);
  }

  @override
  Future<Result<void>> deleteTrack(String id) async => const Ok(null);

  @override
  Future<Result<LifeTrack>> getTrack(String id) async => Ok(_track!);

  @override
  Future<Result<List<LifeTrack>>> listTracks({TrackStatus? status}) async =>
      Ok(_track == null ? const [] : [_track!]);

  @override
  Future<Result<void>> saveInputValue(
    String requirementId,
    String value,
  ) async => const Ok(null);

  @override
  Future<Result<void>> updateActionItem(ActionItem item) async =>
      const Ok(null);

  @override
  Future<Result<void>> updateItemStatus(
    String itemId,
    ItemStatus status,
  ) async => const Ok(null);

  @override
  Future<Result<void>> updateMilestone(Milestone milestone) async =>
      const Ok(null);

  @override
  Future<Result<void>> updateTrack(LifeTrack track) async {
    _track = track;
    return const Ok(null);
  }

  @override
  Stream<List<LifeTrack>> watchTracks({TrackStatus? status}) async* {
    if (_track != null) yield [_track!];
  }
}
