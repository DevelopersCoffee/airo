import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/mind_rule_harness.dart';
import '../support/surface_harness.dart';

void main() {
  testWidgets('is a runtime dashboard, not a feed', (tester) async {
    await pumpSurface(tester, MindHomeSurface(runtime: FixtureMindRuntime()));
    await tester.pumpAndSettle();

    // Ops, peers and vault are the point of the screen, and they sit above
    // everything else.
    expect(find.text('12,481 ops'), findsOneWidget);
    expect(find.text('3 on LAN'), findsOneWidget);
    expect(find.text('Sealed'), findsOneWidget);

    await expectSatisfiesMindRules(tester);
  });

  testWidgets('capture is one tap from here', (tester) async {
    await pumpSurface(tester, MindHomeSurface(runtime: FixtureMindRuntime()));
    await tester.pumpAndSettle();

    expect(find.text('VOICE'), findsOneWidget);
    expect(find.text('NOTE'), findsOneWidget);
    expect(find.text('SCAN'), findsOneWidget);
  });

  testWidgets('renders every active context as a tappable chip', (
    tester,
  ) async {
    var tapped = '';
    await pumpSurface(
      tester,
      MindHomeSurface(
        runtime: FixtureMindRuntime(),
        onOpenContext: (context) => tapped = context.label,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4 ACTIVE'), findsOneWidget);
    expect(find.byType(MindContextChip), findsNWidgets(4));

    await tester.tap(find.text('#KneeSurgery2026'));
    expect(tapped, '#KneeSurgery2026');
  });

  testWidgets('lists installed capabilities with their item counts', (
    tester,
  ) async {
    await pumpSurface(tester, MindHomeSurface(runtime: FixtureMindRuntime()));
    await tester.pumpAndSettle();

    expect(find.text('Hospital Recovery'), findsOneWidget);
    expect(find.text('Audio Scribe'), findsOneWidget);
    expect(find.text('38 ITEMS'), findsOneWidget);
  });

  testWidgets('recent log rows carry their context and op number', (
    tester,
  ) async {
    await pumpSurface(tester, MindHomeSurface(runtime: FixtureMindRuntime()));
    await tester.pumpAndSettle();

    expect(find.text('Ibuprofen 400 mg logged'), findsOneWidget);
    expect(find.text('op 12,481'), findsOneWidget);
  });

  testWidgets('reports the missing port when the runtime is partial', (
    tester,
  ) async {
    // CUDA bench gave OperationLogPort a Dart fallback, so Home's first
    // missing read on the real runtime is mesh.peers(). Proven against a
    // mixed runtime so the assertion cannot pass for the unrelated reason
    // of the log also failing (path_provider / thermal probe).
    await pumpSurface(
      tester,
      MindHomeSurface(
        runtime: _PartialHomeRuntime(
          FixtureMindRuntime(),
          mesh: const _UnavailableMesh(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('MeshPort'), findsOneWidget);
    expect(find.byType(MindNumberStrip), findsNothing);
  });

  // Layout golden, not a typography one. `flutter test` loads no fonts, so
  // glyphs render as boxes; the design's three faces ship as .woff2, which
  // FontLoader cannot consume. This catches structure, spacing and overflow —
  // not copy or type. Reading it as proof of the design's look would be
  // exactly the kind of green that proves nothing.
  testWidgets('golden — layout at 390 x 844', (tester) async {
    await pumpSurface(tester, MindHomeSurface(runtime: FixtureMindRuntime()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MindHomeSurface),
      matchesGoldenFile('goldens/mind_home.png'),
    );
  });
}

class _PartialHomeRuntime implements MindRuntime {
  _PartialHomeRuntime(this._inner, {required this.mesh});

  final MindRuntime _inner;

  @override
  final MeshPort mesh;

  @override
  VaultPort get vault => _inner.vault;

  @override
  OperationLogPort get log => _inner.log;

  @override
  ContextPort get contexts => _inner.contexts;

  @override
  ProjectionPort get projections => _inner.projections;

  @override
  CapabilityPort get capabilities => _inner.capabilities;

  @override
  ModelPort get models => _inner.models;

  @override
  PortabilityPort get portability => _inner.portability;
}

class _UnavailableMesh implements MeshPort {
  const _UnavailableMesh();

  static const _error = MindPortUnavailable(
    'MeshPort',
    'not implemented yet — #1200',
  );

  @override
  Stream<List<MindPeer>> peers() => Stream.error(_error);

  @override
  Stream<PairingRequest?> pendingRequest() => Stream.error(_error);

  @override
  Future<void> authorise(PairingRequest request) async => throw _error;

  @override
  Future<void> deny(PairingRequest request) async => throw _error;

  @override
  Future<int> push(DeviceFingerprint peer) async => throw _error;
}
