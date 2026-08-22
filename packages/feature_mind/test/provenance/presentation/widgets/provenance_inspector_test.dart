import 'package:feature_mind/src/provenance/domain/models/extracted_entity.dart';
import 'package:feature_mind/src/provenance/domain/services/entity_extractor.dart';
import 'package:feature_mind/src/provenance/presentation/widgets/provenance_inspector.dart';
import 'package:feature_mind/src/runtime/models/capability_models.dart';
import 'package:feature_mind/src/runtime/models/context_models.dart';
import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:feature_mind/src/runtime/models/projection_models.dart';
import 'package:feature_mind/src/runtime/ports/context_port.dart';
import 'package:feature_mind/src/runtime/ports/operation_log_port.dart';
import 'package:feature_mind/src/runtime/ports/projection_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _op = MindOp(
  sequence: 12481,
  kind: MindOpKind.automation,
  title: 'Ibuprofen 400 mg logged',
  contextId: 'kneesurgery2026',
  deviceName: 'Pixel 9 Pro',
  // Stored as unverified so the "not assumed" tests can prove the panel
  // re-checks rather than trusting this value.
  signature: SignatureState.unverified,
  recordedAtMs: 0,
  detail: 'Dr. Rao logged the dose on 14 Aug.',
);

const _knee = MindContext(
  id: 'kneesurgery2026',
  label: '#KneeSurgery2026',
  itemCount: 38,
  opCount: 1204,
  openedAtMs: 0,
  safetyClass: CapabilitySafetyClass.health,
);

const _tax = MindContext(
  id: 'q3taxfiling',
  label: '#Q3TaxFiling',
  itemCount: 52,
  opCount: 918,
  openedAtMs: 0,
  safetyClass: CapabilitySafetyClass.financial,
);

class _FakeLog implements OperationLogPort {
  _FakeLog({this.ops = const [_op], this.verifiedAs = SignatureState.verified});

  final List<MindOp> ops;
  final SignatureState verifiedAs;
  static const List<double> replayFrames = [0.5, 1.0];

  @override
  Future<int> count() async => ops.length;

  @override
  Future<List<MindOp>> range({required int offset, required int limit}) async =>
      ops.skip(offset).take(limit).toList(growable: false);

  @override
  Future<MindOp?> bySequence(int sequence) async {
    for (final op in ops) {
      if (op.sequence == sequence) return op;
    }
    return null;
  }

  @override
  Future<int> append({
    required MindOpKind kind,
    required String title,
    required String contextId,
    String detail = '',
  }) async => 0;

  @override
  Future<SignatureState> verify(int sequence) async => verifiedAs;

  @override
  Stream<double> replayFrom(int sequence) async* {
    for (final frame in replayFrames) {
      yield frame;
    }
  }
}

class _FakeContexts implements ContextPort {
  _FakeContexts();

  final List<MindContext> contexts = const [_knee, _tax];
  final List<ContextLink> links = const [
    ContextLink('kneesurgery2026', 'q3taxfiling'),
  ];

  @override
  Future<List<MindContext>> all() async => contexts;

  @override
  Future<MindContext?> byId(String id) async {
    for (final c in contexts) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<List<ContextLink>> linksFor(String contextId) async => links
      .where((l) => l.fromId == contextId || l.toId == contextId)
      .toList(growable: false);

  @override
  Future<MindContext> create({required String label}) async => contexts.first;

  @override
  Future<void> link(String fromId, String toId) async {}

  @override
  Future<void> unlink(String fromId, String toId) async {}

  @override
  Future<List<String>> survivorsIfDestroyed(String contextId) async => const [];
}

class _FakeProjections implements ProjectionPort {
  _FakeProjections({
    this.searchHits = const [
      SearchHitRef(
        opSequence: 12481,
        title: 'Ibuprofen 400 mg logged',
        snippet: 'Dr. Rao logged the dose on 14 Aug.',
        contextIds: ['kneesurgery2026'],
      ),
    ],
  });

  final List<ProjectionState> states0 = const [
    ProjectionState(
      kind: ProjectionKind.graph,
      status: ProjectionStatus.fresh,
      lastRebuildMs: 3100,
      opsProcessed: 12481,
      opsTotal: 12481,
    ),
    ProjectionState(
      kind: ProjectionKind.timeline,
      status: ProjectionStatus.rebuilding,
      lastRebuildMs: 900,
      opsProcessed: 6000,
      opsTotal: 12481,
    ),
    ProjectionState(
      kind: ProjectionKind.search,
      status: ProjectionStatus.queued,
      lastRebuildMs: 3100,
      opsProcessed: 0,
      opsTotal: 12481,
    ),
  ];
  final List<SearchHitRef> searchHits;

  @override
  Future<ProjectionState> stateOf(ProjectionKind kind) async =>
      states0.firstWhere((s) => s.kind == kind);

  @override
  Future<List<ProjectionState>> states() async => states0;

  @override
  Stream<ProjectionState> rebuild(ProjectionKind kind) => const Stream.empty();

  @override
  Future<List<SearchHitRef>> search(String query, {String? contextId}) async =>
      searchHits;
}

class _ThrowingExtractor implements EntityExtractor {
  const _ThrowingExtractor();

  @override
  List<ExtractedEntity> extract(String text) =>
      throw const EntityExtractionUnavailable('no model loaded');
}

class _EmptyExtractor implements EntityExtractor {
  const _EmptyExtractor();

