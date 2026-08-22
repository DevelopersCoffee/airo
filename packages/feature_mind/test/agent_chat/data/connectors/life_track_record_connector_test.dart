import 'package:core_domain/core_domain.dart';
import 'package:feature_mind/src/agent_chat/data/connectors/life_track_record_connector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeLifeTrackRepository repository;
  late LifeTrackRecordConnector connector;

  setUp(() {
    repository = _FakeLifeTrackRepository();
    connector = LifeTrackRecordConnector(
      repository: repository,
      resolveTemplate: (_) async => _template,
      now: () => DateTime.utc(2026, 8, 21, 9),
      newTrackId: () => 'lt-claim-1',
    );
  });

  test('asks for confirmation before writing', () async {
    final result = await connector.execute({
      'title': 'Niva Bupa reimbursement 9001001',
      'template_id': 'insurance_claim_v1',
      'facts': const {'Claim ID': '9001001', 'Insurer': 'Niva Bupa'},
    });

    expect(result.isError, isTrue);
    expect(result.errorCode, 'confirmation_required');
    expect(repository.tracks, isEmpty);
    expect((result.data['pending'] as Map)['source'], 'user_confirm');
  });

  test('creates a local claim track after user confirmation', () async {
    final result = await connector.execute({
      'title': 'Niva Bupa reimbursement 9001001',
      'template_id': 'insurance_claim_v1',
      'facts': const {
        'Claim ID': '9001001',
        'Insurer': 'Niva Bupa',
        LifeTrackFactPatch.documentsReceivedKey: 'received',
      },
      'confirmed': true,
      'source': 'user_confirm',
    });

    expect(result.isError, isFalse);
    expect(result.data['created'], isTrue);
    expect(repository.tracks, hasLength(1));
    final track = repository.tracks.single;
    expect(track.id, 'lt-claim-1');
    expect(track.templateId, 'insurance_claim_v1');
    expect(
      const LifeTrackFactPatch().requirementValue(track, 'Claim ID'),
      '9001001',
    );
    expect(
      const LifeTrackFactPatch().requirementValue(track, 'Discharge Summary'),
      'received',
    );
  });

  test('updates an existing track with the same claim id', () async {
    await connector.execute({
      'title': 'Niva Bupa reimbursement 9001001',
      'template_id': 'insurance_claim_v1',
      'facts': const {'Claim ID': '9001001'},
      'confirmed': true,
      'source': 'user_confirm',
    });

    final result = await connector.execute({
      'title': 'Niva Bupa reimbursement 9001001',
      'template_id': 'insurance_claim_v1',
      'facts': const {'Follow-up Log': 'Missed call from claims team.'},
      'confirmed': true,
      'source': 'user_confirm',
    });

    expect(result.data['created'], isFalse);
    expect(repository.tracks, hasLength(1));
    expect(
      const LifeTrackFactPatch().requirementValue(
        repository.tracks.single,
        'Follow-up Log',
      ),
      'Missed call from claims team.',
    );
  });
}

const _template = LifeTrackTemplate(
  templateId: 'insurance_claim_v1',
  title: 'Insurance Claim Tracking Template',
  description: 'Test',
  category: LifeTrackCategory.insurance,
  version: '1.1',
  milestones: [
    MilestoneTemplate(
      name: 'Phase 1: Policy & Incident',
      objective: 'Record the policy',
      tasks: [
        ActionItemTemplate(
          summary: 'Record policy details',
          requirements: [
            InputRequirementTemplate(
              label: 'Insurer',
              type: FieldType.text,
              isRequired: true,
            ),
          ],
        ),
      ],
    ),
    MilestoneTemplate(
      name: 'Phase 2: Claim Filing',
      objective: 'Store claim identifiers',
      tasks: [
        ActionItemTemplate(
          summary: 'Record claim references',
          requirements: [
            InputRequirementTemplate(
              label: 'Claim ID',
              type: FieldType.text,
              isRequired: true,
            ),
          ],
        ),
      ],
    ),
    MilestoneTemplate(
      name: 'Phase 3: Follow-up',
      objective: 'Track documents',
      tasks: [
        ActionItemTemplate(
          summary: 'Collect required documents',
          requirements: [
            InputRequirementTemplate(
              label: 'Discharge Summary',
              type: FieldType.document,
              isRequired: true,
            ),
          ],
        ),
        ActionItemTemplate(
          summary: 'Log insurer follow-up requests',
          requirements: [
            InputRequirementTemplate(
              label: 'Follow-up Log',
              type: FieldType.text,
              isRequired: true,
            ),
          ],
        ),
      ],
    ),
  ],
);

class _FakeLifeTrackRepository implements LifeTrackRepository {
  final List<LifeTrack> tracks = [];

  @override
  Future<Result<List<LifeTrack>>> listTracks({TrackStatus? status}) async =>
      Ok(List<LifeTrack>.from(tracks));

  @override
  Future<Result<LifeTrack>> createTrack(LifeTrack track) async {
    tracks.add(track);
    return Ok(track);
  }

  @override
  Future<Result<void>> deleteTrack(String id) async => const Ok(null);

  @override
  Future<Result<LifeTrack>> getTrack(String id) async =>
      Ok(tracks.firstWhere((track) => track.id == id));

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
    final index = tracks.indexWhere((item) => item.id == track.id);
    if (index >= 0) tracks[index] = track;
    return const Ok(null);
  }

  @override
  Stream<List<LifeTrack>> watchTracks({TrackStatus? status}) =>
      Stream.value(tracks);
}
