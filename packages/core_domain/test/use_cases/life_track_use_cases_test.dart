import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LifeTrack use cases', () {
    late _FakeLifeTrackRepository repository;

    setUp(() {
      repository = _FakeLifeTrackRepository(_sampleTrack());
    });

    test('CreateTrackUseCase delegates to the repository', () async {
      final useCase = CreateTrackUseCase(repository);
      final track = _sampleTrack(id: 'new-track');

      final result = await useCase(track);

      expect(result.value.id, 'new-track');
      expect(repository.createdTrack, track);
    });

    test(
      'ListTracksUseCase filters by category after repository status query',
      () async {
        repository.tracks = [
          _sampleTrack(
            id: 'real-estate',
            category: LifeTrackCategory.realEstate,
          ),
          _sampleTrack(id: 'finance', category: LifeTrackCategory.finance),
        ];
        final useCase = ListTracksUseCase(repository);

        final result = await useCase(
          const ListTracksQuery(
            status: TrackStatus.active,
            category: LifeTrackCategory.finance,
          ),
        );

        expect(repository.lastListedStatus, TrackStatus.active);
        expect(result.value.map((track) => track.id), ['finance']);
      },
    );

    test('GetTrackDetailUseCase returns the hydrated track', () async {
      final useCase = GetTrackDetailUseCase(repository);

      final result = await useCase('track-1');

      expect(result.value.milestones.single.actionItems, hasLength(2));
    });

    test(
      'UpdateItemStatusUseCase rewrites the track with recomputed statuses',
      () async {
        final useCase = UpdateItemStatusUseCase(repository);

        final result = await useCase(
          const UpdateItemStatusCommand(
            trackId: 'track-1',
            itemId: 'item-2',
            status: ItemStatus.done,
          ),
        );

        final updatedTrack = result.value;
        expect(updatedTrack.status, TrackStatus.completed);
        expect(updatedTrack.milestones.single.status, ItemStatus.done);
        expect(
          updatedTrack.milestones.single.actionItems.map((item) => item.status),
          [ItemStatus.done, ItemStatus.done],
        );
        expect(repository.updatedTrack, isNotNull);
        expect(
          repository.updatedTrack!.updatedAt,
          isNot(_sampleTrack().updatedAt),
        );
      },
    );

    test('UpdateItemStatusUseCase rejects invalid transitions', () async {
      final useCase = UpdateItemStatusUseCase(repository);

      final result = await useCase(
        const UpdateItemStatusCommand(
          trackId: 'track-1',
          itemId: 'item-1',
          status: ItemStatus.inProgress,
        ),
      );

      expect(result, isA<Err<LifeTrack>>());
      expect(
        (result as Err<LifeTrack>).error,
        isA<InvalidStatusTransitionError>(),
      );
    });

    test(
      'UpdateItemStatusUseCase returns not found when the item is missing',
      () async {
        final useCase = UpdateItemStatusUseCase(repository);

        final result = await useCase(
          const UpdateItemStatusCommand(
            trackId: 'track-1',
            itemId: 'missing-item',
            status: ItemStatus.done,
          ),
        );

        expect(result, isA<Err<LifeTrack>>());
        expect((result as Err<LifeTrack>).error, isA<NotFoundError>());
      },
    );

    test(
      'SaveInputValueUseCase serializes scalar and document values',
      () async {
        final useCase = SaveInputValueUseCase(repository);

        await useCase(
          const SaveInputValueCommand(
            requirementId: 'req-text',
            value: '/tmp/contract.pdf',
          ),
        );
        expect(repository.savedValues['req-text'], '/tmp/contract.pdf');

        await useCase(
          SaveInputValueCommand(
            requirementId: 'req-date',
            value: DateTime.utc(2026, 7, 2, 8, 30),
          ),
        );
        expect(repository.savedValues['req-date'], '2026-07-02T08:30:00.000Z');

        await useCase(
          const SaveInputValueCommand(
            requirementId: 'req-files',
            value: ['/tmp/a.pdf', '/tmp/b.pdf'],
          ),
        );
        expect(
          repository.savedValues['req-files'],
          '["/tmp/a.pdf","/tmp/b.pdf"]',
        );
      },
    );
  });
}

class _FakeLifeTrackRepository implements LifeTrackRepository {
  _FakeLifeTrackRepository(LifeTrack seedTrack) : _track = seedTrack {
    tracks = [seedTrack];
  }

  LifeTrack _track;
  List<LifeTrack> tracks = const [];
  LifeTrack? createdTrack;
  LifeTrack? updatedTrack;
  TrackStatus? lastListedStatus;
  final Map<String, String> savedValues = {};

  @override
  Future<Result<LifeTrack>> createTrack(LifeTrack track) async {
    createdTrack = track;
    _track = track;
    tracks = [track];
    return Ok(track);
  }

  @override
  Future<Result<void>> deleteTrack(String id) async => const Ok(null);

  @override
  Future<Result<LifeTrack>> getTrack(String id) async => Ok(_track);

  @override
  Future<Result<List<LifeTrack>>> listTracks({TrackStatus? status}) async {
    lastListedStatus = status;
    if (status == null) {
      return Ok(tracks);
    }
    return Ok(
      tracks.where((track) => track.status == status).toList(growable: false),
    );
  }

  @override
  Future<Result<void>> saveInputValue(
    String requirementId,
    String value,
  ) async {
    savedValues[requirementId] = value;
    return const Ok(null);
  }

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
    updatedTrack = track;
    _track = track;
    tracks = [track];
    return const Ok(null);
  }

  @override
  Stream<List<LifeTrack>> watchTracks({TrackStatus? status}) async* {
    yield tracks;
  }
}

LifeTrack _sampleTrack({
  String id = 'track-1',
  LifeTrackCategory category = LifeTrackCategory.realEstate,
}) {
  return LifeTrack(
    id: id,
    title: 'Flat Purchase',
    category: category,
    status: TrackStatus.active,
    milestones: [
      Milestone(
        id: 'milestone-1',
        trackId: id,
        name: 'Verification',
        objective: 'Finish all checks',
        sortOrder: 0,
        status: ItemStatus.inProgress,
        actionItems: [
          ActionItem(
            id: 'item-1',
            milestoneId: 'milestone-1',
            summary: 'RERA check',
            status: ItemStatus.done,
            requirements: const [
              InputRequirement(
                id: 'req-1',
                actionItemId: 'item-1',
                label: 'Upload proof',
                fieldType: FieldType.document,
                isRequired: true,
              ),
            ],
            createdAt: DateTime.utc(2026, 6, 29, 9),
            updatedAt: DateTime.utc(2026, 6, 29, 10),
          ),
          ActionItem(
            id: 'item-2',
            milestoneId: 'milestone-1',
            summary: 'Loan approval',
            status: ItemStatus.inProgress,
            requirements: const [],
            createdAt: DateTime.utc(2026, 6, 29, 9),
            updatedAt: DateTime.utc(2026, 6, 29, 10),
          ),
        ],
      ),
    ],
    createdAt: DateTime.utc(2026, 6, 29, 8),
    updatedAt: DateTime.utc(2026, 6, 29, 11),
  );
}
