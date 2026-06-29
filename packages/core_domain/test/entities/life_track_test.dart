import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final requirement = InputRequirement(
    id: 'req-1',
    actionItemId: 'item-1',
    label: 'Commencement Certificate PDF',
    fieldType: FieldType.document,
    value: null,
    isRequired: true,
    hint: 'Upload the latest certificate',
  );

  final actionItem = ActionItem(
    id: 'item-1',
    milestoneId: 'milestone-1',
    summary: 'Check Builder RERA Registration',
    description: 'Verify the builder on MahaRERA.',
    status: ItemStatus.done,
    requirements: [requirement],
    dueDate: DateTime.utc(2026, 7, 1),
    notes: 'Verified successfully',
    createdAt: DateTime.utc(2026, 6, 29, 10),
    updatedAt: DateTime.utc(2026, 6, 29, 11),
  );

  final blockedItem = ActionItem(
    id: 'item-2',
    milestoneId: 'milestone-1',
    summary: 'Check lender list',
    status: ItemStatus.blocked,
    requirements: const [],
    createdAt: DateTime.utc(2026, 6, 29, 10),
    updatedAt: DateTime.utc(2026, 6, 29, 11),
  );

  final skippedItem = ActionItem(
    id: 'item-3',
    milestoneId: 'milestone-2',
    summary: 'Optional paperwork',
    status: ItemStatus.skipped,
    requirements: const [],
    createdAt: DateTime.utc(2026, 6, 29, 10),
    updatedAt: DateTime.utc(2026, 6, 29, 11),
  );

  final secondDoneItem = ActionItem(
    id: 'item-4',
    milestoneId: 'milestone-2',
    summary: 'Collect agreement copy',
    status: ItemStatus.done,
    requirements: const [],
    createdAt: DateTime.utc(2026, 6, 29, 10),
    updatedAt: DateTime.utc(2026, 6, 29, 11),
  );

  final milestoneOne = Milestone(
    id: 'milestone-1',
    trackId: 'track-1',
    name: 'Phase 1',
    objective: 'Legal verification',
    sortOrder: 1,
    status: ItemStatus.inProgress,
    actionItems: [actionItem, blockedItem],
  );

  final milestoneTwo = Milestone(
    id: 'milestone-2',
    trackId: 'track-1',
    name: 'Phase 2',
    objective: 'Agreement checks',
    sortOrder: 2,
    status: ItemStatus.todo,
    actionItems: [skippedItem, secondDoneItem],
  );

  final track = LifeTrack(
    id: 'track-1',
    title: 'Buy Under-Construction Flat',
    category: LifeTrackCategory.realEstate,
    status: TrackStatus.active,
    milestones: [milestoneOne, milestoneTwo],
    createdAt: DateTime.utc(2026, 6, 29, 9),
    updatedAt: DateTime.utc(2026, 6, 29, 12),
    templateId: 'real_estate_under_construction_v1',
  );

  group('LifeTrack entities', () {
    test('round-trips nested entity JSON', () {
      final encoded = track.toJson();
      final decoded = LifeTrack.fromJson(encoded);

      expect(decoded, track);
      expect(
        decoded.milestones.first.actionItems.first.requirements.first,
        requirement,
      );
    });

    test('computes milestone progress with skipped items excluded', () {
      expect(milestoneOne.progress, 0.5);
      expect(milestoneTwo.progress, 1.0);
    });

    test('computes track progress as weighted item completion', () {
      expect(track.progress, closeTo(2 / 3, 0.0001));
    });

    test(
      'returns zero progress for empty milestones and skipped-only milestones',
      () {
        const emptyMilestone = Milestone(
          id: 'm-empty',
          trackId: 'track-empty',
          name: 'Empty',
          objective: 'Nothing yet',
          sortOrder: 0,
          status: ItemStatus.todo,
          actionItems: [],
        );
        final skippedOnly = Milestone(
          id: 'm-skipped',
          trackId: 'track-empty',
          name: 'Skipped',
          objective: 'All optional',
          sortOrder: 1,
          status: ItemStatus.skipped,
          actionItems: [skippedItem],
        );
        final emptyTrack = LifeTrack(
          id: 'track-empty',
          title: 'Empty Track',
          category: LifeTrackCategory.custom,
          status: TrackStatus.draft,
          milestones: const [],
          createdAt: DateTime.utc(2026, 6, 29),
          updatedAt: DateTime.utc(2026, 6, 29),
        );

        expect(emptyMilestone.progress, 0);
        expect(skippedOnly.progress, 0);
        expect(emptyTrack.progress, 0);
      },
    );

    test('copyWith preserves and replaces selected fields', () {
      final updated = track.copyWith(
        title: 'Updated title',
        status: TrackStatus.completed,
      );

      expect(updated.title, 'Updated title');
      expect(updated.status, TrackStatus.completed);
      expect(updated.milestones, track.milestones);
      expect(updated.templateId, track.templateId);
    });
  });
}
