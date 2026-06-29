import 'package:core_data/src/repositories/life_track_repository_impl.dart';
import 'package:core_data/src/storage/life_track_local_data_source.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LifeTrackLocalDataSource dataSource;
  late LifeTrackRepositoryImpl repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    dataSource = LifeTrackLocalDataSource(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    await dataSource.initialize();
    repository = LifeTrackRepositoryImpl(localDataSource: dataSource);
  });

  tearDown(() async {
    await dataSource.close();
  });

  test('returns not found error for missing track', () async {
    final result = await repository.getTrack('missing');

    expect(result.isErr, isTrue);
    expect(result.getErrorOrNull(), isA<NotFoundError>());
  });

  test('creates, lists, updates, and watches tracks', () async {
    final track = LifeTrack(
      id: 'track-1',
      title: 'Track',
      category: LifeTrackCategory.finance,
      status: TrackStatus.draft,
      milestones: const [],
      createdAt: DateTime.utc(2026, 6, 29),
      updatedAt: DateTime.utc(2026, 6, 29),
    );

    final created = await repository.createTrack(track);
    expect(created.value.id, 'track-1');

    final listed = await repository.listTracks();
    expect(listed.value, hasLength(1));

    final watched = repository.watchTracks();
    final updatedTrack = track.copyWith(title: 'Updated');
    await repository.updateTrack(updatedTrack);
    final values = await watched.firstWhere(
      (items) => items.any((item) => item.title == 'Updated'),
    );

    expect(values.single.title, 'Updated');
  });
}
