import 'dart:async';

import '../entities/action_item.dart';
import '../entities/life_track.dart';
import '../entities/milestone.dart';
import '../result/result.dart';

abstract class LifeTrackRepository {
  Future<Result<LifeTrack>> createTrack(LifeTrack track);

  Future<Result<LifeTrack>> getTrack(String id);

  Future<Result<List<LifeTrack>>> listTracks({TrackStatus? status});

  Future<Result<void>> updateTrack(LifeTrack track);

  Future<Result<void>> deleteTrack(String id);

  Stream<List<LifeTrack>> watchTracks({TrackStatus? status});

  Future<Result<void>> updateMilestone(Milestone milestone);

  Future<Result<void>> updateActionItem(ActionItem item);

  Future<Result<void>> updateItemStatus(String itemId, ItemStatus status);

  Future<Result<void>> saveInputValue(String requirementId, String value);
}
