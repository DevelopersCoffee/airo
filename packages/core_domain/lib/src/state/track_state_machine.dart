import '../entities/life_track.dart';
import '../entities/milestone.dart';
import '../errors/app_error.dart';

class TrackStateMachine {
  const TrackStateMachine._();

  static const Map<ItemStatus, Set<ItemStatus>> _transitions = {
    ItemStatus.todo: {ItemStatus.inProgress, ItemStatus.skipped},
    ItemStatus.inProgress: {
      ItemStatus.done,
      ItemStatus.blocked,
      ItemStatus.todo,
    },
    ItemStatus.blocked: {
      ItemStatus.inProgress,
      ItemStatus.todo,
      ItemStatus.skipped,
    },
    ItemStatus.done: {ItemStatus.todo},
    ItemStatus.skipped: {ItemStatus.todo},
  };

  static bool canTransition(ItemStatus from, ItemStatus to) {
    return _transitions[from]?.contains(to) ?? false;
  }

  static ItemStatus transition(ItemStatus from, ItemStatus to) {
    if (!canTransition(from, to)) {
      throw InvalidStatusTransitionError(from, to);
    }
    return to;
  }

  static double milestoneProgress(Milestone milestone) => milestone.progress;

  static double trackProgress(LifeTrack track) {
    var completed = 0;
    var total = 0;

    for (final milestone in track.milestones) {
      for (final item in milestone.actionItems) {
        if (item.status == ItemStatus.skipped) {
          continue;
        }
        total++;
        if (item.status == ItemStatus.done) {
          completed++;
        }
      }
    }

    if (total == 0) return 0;
    return completed / total;
  }

  static TrackStatus computeTrackStatus(LifeTrack track) {
    if (track.status == TrackStatus.archived ||
        track.status == TrackStatus.postponed) {
      return track.status;
    }

    final items = track.milestones.expand((milestone) => milestone.actionItems);
    if (items.isEmpty) return TrackStatus.draft;

    final allResolved = items.every(
      (item) =>
          item.status == ItemStatus.done || item.status == ItemStatus.skipped,
    );
    if (allResolved) return TrackStatus.completed;

    final hasStarted = items.any((item) => item.status != ItemStatus.todo);
    return hasStarted ? TrackStatus.active : TrackStatus.draft;
  }

  static bool isSuppressed(TrackStatus status) =>
      status == TrackStatus.postponed;
}
