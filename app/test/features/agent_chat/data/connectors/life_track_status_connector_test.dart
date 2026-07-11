import 'package:airo_app/features/agent_chat/data/connectors/life_track_status_connector.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LifeTrackStatusFormatter', () {
    test('formats active track status as deterministic markdown table', () {
      final track = _track(
        title: 'Flat purchase',
        category: LifeTrackCategory.realEstate,
        status: TrackStatus.active,
        milestones: [
          _milestone(
            name: 'Documents',
            items: [
              _item(
                summary: 'Upload sale agreement',
                status: ItemStatus.todo,
                dueDate: DateTime.utc(2026, 7, 20),
                requirements: [_document('Sale agreement', value: null)],
              ),
              _item(summary: 'Pay booking amount', status: ItemStatus.done),
            ],
          ),
        ],
      );

      final result = LifeTrackStatusFormatter().format(
        query: 'what is pending on my flat track?',
        tracks: [track],
      );

      expect(result.matchedTracks, ['track-flat-purchase']);
      expect(result.markdown, contains('LifeTrack status for Flat purchase'));
      expect(
        result.markdown,
        contains(
          '| Documents | Upload sale agreement | todo | 2026-07-20 | Sale agreement |',
        ),
      );
      expect(result.markdown, isNot(contains('Pay booking amount')));
      expect(result.data['pending_count'], 1);
    });

    test('lists required documents for car goal queries', () {
      final track = _track(
        title: 'Car purchase',
        category: LifeTrackCategory.carPurchase,
        milestones: [
          _milestone(
            name: 'RTO',
            items: [
              _item(
                summary: 'Prepare registration file',
                requirements: [
                  _document('Driving licence', value: ''),
                  _document('Insurance policy', value: 'policy.pdf'),
                ],
              ),
            ],
          ),
        ],
      );

      final result = LifeTrackStatusFormatter().format(
        query: 'what driving documents do I need for my car goal?',
        tracks: [track],
      );

      expect(
        result.markdown,
        contains('| Driving licence | missing | Prepare registration file |'),
      );
      expect(
        result.markdown,
        contains('| Insurance policy | provided | Prepare registration file |'),
      );
      expect(result.markdown, isNot(contains('policy.pdf')));
    });

    test('suppresses postponed tracks from proactive summaries', () {
      final active = _track(title: 'Flat purchase');
      final postponed = _track(
        title: 'Medical checkup',
        status: TrackStatus.postponed,
      );

      final result = LifeTrackStatusFormatter().proactiveSummary([
        active,
        postponed,
      ]);

      expect(result, contains('Flat purchase'));
      expect(result, isNot(contains('Medical checkup')));
    });

    test('returns explicit no-match message instead of hallucinating', () {
      final result = LifeTrackStatusFormatter().format(
        query: 'what is pending on my passport track?',
        tracks: [_track(title: 'Flat purchase')],
      );

      expect(result.matchedTracks, isEmpty);
      expect(
        result.markdown,
        contains('I could not find a LifeTrack matching "passport"'),
      );
      expect(result.data['matched_tracks'], isEmpty);
    });
  });

  group('LifeTrackStatusConnector', () {
    test('queries repository and returns formatter data locally', () async {
      final repository = _FakeLifeTrackRepository([
        _track(title: 'Flat purchase'),
      ]);
      final connector = LifeTrackStatusConnector(repository: repository);

      final result = await connector.execute({
        'query': 'what is pending on my flat track?',
      });

      expect(result.isError, false);
      expect(result.data['source'], 'local_lifetrack_repository');
      expect(result.data['markdown'], contains('Flat purchase'));
      expect(repository.listTracksCalls, 1);
    });
  });
}

LifeTrack _track({
  required String title,
  LifeTrackCategory category = LifeTrackCategory.realEstate,
  TrackStatus status = TrackStatus.active,
  List<Milestone>? milestones,
}) {
  final id =
      'track-${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '')}';
  return LifeTrack(
    id: id,
    title: title,
    category: category,
    status: status,
    milestones:
        milestones ??
        [
          _milestone(
            name: 'Next steps',
            items: [_item(summary: 'Confirm documents')],
          ),
        ],
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 2),
  );
}

Milestone _milestone({required String name, required List<ActionItem> items}) {
  return Milestone(
    id: 'milestone-${name.toLowerCase().replaceAll(' ', '-')}',
    trackId: 'track-id',
    name: name,
    objective: '',
    sortOrder: 0,
    status: ItemStatus.todo,
    actionItems: items,
  );
}

ActionItem _item({
  required String summary,
  ItemStatus status = ItemStatus.todo,
  DateTime? dueDate,
  List<InputRequirement> requirements = const [],
}) {
  return ActionItem(
    id: 'item-${summary.toLowerCase().replaceAll(' ', '-')}',
    milestoneId: 'milestone-id',
    summary: summary,
    status: status,
    requirements: requirements,
    dueDate: dueDate,
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 2),
  );
}

InputRequirement _document(String label, {String? value}) {
  return InputRequirement(
    id: 'req-${label.toLowerCase().replaceAll(' ', '-')}',
    actionItemId: 'item-id',
    label: label,
    fieldType: FieldType.document,
    value: value,
    isRequired: true,
  );
}

class _FakeLifeTrackRepository implements LifeTrackRepository {
  _FakeLifeTrackRepository(this.tracks);

  final List<LifeTrack> tracks;
  int listTracksCalls = 0;

  @override
  Future<Result<List<LifeTrack>>> listTracks({TrackStatus? status}) async {
    listTracksCalls++;
    return Ok(
      tracks
          .where((track) => status == null || track.status == status)
          .toList(),
    );
  }

  @override
  Future<Result<LifeTrack>> createTrack(LifeTrack track) async => Ok(track);

  @override
  Future<Result<void>> deleteTrack(String id) async => const Ok(null);

  @override
  Future<Result<LifeTrack>> getTrack(String id) async => Ok(tracks.first);

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
  Future<Result<void>> updateTrack(LifeTrack track) async => const Ok(null);

  @override
  Stream<List<LifeTrack>> watchTracks({TrackStatus? status}) =>
      Stream.value(tracks);
}
