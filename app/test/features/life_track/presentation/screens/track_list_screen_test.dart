import 'dart:async';

import 'package:airo_app/features/life_track/presentation/screens/track_list_screen.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders board mode grouped by status by default', (
    tester,
  ) async {
    final repository = _FakeLifeTrackRepository(_sampleTracks());

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('LifeTrack'), findsOneWidget);
    expect(find.byKey(const ValueKey('life_track_board')), findsOneWidget);
    expect(find.text('Draft'), findsWidgets);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Postponed'), findsWidgets);
    expect(find.text('Flat purchase'), findsOneWidget);
    expect(find.text('MBA admissions'), findsOneWidget);
  });

  testWidgets('switches to list mode', (tester) async {
    final repository = _FakeLifeTrackRepository(_sampleTracks());

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('life_track_list')), findsOneWidget);
    expect(find.byKey(const ValueKey('life_track_board')), findsNothing);
    expect(find.text('Current focus: Registration'), findsOneWidget);
  });

  testWidgets('filters tracks by category chip', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeLifeTrackRepository(_sampleTracks());

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    final financeFilter = find.byKey(
      const ValueKey('life_track_filter_finance'),
    );
    await tester.tap(financeFilter);
    await tester.pumpAndSettle();

    expect(find.text('Budget rescue'), findsOneWidget);
    expect(find.text('Flat purchase'), findsNothing);
    expect(find.text('MBA admissions'), findsNothing);
  });

  testWidgets('postponed tracks render dimmed styling', (tester) async {
    final repository = _FakeLifeTrackRepository(_sampleTracks());

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    final opacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.byKey(const ValueKey('life_track_card_track-postponed')),
        matching: find.byType(Opacity),
      ),
    );

    expect(opacity.opacity, 0.58);
  });

  testWidgets('track actions can postpone and archive cards', (tester) async {
    final repository = _FakeLifeTrackRepository(_sampleTracks());

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    final actions = find.byKey(const ValueKey('life_track_actions_track-1'));
    await tester.ensureVisible(actions);
    await tester.tap(actions);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Postpone').last);
    await tester.pumpAndSettle();

    expect(repository.latestTrack('track-1')?.status, TrackStatus.postponed);
    expect(find.text('Postponed'), findsWidgets);

    await tester.ensureVisible(actions);
    await tester.tap(actions);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();

    expect(repository.latestTrack('track-1')?.status, TrackStatus.archived);
  });
}

Widget _testApp(_FakeLifeTrackRepository repository) {
  return MaterialApp(
    home: TrackListScreen(
      repository: repository,
      ensureInitialized: () async {},
      disposeOwnedResources: false,
    ),
  );
}

class _FakeLifeTrackRepository implements LifeTrackRepository {
  _FakeLifeTrackRepository(List<LifeTrack> seedTracks)
    : _tracks = List<LifeTrack>.from(seedTracks) {
    _controller = StreamController<List<LifeTrack>>.broadcast(
      onListen: () => _controller.add(List<LifeTrack>.from(_tracks)),
    );
  }

  late final StreamController<List<LifeTrack>> _controller;
  final List<LifeTrack> _tracks;

  LifeTrack? latestTrack(String id) {
    for (final track in _tracks) {
      if (track.id == id) return track;
    }
    return null;
  }

  @override
  Future<Result<LifeTrack>> createTrack(LifeTrack track) async {
    _tracks.add(track);
    _controller.add(List<LifeTrack>.from(_tracks));
    return Ok(track);
  }

  @override
  Future<Result<void>> deleteTrack(String id) async {
    _tracks.removeWhere((track) => track.id == id);
    _controller.add(List<LifeTrack>.from(_tracks));
    return const Ok(null);
  }

  @override
  Future<Result<LifeTrack>> getTrack(String id) async {
    final track = latestTrack(id);
    if (track == null) {
      return Err(NotFoundError('track not found'), StackTrace.current);
    }
    return Ok(track);
  }

