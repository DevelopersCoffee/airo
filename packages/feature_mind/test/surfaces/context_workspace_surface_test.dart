import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_mind/src/runtime/fixture/fixture_data.dart';
import 'package:feature_mind/src/runtime/fixture/fixture_mind_runtime.dart';
import 'package:feature_mind/src/runtime/mind_runtime.dart';
import 'package:feature_mind/src/runtime/models/context_models.dart';
import 'package:feature_mind/src/runtime/models/projection_models.dart';
import 'package:feature_mind/src/runtime/ports/context_port.dart';
import 'package:feature_mind/src/runtime/ports/projection_port.dart';
import 'package:feature_mind/src/surfaces/context_workspace_surface.dart';
import 'package:feature_mind/src/widgets/mind_context_chip.dart';
import 'package:feature_mind/src/widgets/mind_presence_pip.dart';
import 'package:feature_mind/src/widgets/mind_projection_switcher.dart';

const _localDeviceName = 'Pixel 9 Pro';

/// Resizes the test surface itself, not just the [MediaQuery] a descendant
/// reads. `LayoutBuilder`'s constraints come from the real render tree, so a
/// bare `MediaQuery` override is invisible to it — the test binding's default
/// surface (800x600) would satisfy the tablet breakpoint regardless of what
/// size a test claims to run at.
Future<void> _pumpAtSize(
  WidgetTester tester,
  Widget child, {
  required Size size,
}) async {
  final originalPhysicalSize = tester.view.physicalSize;
  final originalDevicePixelRatio = tester.view.devicePixelRatio;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.physicalSize = originalPhysicalSize;
    tester.view.devicePixelRatio = originalDevicePixelRatio;
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SizedBox.expand(child: child)),
    ),
  );
}

/// A [ProjectionPort] with caller-chosen states — used to drive the
/// rebuilding non-happy state deterministically instead of racing the
/// fixture's own animated [FixtureMindRuntime] rebuild stream.
class _FixedProjectionPort implements ProjectionPort {
  _FixedProjectionPort(this._states);

  final List<ProjectionState> _states;

  @override
  Future<ProjectionState> stateOf(ProjectionKind kind) async =>
      _states.firstWhere((s) => s.kind == kind);

  @override
  Future<List<ProjectionState>> states() async => _states;

  @override
  Stream<ProjectionState> rebuild(ProjectionKind kind) => const Stream.empty();

  @override
  Future<List<SearchHitRef>> search(String query, {String? contextId}) async =>
      const [];
}

class _UnavailableContextPort implements ContextPort {
  const _UnavailableContextPort();

  Never _fail() =>
      throw const MindPortUnavailable('contexts', 'not implemented yet');

  @override
  Future<List<MindContext>> all() async => _fail();

  @override
  Future<MindContext?> byId(String id) async => _fail();

  @override
  Future<List<ContextLink>> linksFor(String contextId) async => _fail();

  @override
  Future<MindContext> create({required String label}) async => _fail();

  @override
  Future<void> link(String fromId, String toId) async => _fail();

  @override
  Future<void> unlink(String fromId, String toId) async => _fail();

  @override
  Future<List<String>> survivorsIfDestroyed(String contextId) async => _fail();
}

class _UnavailableProjectionPort implements ProjectionPort {
  const _UnavailableProjectionPort();

  Never _fail() =>
      throw const MindPortUnavailable('projections', 'not implemented yet');

  @override
  Future<ProjectionState> stateOf(ProjectionKind kind) async => _fail();

  @override
  Future<List<ProjectionState>> states() async => _fail();

  @override
  Stream<ProjectionState> rebuild(ProjectionKind kind) => const Stream.empty();

  @override
  Future<List<SearchHitRef>> search(String query, {String? contextId}) async =>
      _fail();
}

