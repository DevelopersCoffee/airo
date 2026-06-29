import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrackStateMachine.canTransition', () {
    test('allows only the documented transitions', () {
      const statuses = ItemStatus.values;
      const expected = <ItemStatus, Set<ItemStatus>>{
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

      for (final from in statuses) {
        for (final to in statuses) {
          expect(
            TrackStateMachine.canTransition(from, to),
            expected[from]!.contains(to),
            reason:
                'Unexpected transition result for ${from.name} -> ${to.name}',
          );
        }
      }
    });
  });

  group('TrackStateMachine.transition', () {
    test('returns the target status for valid transitions', () {
      expect(
        TrackStateMachine.transition(ItemStatus.todo, ItemStatus.inProgress),
        ItemStatus.inProgress,
      );
      expect(
        TrackStateMachine.transition(ItemStatus.blocked, ItemStatus.skipped),
        ItemStatus.skipped,
      );
      expect(
        TrackStateMachine.transition(ItemStatus.done, ItemStatus.todo),
        ItemStatus.todo,
      );
    });

    test('throws for invalid transitions', () {
      expect(
        () => TrackStateMachine.transition(
          ItemStatus.done,
          ItemStatus.inProgress,
        ),
        throwsA(isA<InvalidStatusTransitionError>()),
      );
      expect(
        () => TrackStateMachine.transition(ItemStatus.todo, ItemStatus.blocked),
        throwsA(isA<InvalidStatusTransitionError>()),
      );
    });
  });

  group('TrackStateMachine progress', () {
    test('computes milestone progress with skipped items excluded', () {
      expect(
        TrackStateMachine.milestoneProgress(_sampleMilestoneOne),
        closeTo(0.5, 0.0001),
      );
      expect(
        TrackStateMachine.milestoneProgress(_sampleMilestoneTwo),
        closeTo(1, 0.0001),
      );
    });

    test('computes track progress as weighted item completion', () {
      final track = _sampleTrack(
        milestones: [_sampleMilestoneOne, _sampleMilestoneTwo],
      );

      expect(TrackStateMachine.trackProgress(track), closeTo(2 / 3, 0.0001));
    });

    test('returns zero for empty and skipped-only tracks', () {
      final skippedOnly = _sampleTrack(
        milestones: [
          Milestone(
            id: 'skipped-milestone',
            trackId: 'track-skipped',
            name: 'Skipped only',
            objective: 'Optional steps',
            sortOrder: 0,
            status: ItemStatus.skipped,
            actionItems: [
              _item(
                id: 'skipped-item',
                milestoneId: 'skipped-milestone',
                status: ItemStatus.skipped,
              ),
            ],
          ),
        ],
      );

      expect(
        TrackStateMachine.trackProgress(_sampleTrack(milestones: const [])),
        0,
      );
      expect(TrackStateMachine.trackProgress(skippedOnly), 0);
    });
  });

  group('TrackStateMachine.computeTrackStatus', () {
    test('keeps archived and postponed tracks suppressed', () {
      expect(
        TrackStateMachine.computeTrackStatus(
          _sampleTrack(status: TrackStatus.archived),
        ),
        TrackStatus.archived,
      );
      expect(
        TrackStateMachine.computeTrackStatus(
          _sampleTrack(status: TrackStatus.postponed),
        ),
        TrackStatus.postponed,
      );
      expect(TrackStateMachine.isSuppressed(TrackStatus.postponed), isTrue);
      expect(TrackStateMachine.isSuppressed(TrackStatus.active), isFalse);
    });

    test('returns draft when no work has started', () {
      final draftTrack = _sampleTrack(
        status: TrackStatus.draft,
        milestones: [
          Milestone(
            id: 'todo-milestone',
            trackId: 'track-draft',
            name: 'Todo',
            objective: 'Pending',
            sortOrder: 0,
            status: ItemStatus.todo,
            actionItems: [
              _item(
                id: 'todo-item',
                milestoneId: 'todo-milestone',
                status: ItemStatus.todo,
              ),
            ],
          ),
        ],
      );

      expect(
        TrackStateMachine.computeTrackStatus(draftTrack),
        TrackStatus.draft,
      );
    });

    test('returns active once any item has started or been resolved', () {
      expect(
        TrackStateMachine.computeTrackStatus(_sampleTrack()),
        TrackStatus.active,
      );
      expect(
        TrackStateMachine.computeTrackStatus(
          _sampleTrack(
            milestones: [
              Milestone(
                id: 'done-milestone',
                trackId: 'track-active',
                name: 'Started',
                objective: 'Partially done',
                sortOrder: 0,
                status: ItemStatus.done,
                actionItems: [
                  _item(
                    id: 'done-item',
                    milestoneId: 'done-milestone',
                    status: ItemStatus.done,
                  ),
                  _item(
                    id: 'todo-item',
                    milestoneId: 'done-milestone',
                    status: ItemStatus.todo,
                  ),
                ],
              ),
            ],
          ),
        ),
        TrackStatus.active,
      );
    });

    test('returns completed when all items are done or skipped', () {
      final completedTrack = _sampleTrack(
        milestones: [
          Milestone(
            id: 'complete-milestone',
            trackId: 'track-complete',
            name: 'Complete',
            objective: 'All resolved',
            sortOrder: 0,
            status: ItemStatus.done,
            actionItems: [
              _item(
                id: 'done-item',
                milestoneId: 'complete-milestone',
                status: ItemStatus.done,
              ),
              _item(
                id: 'skipped-item',
                milestoneId: 'complete-milestone',
                status: ItemStatus.skipped,
              ),
            ],
          ),
        ],
      );

      expect(
        TrackStateMachine.computeTrackStatus(completedTrack),
        TrackStatus.completed,
      );
    });

    test('returns draft for empty tracks', () {
      expect(
        TrackStateMachine.computeTrackStatus(
          _sampleTrack(milestones: const []),
        ),
        TrackStatus.draft,
      );
    });
  });
}