  @override
  List<ExtractedEntity> extract(String text) => const [];
}

Widget _harness({
  required OperationLogPort log,
  required ContextPort contexts,
  required ProjectionPort projections,
  EntityExtractor extractor = const RuleBasedEntityExtractor(),
  int opSequence = 12481,
  void Function(int)? onCitationTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ProvenanceInspector(
        opSequence: opSequence,
        log: log,
        contexts: contexts,
        projections: projections,
        extractor: extractor,
        onCitationTap: onCitationTap,
      ),
    ),
  );
}

void main() {
  testWidgets('renders extracted entities as tappable citation chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        log: _FakeLog(),
        contexts: _FakeContexts(),
        projections: _FakeProjections(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dr. Rao'), findsOneWidget);
    expect(find.text('Ibuprofen'), findsOneWidget);
    expect(find.text('14 Aug'), findsOneWidget);
    expect(find.byKey(const Key('provenance.entities.empty')), findsNothing);
    expect(find.byKey(const Key('provenance.relations.empty')), findsOneWidget);
  });

  testWidgets('renders typed relations for a funding announcement', (
    tester,
  ) async {
    const announcement = MindOp(
      sequence: 2001,
      kind: MindOpKind.automation,
      title: 'Funding note',
      contextId: 'kneesurgery2026',
      deviceName: 'Pixel 9 Pro',
      signature: SignatureState.unverified,
      recordedAtMs: 0,
      detail:
          'On Aug 29th, 2024, Optimist Corp. announced in Chicago that '
          'its CEO, Brad Doe, would be stepping down after a successful '
          '\$5 million funding round.',
    );

    await tester.pumpWidget(
      _harness(
        log: _FakeLog(ops: const [announcement]),
        contexts: _FakeContexts(),
        projections: _FakeProjections(),
        opSequence: 2001,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Brad Doe · works at · Optimist Corp.'), findsOneWidget);
    expect(find.text('Optimist Corp. · located in · Chicago'), findsOneWidget);
    expect(find.byKey(const Key('provenance.relations.empty')), findsNothing);
  });

  // Non-happy: no entities found.
  testWidgets('states plainly when extraction finds nothing', (tester) async {
    await tester.pumpWidget(
      _harness(
        log: _FakeLog(),
        contexts: _FakeContexts(),
        projections: _FakeProjections(),
        extractor: const _EmptyExtractor(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('provenance.entities.empty')), findsOneWidget);
  });

  // Non-happy: extraction unavailable.
  testWidgets('states plainly when extraction is unavailable', (tester) async {
    await tester.pumpWidget(
      _harness(
        log: _FakeLog(),
        contexts: _FakeContexts(),
        projections: _FakeProjections(),
        extractor: const _ThrowingExtractor(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('provenance.entities.unavailable')),
      findsOneWidget,
    );
  });

  testWidgets(
    'signature state is freshly re-verified, not read off the stored op',
    (tester) async {
      // The op's own `signature` field says unverified; the log's fresh
      // `verify()` disagrees and says verified. The panel must show the
      // fresh answer, proving it did not just print the stored field.
      await tester.pumpWidget(
        _harness(
          log: _FakeLog(verifiedAs: SignatureState.verified),
          contexts: _FakeContexts(),
          projections: _FakeProjections(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Signature verified'), findsOneWidget);
      expect(find.text('Signature UNVERIFIED'), findsNothing);
    },
  );

  testWidgets('renders each projection\'s state independently', (tester) async {
    await tester.pumpWidget(
      _harness(
        log: _FakeLog(),
        contexts: _FakeContexts(),
        projections: _FakeProjections(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('provenance.projection.graph')),
      findsOneWidget,
    );
    expect(find.text('graph · fresh'), findsOneWidget);
    expect(find.text('timeline · rebuilding (6000/12481)'), findsOneWidget);
    expect(find.text('search · queued'), findsOneWidget);
  });

  testWidgets('renders linked contexts as tappable R02 chips', (tester) async {
    await tester.pumpWidget(
      _harness(
        log: _FakeLog(),
        contexts: _FakeContexts(),
        projections: _FakeProjections(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#Q3TaxFiling'), findsOneWidget);
  });

  // Non-happy: provenance chain broken (op not found).
  testWidgets('states plainly when the inspected op is not in the log', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        log: _FakeLog(ops: const []),
        contexts: _FakeContexts(),
        projections: _FakeProjections(),
        opSequence: 999,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('provenance.broken')), findsOneWidget);
    expect(find.textContaining('999'), findsOneWidget);
  });

  // Non-happy: provenance chain broken (entity not confirmed by the index).
  testWidgets(
    'tapping an entity with no search hits states the chain is broken',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          log: _FakeLog(),
          contexts: _FakeContexts(),
          projections: _FakeProjections(searchHits: const []),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ibuprofen'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('provenance.chain.broken')), findsOneWidget);
    },
  );

  testWidgets('tapping an entity with hits jumps back to the citing op', (
    tester,
  ) async {
    int? tapped;
    await tester.pumpWidget(
      _harness(
        log: _FakeLog(),
        contexts: _FakeContexts(),
        projections: _FakeProjections(),
        onCitationTap: (sequence) => tapped = sequence,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ibuprofen'));
    await tester.pumpAndSettle();

    expect(tapped, 12481);
  });

  testWidgets('replay-from-log rebuilds and reports its measured duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        log: _FakeLog(),
        contexts: _FakeContexts(),
        projections: _FakeProjections(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('provenance.replay.button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('provenance.replay.button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('provenance.replay.done')), findsOneWidget);
    expect(find.textContaining('Rebuilt in'), findsOneWidget);
  });
}