  @override
  Future<Result<List<LifeTrack>>> listTracks({TrackStatus? status}) async {
    final tracks = status == null
        ? List<LifeTrack>.from(_tracks)
        : _tracks.where((track) => track.status == status).toList();
    return Ok(tracks);
  }

  @override
  Future<Result<void>> saveInputValue(
    String requirementId,
    String value,
  ) async {
    return const Ok(null);
  }

  @override
  Future<Result<void>> updateActionItem(ActionItem item) async =>
      const Ok(null);

  @override
  Future<Result<void>> updateItemStatus(
    String itemId,
    ItemStatus status,
  ) async {
    return const Ok(null);
  }

  @override
  Future<Result<void>> updateMilestone(Milestone milestone) async =>
      const Ok(null);

  @override
  Future<Result<void>> updateTrack(LifeTrack track) async {
    final index = _tracks.indexWhere((existing) => existing.id == track.id);
    if (index == -1) {
      return Err(NotFoundError('track not found'), StackTrace.current);
    }
    _tracks[index] = track;
    _controller.add(List<LifeTrack>.from(_tracks));
    return const Ok(null);
  }

  @override
  Stream<List<LifeTrack>> watchTracks({TrackStatus? status}) {
    if (status == null) {
      return _controller.stream;
    }
    return _controller.stream.map(
      (tracks) => tracks
          .where((track) => track.status == status)
          .toList(growable: false),
    );
  }
}

List<LifeTrack> _sampleTracks() {
  return [
    _track(
      id: 'track-1',
      title: 'Flat purchase',
      category: LifeTrackCategory.realEstate,
      status: TrackStatus.active,
      itemStatuses: const [ItemStatus.done, ItemStatus.inProgress],
      milestoneName: 'Registration',
      objective: 'Book the registration slot',
    ),
    _track(
      id: 'track-2',
      title: 'MBA admissions',
      category: LifeTrackCategory.education,
      status: TrackStatus.draft,
      itemStatuses: const [ItemStatus.todo],
      milestoneName: 'Applications',
      objective: 'Prepare the shortlist',
    ),
    _track(
      id: 'track-finance',
      title: 'Budget rescue',
      category: LifeTrackCategory.finance,
      status: TrackStatus.completed,
      itemStatuses: const [ItemStatus.done, ItemStatus.done],
      milestoneName: 'Freeze subscriptions',
      objective: 'Reduce recurring expenses',
    ),
    _track(
      id: 'track-postponed',
      title: 'Passport renewal',
      category: LifeTrackCategory.travel,
      status: TrackStatus.postponed,
      itemStatuses: const [ItemStatus.todo],
      milestoneName: 'Document prep',
      objective: 'Collect identity proofs',
    ),
  ];
}

LifeTrack _track({
  required String id,
  required String title,
  required LifeTrackCategory category,
  required TrackStatus status,
  required List<ItemStatus> itemStatuses,
  required String milestoneName,
  required String objective,
}) {
  final now = DateTime.utc(2026, 7, 12);
  return LifeTrack(
    id: id,
    title: title,
    category: category,
    status: status,
    milestones: [
      Milestone(
        id: '${id}_milestone',
        trackId: id,
        name: milestoneName,
        objective: objective,
        sortOrder: 0,
        status: itemStatuses.any((status) => status == ItemStatus.inProgress)
            ? ItemStatus.inProgress
            : itemStatuses.every((status) => status == ItemStatus.done)
            ? ItemStatus.done
            : ItemStatus.todo,
        actionItems: [
          for (var i = 0; i < itemStatuses.length; i++)
            ActionItem(
              id: '${id}_item_$i',
              milestoneId: '${id}_milestone',
              summary: 'Task $i',
              status: itemStatuses[i],
              requirements: const [],
              createdAt: now,
              updatedAt: now,
            ),
        ],
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );
}
