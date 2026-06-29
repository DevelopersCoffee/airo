import 'package:core_data/src/storage/life_track_local_data_source.dart';
import 'package:core_domain/core_domain.dart';

class LifeTrackRepositoryImpl implements LifeTrackRepository {
  LifeTrackRepositoryImpl({required this._localDataSource});

  final LifeTrackLocalDataSource _localDataSource;

  @override
  Future<Result<LifeTrack>> createTrack(LifeTrack track) async {
    try {
      return Ok(await _localDataSource.createTrack(track));
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  @override
  Future<Result<void>> deleteTrack(String id) async {
    try {
      await _localDataSource.deleteTrack(id);
      return const Ok(null);
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  @override
  Future<Result<LifeTrack>> getTrack(String id) async {
    try {
      final track = await _localDataSource.getTrack(id);
      if (track == null) {
        return Err(
          NotFoundError('LifeTrack not found: $id'),
          StackTrace.current,
        );
      }
      return Ok(track);
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  @override
  Future<Result<List<LifeTrack>>> listTracks({TrackStatus? status}) async {
    try {
      return Ok(await _localDataSource.listTracks(status: status));
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  @override
  Future<Result<void>> saveInputValue(
    String requirementId,
    String value,
  ) async {
    try {
      await _localDataSource.saveInputValue(requirementId, value);
      return const Ok(null);
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  @override
  Future<Result<void>> updateActionItem(ActionItem item) async {
    try {
      await _localDataSource.updateActionItem(item);
      return const Ok(null);
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  @override
  Future<Result<void>> updateItemStatus(
    String itemId,
    ItemStatus status,
  ) async {
    try {
      await _localDataSource.updateItemStatus(itemId, status);
      return const Ok(null);
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  @override
  Future<Result<void>> updateMilestone(Milestone milestone) async {
    try {
      await _localDataSource.updateMilestone(milestone);
      return const Ok(null);
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  @override
  Future<Result<void>> updateTrack(LifeTrack track) async {
    try {
      await _localDataSource.updateTrack(track);
      return const Ok(null);
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  @override
  Stream<List<LifeTrack>> watchTracks({TrackStatus? status}) {
    return _localDataSource.watchTracks(status: status);
  }
}