final _sampleMilestoneOne = Milestone(
  id: 'milestone-1',
  trackId: 'track-1',
  name: 'Phase 1',
  objective: 'Legal verification',
  sortOrder: 0,
  status: ItemStatus.inProgress,
  actionItems: [
    _item(id: 'item-1', milestoneId: 'milestone-1', status: ItemStatus.done),
    _item(id: 'item-2', milestoneId: 'milestone-1', status: ItemStatus.blocked),
  ],
);

final _sampleMilestoneTwo = Milestone(
  id: 'milestone-2',
  trackId: 'track-1',
  name: 'Phase 2',
  objective: 'Agreement checks',
  sortOrder: 1,
  status: ItemStatus.todo,
  actionItems: [
    _item(id: 'item-3', milestoneId: 'milestone-2', status: ItemStatus.skipped),
    _item(id: 'item-4', milestoneId: 'milestone-2', status: ItemStatus.done),
  ],
);

LifeTrack _sampleTrack({
  TrackStatus status = TrackStatus.active,
  List<Milestone>? milestones,
}) {
  return LifeTrack(
    id: 'track-1',
    title: 'Buy Under-Construction Flat',
    category: LifeTrackCategory.realEstate,
    status: status,
    milestones: milestones ?? [_sampleMilestoneOne, _sampleMilestoneTwo],
    createdAt: DateTime.utc(2026, 6, 29, 9),
    updatedAt: DateTime.utc(2026, 6, 29, 12),
    templateId: 'real_estate_under_construction_v1',
  );
}

ActionItem _item({
  required String id,
  required String milestoneId,
  required ItemStatus status,
}) {
  return ActionItem(
    id: id,
    milestoneId: milestoneId,
    summary: id,
    status: status,
    requirements: const [],
    createdAt: DateTime.utc(2026, 6, 29, 10),
    updatedAt: DateTime.utc(2026, 6, 29, 11),
  );
}
