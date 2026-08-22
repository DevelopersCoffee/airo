import 'package:core_domain/core_domain.dart';

import '../storage/secure_life_track_destination.dart';

class SecureLifeTrackRepositoryImpl implements LifeTrackRepository {
  SecureLifeTrackRepositoryImpl({required this._destination});

  final SecureLifeTrackDestination _destination;

  @override
  Future<Result<LifeTrack>> createTrack(LifeTrack track) =>
      _destination.createTrack(track);

  @override
  Future<Result<void>> deleteTrack(String id) =>
      _destination.deleteTrack(id);

  @override
  Future<Result<LifeTrack>> getTrack(String id) => _destination.getTrack(id);

  @override
  Future<Result<List<LifeTrack>>> listTracks({TrackStatus? status}) =>
      _destination.listTracks(status: status);

  @override
  Future<Result<void>> saveInputValue(
    String requirementId,
    String value,
  ) => _destination.saveInputValue(requirementId, value);

  @override
  Future<Result<void>> updateActionItem(ActionItem item) =>
      _destination.updateActionItem(item);

  @override
  Future<Result<void>> updateItemStatus(
    String itemId,
    ItemStatus status,
  ) => _destination.updateItemStatus(itemId, status);

  @override
  Future<Result<void>> updateMilestone(Milestone milestone) =>
      _destination.updateMilestone(milestone);

  @override
  Future<Result<void>> updateTrack(LifeTrack track) =>
      _destination.updateTrack(track);

  @override
  Stream<List<LifeTrack>> watchTracks({TrackStatus? status}) =>
      _destination.watchTracks(status: status);
}