void main() {
  late FixtureMindRuntime runtime;

  setUp(() {
    runtime = FixtureMindRuntime();
  });

  group('tablet width (>= 600px)', () {
    testWidgets('renders the split pane and both context list and detail', (
      tester,
    ) async {
      await _pumpAtSize(
        tester,
        ContextWorkspaceSurface(
          contexts: runtime.contexts,
          log: runtime.log,
          projections: runtime.projections,
          localDeviceName: _localDeviceName,
        ),
        size: const Size(900, 1200),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mind.contextWorkspace.splitPane')),
        findsOneWidget,
      );
      // Split pane shows the list immediately, without a tap.
      expect(find.byType(MindContextChip), findsWidgets);

      // Select a context and confirm the detail pane renders alongside the
      // list rather than replacing it (no navigation, no back button).
      await tester.tap(find.byType(MindContextChip).first);
      await tester.pumpAndSettle();

      expect(find.byType(MindContextChip), findsWidgets);
      expect(find.text('BACK TO CONTEXTS'), findsNothing);
    });

    test('600px itself counts as tablet width', () {
      expect(
        600 >= ContextWorkspaceSurface.tabletBreakpoint,
        isTrue,
        reason:
            'RESPONSIVE_STANDARDS.md documents 600px as the start of '
            'the tablet range.',
      );
    });
  });

  group('phone width (< 600px)', () {
    testWidgets('collapses to a single pane', (tester) async {
      await _pumpAtSize(
        tester,
        ContextWorkspaceSurface(
          contexts: runtime.contexts,
          log: runtime.log,
          projections: runtime.projections,
          localDeviceName: _localDeviceName,
        ),
        size: const Size(390, 844),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mind.contextWorkspace.singlePane')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mind.contextWorkspace.splitPane')),
        findsNothing,
      );

      // Selecting a context replaces the list with the detail pane, and a
      // back affordance appears — the single-pane collapse the tablet
      // composition must fall back to.
      await tester.tap(find.byType(MindContextChip).first);
      await tester.pumpAndSettle();

      expect(find.text('BACK TO CONTEXTS'), findsOneWidget);
      expect(find.byType(MindContextChip), findsNothing);
    });

    testWidgets('599px (just under the breakpoint) also collapses', (
      tester,
    ) async {
      await _pumpAtSize(
        tester,
        ContextWorkspaceSurface(
          contexts: runtime.contexts,
          log: runtime.log,
          projections: runtime.projections,
          localDeviceName: _localDeviceName,
        ),
        size: const Size(599, 900),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mind.contextWorkspace.singlePane')),
        findsOneWidget,
      );
    });
  });

  group('R03 — single switcher', () {
    testWidgets('uses exactly one MindProjectionSwitcher at tablet width', (
      tester,
    ) async {
      await _pumpAtSize(
        tester,
        ContextWorkspaceSurface(
          contexts: runtime.contexts,
          log: runtime.log,
          projections: runtime.projections,
          localDeviceName: _localDeviceName,
        ),
        size: const Size(900, 1200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MindContextChip).first);
      await tester.pumpAndSettle();

      expect(find.byType(MindProjectionSwitcher), findsOneWidget);
    });

    testWidgets('uses exactly one MindProjectionSwitcher at phone width', (
      tester,
    ) async {
      await _pumpAtSize(
        tester,
        ContextWorkspaceSurface(
          contexts: runtime.contexts,
          log: runtime.log,
          projections: runtime.projections,
          localDeviceName: _localDeviceName,
        ),
        size: const Size(390, 844),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MindContextChip).first);
      await tester.pumpAndSettle();

      expect(find.byType(MindProjectionSwitcher), findsOneWidget);
    });
  });

  group('R01 — presence pip', () {
    testWidgets('is present at both tablet and phone widths', (tester) async {
      for (final size in [const Size(900, 1200), const Size(390, 844)]) {
        await _pumpAtSize(
          tester,
          ContextWorkspaceSurface(
            contexts: runtime.contexts,
            log: runtime.log,
            projections: runtime.projections,
            localDeviceName: _localDeviceName,
          ),
          size: size,
        );
        await tester.pumpAndSettle();
        expect(find.byType(MindPresencePip), findsAtLeastNWidgets(1));
      }
    });
  });

  group('R02 — context chips', () {
    testWidgets('every chip meets the 48px minimum tap target', (tester) async {
      await _pumpAtSize(
        tester,
        ContextWorkspaceSurface(
          contexts: runtime.contexts,
          log: runtime.log,
          projections: runtime.projections,
          localDeviceName: _localDeviceName,
        ),
        size: const Size(900, 1200),
      );
      await tester.pumpAndSettle();

      final chips = find.byType(MindContextChip);
      expect(chips, findsWidgets);
      for (var i = 0; i < chips.evaluate().length; i++) {
        expect(
          tester.getSize(chips.at(i)).height,
          greaterThanOrEqualTo(MindContextChip.minimumTarget),
        );
      }
    });
  });

  group('non-happy: runtime unavailable', () {
    testWidgets('names the port when the context list cannot load', (
      tester,
    ) async {
      await _pumpAtSize(
        tester,
        ContextWorkspaceSurface(
          contexts: const _UnavailableContextPort(),
          log: runtime.log,
          projections: runtime.projections,
          localDeviceName: _localDeviceName,
        ),
        size: const Size(900, 1200),
      );
      await tester.pumpAndSettle();

      final error = find.byKey(const Key('mind.contextWorkspace.portError'));
      expect(error, findsOneWidget);
      expect(
        tester.widget<Text>(error).data,
        contains('contexts'),
        reason: 'MindPortUnavailable names the port, not the product.',
      );
    });

    testWidgets('names the port when projection status cannot load', (
      tester,
    ) async {
      await _pumpAtSize(
        tester,
        ContextWorkspaceSurface(
          contexts: runtime.contexts,
          log: runtime.log,
          projections: const _UnavailableProjectionPort(),
          localDeviceName: _localDeviceName,
        ),
        size: const Size(900, 1200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MindContextChip).first);
      await tester.pumpAndSettle();

      final error = find.byKey(const Key('mind.contextWorkspace.portError'));
      expect(error, findsOneWidget);
      expect(tester.widget<Text>(error).data, contains('projections'));
    });
  });

  group('non-happy: projection rebuilding', () {
    testWidgets('shows ops processed of ops total, never a bare spinner', (
      tester,
    ) async {
      final rebuildingPort = _FixedProjectionPort(const [
        ProjectionState(
          kind: ProjectionKind.graph,
          status: ProjectionStatus.rebuilding,
          lastRebuildMs: 3100,
          opsProcessed: 6240,
          opsTotal: 12481,
        ),
        ProjectionState(
          kind: ProjectionKind.timeline,
          status: ProjectionStatus.fresh,
          lastRebuildMs: 900,
          opsProcessed: 12481,
          opsTotal: 12481,
        ),
        ProjectionState(
          kind: ProjectionKind.search,
          status: ProjectionStatus.queued,
          lastRebuildMs: 3100,
          opsProcessed: 0,
          opsTotal: 12481,
        ),
      ]);

      await _pumpAtSize(
        tester,
        ContextWorkspaceSurface(
          contexts: runtime.contexts,
          log: runtime.log,
          projections: rebuildingPort,
          localDeviceName: _localDeviceName,
        ),
        size: const Size(900, 1200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MindContextChip).first);
      await tester.pumpAndSettle();

      expect(find.text('REBUILDING · 6240/12481'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('non-happy: peer offline / remote attribution', () {
    testWidgets(
      'renders a non-local pip naming the writing device when the most '
      'recent op for a context was not written on this device',
      (tester) async {
        // #Q3TaxFiling's most recent op in the fixture was written on
        // 'Desktop', not 'Pixel 9 Pro'.
        final taxContext = fixtureContexts.firstWhere(
          (c) => c.id == 'q3taxfiling',
        );

        await _pumpAtSize(
          tester,
          ContextWorkspaceSurface(
            contexts: runtime.contexts,
            log: runtime.log,
            projections: runtime.projections,
            localDeviceName: _localDeviceName,
          ),
          size: const Size(900, 1200),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(taxContext.label));
        await tester.pumpAndSettle();

        final pip = tester.widget<MindPresencePip>(
          find.byKey(const Key('mind.contextWorkspace.provenancePip')),
        );
        expect(pip.isLocal, isFalse);
        expect(pip.remoteLabel, 'Desktop');
      },
    );

    testWidgets('renders a local pip when the most recent op was local', (
      tester,
    ) async {
      // #KneeSurgery2026's most recent op in the fixture was written on
      // 'Pixel 9 Pro' — this device.
      final kneeContext = fixtureContexts.firstWhere(
        (c) => c.id == 'kneesurgery2026',
      );

      await _pumpAtSize(
        tester,
        ContextWorkspaceSurface(
          contexts: runtime.contexts,
          log: runtime.log,
          projections: runtime.projections,
          localDeviceName: _localDeviceName,
        ),
        size: const Size(900, 1200),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(kneeContext.label));
      await tester.pumpAndSettle();

      final pip = tester.widget<MindPresencePip>(
        find.byKey(const Key('mind.contextWorkspace.provenancePip')),
      );
      expect(pip.isLocal, isTrue);
    });
  });
}
