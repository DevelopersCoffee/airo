import 'package:core_data/src/storage/life_track_local_data_source.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseFactory databaseFactory;
  late LifeTrackLocalDataSource dataSource;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    dataSource = LifeTrackLocalDataSource(
      databaseFactory: databaseFactory,
      databasePath: inMemoryDatabasePath,
    );
    await dataSource.initialize();
  });

  tearDown(() async {
    await dataSource.close();
  });

  test('creates and hydrates a full LifeTrack graph', () async {
    final track = _sampleTrack();

    await dataSource.createTrack(track);
    final stored = await dataSource.getTrack(track.id);

    expect(stored, isNotNull);
    expect(stored, track);
    expect(stored!.progress, closeTo(2 / 3, 0.0001));
  });

  test('filters tracks by status', () async {
    await dataSource.createTrack(_sampleTrack());
    await dataSource.createTrack(
      _sampleTrack(id: 'track-2').copyWith(status: TrackStatus.completed),
    );

    final active = await dataSource.listTracks(status: TrackStatus.active);
    final completed = await dataSource.listTracks(
      status: TrackStatus.completed,
    );

    expect(active, hasLength(1));
    expect(completed.single.id, 'track-2');
  });

  test('watchTracks emits after mutation', () async {
    final stream = dataSource.watchTracks();
    final nextNonEmpty = stream.firstWhere((tracks) => tracks.isNotEmpty);

    await dataSource.createTrack(_sampleTrack());
    final emitted = await nextNonEmpty;

    expect(emitted.single.id, 'track-1');
  });

  test('cascade delete removes nested rows', () async {
    final track = _sampleTrack();
    await dataSource.createTrack(track);

    await dataSource.deleteTrack(track.id);

    expect(await dataSource.getTrack(track.id), isNull);
    expect(await dataSource.listTracks(), isEmpty);
  });

  test('batch hydrate inserts 50 items under performance budget', () async {
    final milestone = Milestone(
      id: 'milestone-batch',
      trackId: 'track-batch',
      name: 'Batch',
      objective: 'Perf',
      sortOrder: 0,
      status: ItemStatus.todo,
      actionItems: List.generate(
        50,
        (index) => ActionItem(
          id: 'item-$index',
          milestoneId: 'milestone-batch',
          summary: 'Item $index',
          status: ItemStatus.todo,
          requirements: const [],
          createdAt: DateTime.utc(2026, 6, 29),
          updatedAt: DateTime.utc(2026, 6, 29),
        ),
      ),
    );
    final track = LifeTrack(
      id: 'track-batch',
      title: 'Batch Track',
      category: LifeTrackCategory.custom,
      status: TrackStatus.active,
      milestones: [milestone],
      createdAt: DateTime.utc(2026, 6, 29),
      updatedAt: DateTime.utc(2026, 6, 29),
    );

    final stopwatch = Stopwatch()..start();
    await dataSource.hydrateTemplate(track);
    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, lessThan(100));
  });
}

LifeTrack _sampleTrack({String id = 'track-1'}) {
  final suffix = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  final requirement = InputRequirement(
    id: 'req_$suffix',
    actionItemId: 'item1_$suffix',
    label: 'Document',
    fieldType: FieldType.document,
    isRequired: true,
  );
  final first = ActionItem(
    id: 'item1_$suffix',
    milestoneId: 'milestone1_$suffix',
    summary: 'Check docs',
    status: ItemStatus.done,
    requirements: [requirement],
    createdAt: DateTime.utc(2026, 6, 29, 9),
    updatedAt: DateTime.utc(2026, 6, 29, 10),
  );
  final second = ActionItem(
    id: 'item2_$suffix',
    milestoneId: 'milestone1_$suffix',
    summary: 'Call bank',
    status: ItemStatus.blocked,
    requirements: const [],
    createdAt: DateTime.utc(2026, 6, 29, 9),
    updatedAt: DateTime.utc(2026, 6, 29, 10),
  );
  final skipped = ActionItem(
    id: 'item3_$suffix',
    milestoneId: 'milestone2_$suffix',
    summary: 'Optional',
    status: ItemStatus.skipped,
    requirements: const [],
    createdAt: DateTime.utc(2026, 6, 29, 9),
    updatedAt: DateTime.utc(2026, 6, 29, 10),
  );
  final done = ActionItem(
    id: 'item4_$suffix',
    milestoneId: 'milestone2_$suffix',
    summary: 'Collect copy',
    status: ItemStatus.done,
    requirements: const [],
    createdAt: DateTime.utc(2026, 6, 29, 9),
    updatedAt: DateTime.utc(2026, 6, 29, 10),
  );

  return LifeTrack(
    id: id,
    title: 'LifeTrack',
    category: LifeTrackCategory.realEstate,
    status: TrackStatus.active,
    milestones: [
      Milestone(
        id: 'milestone1_$suffix',
        trackId: id,
        name: 'Phase 1',
        objective: 'Verify',
        sortOrder: 0,
        status: ItemStatus.inProgress,
        actionItems: [first, second],
      ),
      Milestone(
        id: 'milestone2_$suffix',
        trackId: id,
        name: 'Phase 2',
        objective: 'Close',
        sortOrder: 1,
        status: ItemStatus.todo,
        actionItems: [skipped, done],
      ),
    ],
    createdAt: DateTime.utc(2026, 6, 29, 8),
    updatedAt: DateTime.utc(2026, 6, 29, 11),
  );
}
