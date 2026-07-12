import 'dart:async';

import 'package:airo_app/features/life_track/presentation/screens/track_detail_screen.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders milestones and action item tiles', (tester) async {
    final repository = _FakeLifeTrackRepository(_sampleTrack());

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Flat purchase'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('life_track_milestone_m1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('life_track_item_item-docs')),
      findsOneWidget,
    );
    expect(find.text('Gather documents'), findsOneWidget);
  });

  testWidgets('updates an action item status', (tester) async {
    final repository = _FakeLifeTrackRepository(_sampleTrack());

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('life_track_status_item-docs_done')),
    );
    await tester.pumpAndSettle();

    expect(repository.itemStatuses['item-docs'], ItemStatus.done);
  });

  testWidgets('renders field types and saves text or toggle values', (
    tester,
  ) async {
    final repository = _FakeLifeTrackRepository(_sampleTrack());

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('life_track_input_req-text')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('life_track_date_req-date')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('life_track_document_req-doc')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('life_track_bool_req-bool')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('life_track_input_req-number')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('life_track_input_req-text')),
      'Booked the registrar',
    );
    await tester.tap(find.byKey(const ValueKey('life_track_save_req-text')));
    await tester.pumpAndSettle();

    expect(repository.savedValues['req-text'], 'Booked the registrar');

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('life_track_bool_req-bool')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('life_track_bool_req-bool')));
    await tester.pumpAndSettle();

    expect(repository.savedValues['req-bool'], 'true');
  });

  testWidgets('uses injected document and date pickers', (tester) async {
    final repository = _FakeLifeTrackRepository(_sampleTrack());

    await tester.pumpWidget(
      MaterialApp(
        home: TrackDetailScreen(
          trackId: 'track-1',
          repository: repository,
          ensureInitialized: () async {},
          disposeOwnedResources: false,
          pickDocument: () async => '/tmp/title-deed.pdf',
          pickDate: (_, _) async => DateTime.utc(2026, 7, 20),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('life_track_document_req-doc')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('life_track_document_req-doc')));
    await tester.pumpAndSettle();
    expect(repository.savedValues['req-doc'], '/tmp/title-deed.pdf');

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('life_track_date_req-date')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('life_track_date_req-date')));
    await tester.pumpAndSettle();
    expect(
      repository.savedValues['req-date'],
      DateTime.utc(2026, 7, 20).toIso8601String(),
    );
  });
}

Widget _testApp(_FakeLifeTrackRepository repository) {
  return MaterialApp(
    home: TrackDetailScreen(
      trackId: 'track-1',
      repository: repository,
      ensureInitialized: () async {},
      disposeOwnedResources: false,
    ),
  );
}

class _FakeLifeTrackRepository implements LifeTrackRepository {
  _FakeLifeTrackRepository(this._track) {
    _controller = StreamController<List<LifeTrack>>.broadcast(
      onListen: () => _controller.add([_track]),
    );
  }

  LifeTrack _track;
  late final StreamController<List<LifeTrack>> _controller;
  final Map<String, ItemStatus> itemStatuses = {};
  final Map<String, String> savedValues = {};

  @override
  Future<Result<LifeTrack>> createTrack(LifeTrack track) async => Ok(track);

  @override
  Future<Result<void>> deleteTrack(String id) async => const Ok(null);

  @override
  Future<Result<LifeTrack>> getTrack(String id) async => Ok(_track);

  @override
  Future<Result<List<LifeTrack>>> listTracks({TrackStatus? status}) async =>
      Ok([_track]);

  @override
  Future<Result<void>> saveInputValue(
    String requirementId,
    String value,
  ) async {
    savedValues[requirementId] = value;
    _track = _track.copyWith(
      milestones: _track.milestones
          .map(
            (milestone) => milestone.copyWith(
              actionItems: milestone.actionItems
                  .map(
                    (item) => item.copyWith(
                      requirements: item.requirements
                          .map(
                            (requirement) => requirement.id == requirementId
                                ? requirement.copyWith(value: value)
                                : requirement,
                          )
                          .toList(growable: false),
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
    _controller.add([_track]);
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
    itemStatuses[itemId] = status;
    _track = _track.copyWith(
      milestones: _track.milestones
          .map(
            (milestone) => milestone.copyWith(
              actionItems: milestone.actionItems
                  .map(
                    (item) => item.id == itemId
                        ? item.copyWith(status: status)
                        : item,
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
    _controller.add([_track]);
    return const Ok(null);
  }

  @override
  Future<Result<void>> updateMilestone(Milestone milestone) async =>
      const Ok(null);

  @override
  Future<Result<void>> updateTrack(LifeTrack track) async => const Ok(null);

  @override
  Stream<List<LifeTrack>> watchTracks({TrackStatus? status}) =>
      _controller.stream;
}

LifeTrack _sampleTrack() {
  final now = DateTime.utc(2026, 7, 12);
  return LifeTrack(
    id: 'track-1',
    title: 'Flat purchase',
    category: LifeTrackCategory.realEstate,
    status: TrackStatus.active,
    milestones: [
      Milestone(
        id: 'm1',
        trackId: 'track-1',
        name: 'Registration',
        objective: 'Complete legal paperwork',
        sortOrder: 0,
        status: ItemStatus.inProgress,
        actionItems: [
          ActionItem(
            id: 'item-docs',
            milestoneId: 'm1',
            summary: 'Gather documents',
            description: 'Upload the required proofs and confirm the date.',
            status: ItemStatus.inProgress,
            requirements: const [
              InputRequirement(
                id: 'req-text',
                actionItemId: 'item-docs',
                label: 'Registrar notes',
                fieldType: FieldType.text,
                isRequired: true,
              ),
              InputRequirement(
                id: 'req-date',
                actionItemId: 'item-docs',
                label: 'Registration date',
                fieldType: FieldType.date,
                isRequired: true,
              ),
              InputRequirement(
                id: 'req-doc',
                actionItemId: 'item-docs',
                label: 'Title deed',
                fieldType: FieldType.document,
                isRequired: true,
              ),
              InputRequirement(
                id: 'req-bool',
                actionItemId: 'item-docs',
                label: 'All signatures collected',
                fieldType: FieldType.boolean,
                isRequired: false,
              ),
              InputRequirement(
                id: 'req-number',
                actionItemId: 'item-docs',
                label: 'Stamp duty amount',
                fieldType: FieldType.number,
                isRequired: false,
              ),
            ],
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
