// ignore_for_file: prefer_initializing_formals -- _FaultyMindRuntime's named
// overrides are bound to differently-named private fields, not a straight
// positional-to-field assignment.
import 'package:feature_mind/src/home/mind_home_dashboard.dart';
import 'package:feature_mind/src/quick_capture/presentation/quick_capture_sheet.dart';
import 'package:feature_mind/src/runtime/fixture/fixture_data.dart';
import 'package:feature_mind/src/runtime/fixture/fixture_mind_runtime.dart';
import 'package:feature_mind/src/runtime/mind_runtime.dart';
import 'package:feature_mind/src/runtime/models/capability_models.dart';
import 'package:feature_mind/src/runtime/models/context_models.dart';
import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:feature_mind/src/runtime/models/mesh_models.dart';
import 'package:feature_mind/src/runtime/models/vault_models.dart';
import 'package:feature_mind/src/runtime/ports/capability_port.dart';
import 'package:feature_mind/src/runtime/ports/context_port.dart';
import 'package:feature_mind/src/runtime/ports/mesh_port.dart';
import 'package:feature_mind/src/runtime/ports/model_port.dart';
import 'package:feature_mind/src/runtime/ports/operation_log_port.dart';
import 'package:feature_mind/src/runtime/ports/portability_port.dart';
import 'package:feature_mind/src/runtime/ports/projection_port.dart';
import 'package:feature_mind/src/runtime/ports/vault_port.dart';
import 'package:feature_mind/src/widgets/mind_number_strip.dart';
import 'package:feature_mind/src/widgets/mind_presence_pip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 390 x 844 -- the phone viewport the issue's "Done when" pins the
/// above-the-fold assertion to.
const Size _phoneViewport = Size(390, 844);

Future<void> _pumpDashboard(WidgetTester tester, MindRuntime runtime) async {
  tester.view.physicalSize = _phoneViewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(home: MindHomeDashboard(runtime: runtime)),
  );
  await tester.pump();
}

/// Delegates every sub-port to [FixtureMindRuntime] except the ones a test
/// overrides -- lets a non-happy-state test fail exactly one port without
/// hand-rolling all eight.
class _FaultyMindRuntime implements MindRuntime {
  _FaultyMindRuntime(
    this._inner, {
    VaultPort? vault,
    OperationLogPort? log,
    MeshPort? mesh,
    ContextPort? contexts,
    CapabilityPort? capabilities,
  }) : _vault = vault,
       _log = log,
       _mesh = mesh,
       _contexts = contexts,
       _capabilities = capabilities;

  final MindRuntime _inner;
  final VaultPort? _vault;
  final OperationLogPort? _log;
  final MeshPort? _mesh;
  final ContextPort? _contexts;
  final CapabilityPort? _capabilities;

  @override
  VaultPort get vault => _vault ?? _inner.vault;

  @override
  OperationLogPort get log => _log ?? _inner.log;

  @override
  ContextPort get contexts => _contexts ?? _inner.contexts;

  @override
  ProjectionPort get projections => _inner.projections;

  @override
  MeshPort get mesh => _mesh ?? _inner.mesh;

  @override
  CapabilityPort get capabilities => _capabilities ?? _inner.capabilities;

  @override
  ModelPort get models => _inner.models;

  @override
  PortabilityPort get portability => _inner.portability;
}

class _ThrowingVault implements VaultPort {
  const _ThrowingVault();

  static const _error = MindPortUnavailable('vault', 'root identity not sealed');

  @override
  Future<VaultState> state() async => throw _error;

  @override
  Future<List<MindDevice>> devices() async => throw _error;

  @override
  Future<void> revokeDevice(DeviceFingerprint fingerprint) async =>
      throw _error;
}

class _ThrowingLog implements OperationLogPort {
  const _ThrowingLog();

  static const _error = MindPortUnavailable('log', 'append-only log not wired');

  @override
  Future<int> count() async => throw _error;

  @override
  Future<List<MindOp>> range({required int offset, required int limit}) async =>
      throw _error;

  @override
  Future<MindOp?> bySequence(int sequence) async => throw _error;

  @override
  Future<int> append({
    required MindOpKind kind,
    required String title,
    required String contextId,
    String detail = '',
  }) async => throw _error;

  @override
  Future<SignatureState> verify(int sequence) async => throw _error;

  @override
  Stream<double> replayFrom(int sequence) => Stream.error(_error);
}

class _ThrowingMesh implements MeshPort {
  const _ThrowingMesh();

  static const _error = MindPortUnavailable('mesh', 'mDNS discovery not wired');

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

class _ThrowingContexts implements ContextPort {
  const _ThrowingContexts();

  static const _error = MindPortUnavailable('contexts', 'hypergraph not wired');

  @override
  Future<List<MindContext>> all() async => throw _error;

  @override
  Future<MindContext?> byId(String id) async => throw _error;

  @override
  Future<List<ContextLink>> linksFor(String contextId) async => throw _error;

  @override
  Future<MindContext> create({required String label}) async => throw _error;

  @override
  Future<void> link(String fromId, String toId) async => throw _error;

  @override
  Future<void> unlink(String fromId, String toId) async => throw _error;

  @override
  Future<List<String>> survivorsIfDestroyed(String contextId) async =>
      throw _error;
}

class _ThrowingCapabilities implements CapabilityPort {
  const _ThrowingCapabilities();

  static const _error =
      MindPortUnavailable('capabilities', 'pack registry not wired');

  @override
  Future<List<InstalledCapability>> installed() async => throw _error;

  @override
  Future<InstalledCapability?> byId(String id) async => throw _error;

  @override
  Future<void> setActive(String id, {required bool active}) async =>
      throw _error;

  @override
  Future<void> remove(String id) async => throw _error;
}

void main() {
  group('MindHomeDashboard port binding', () {
    testWidgets('renders the R01 presence pip', (tester) async {
      await _pumpDashboard(tester, FixtureMindRuntime());

      expect(find.byType(MindPresencePip), findsOneWidget);
    });

    testWidgets(
      'renders the R04 numbers strip above the fold with vault/log/mesh '
      'values',
      (tester) async {
        await _pumpDashboard(tester, FixtureMindRuntime());

        final stripFinder = find.byKey(const Key('mind.home.numberStrip'));
        expect(stripFinder, findsOneWidget);
        expect(find.byType(MindNumberStrip), findsOneWidget);

        // Fixture values: 12,481 ops, 3 LAN peers, vault sealed.
        expect(find.textContaining('12,481 ops'), findsOneWidget);
        expect(find.textContaining('3 on LAN'), findsOneWidget);
        expect(find.textContaining('Sealed'), findsOneWidget);

        // Above the fold at the pinned 390x844 viewport.
        final top = tester.getTopLeft(stripFinder).dy;
        expect(top, lessThan(_phoneViewport.height / 2));
      },
    );

    testWidgets('renders a context summary bound to ContextPort', (
      tester,
    ) async {
      await _pumpDashboard(tester, FixtureMindRuntime());

      expect(find.byKey(const Key('mind.home.contexts')), findsOneWidget);
      expect(
        find.text('${fixtureContexts.length} CONTEXTS'),
        findsOneWidget,
      );
    });

    testWidgets('renders a capability summary bound to CapabilityPort', (
      tester,
    ) async {
      await _pumpDashboard(tester, FixtureMindRuntime());

      expect(
        find.byKey(const Key('mind.home.capabilities')),
        findsOneWidget,
      );
      final activeCount = fixtureCapabilities
          .where((c) => c.isActive)
          .length;
      expect(
        find.text(
          '$activeCount of ${fixtureCapabilities.length} CAPABILITIES ACTIVE',
        ),
        findsOneWidget,
      );
    });
  });

  group('MindHomeDashboard Quick Capture entry point', () {
    testWidgets('the amber capture key opens QuickCaptureSheet', (
      tester,
    ) async {
      await _pumpDashboard(tester, FixtureMindRuntime());

      expect(find.byType(QuickCaptureSheet), findsNothing);

      await tester.tap(find.byKey(const Key('mind.home.captureKey')));
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureSheet), findsOneWidget);
    });
  });

  group('MindHomeDashboard non-happy states', () {
    testWidgets('names the vault port when VaultPort is unavailable', (
      tester,
    ) async {
      final runtime = _FaultyMindRuntime(
        FixtureMindRuntime(),
        vault: const _ThrowingVault(),
      );
      await _pumpDashboard(tester, runtime);

      expect(
        find.byKey(const Key('mind.home.portError.vault')),
        findsOneWidget,
      );
      expect(find.text('The vault is not available.'), findsOneWidget);
      // A failed port means the strip has no partial-data mode -- it does
      // not render at all rather than guessing.
      expect(find.byKey(const Key('mind.home.numberStrip')), findsNothing);
    });

    testWidgets('names the log port when OperationLogPort is unavailable', (
      tester,
    ) async {
      final runtime = _FaultyMindRuntime(
        FixtureMindRuntime(),
        log: const _ThrowingLog(),
      );
      await _pumpDashboard(tester, runtime);

      expect(
        find.byKey(const Key('mind.home.portError.log')),
        findsOneWidget,
      );
      expect(find.text('The log is not available.'), findsOneWidget);
      expect(find.byKey(const Key('mind.home.numberStrip')), findsNothing);
    });

    testWidgets('names the mesh port when MeshPort fails on the stream', (
      tester,
    ) async {
      final runtime = _FaultyMindRuntime(
        FixtureMindRuntime(),
        mesh: const _ThrowingMesh(),
      );
      await _pumpDashboard(tester, runtime);

      expect(
        find.byKey(const Key('mind.home.portError.mesh')),
        findsOneWidget,
      );
      expect(find.text('The mesh is not available.'), findsOneWidget);
      expect(find.byKey(const Key('mind.home.numberStrip')), findsNothing);
    });

    testWidgets('names the contexts port when ContextPort is unavailable', (
      tester,
    ) async {
      final runtime = _FaultyMindRuntime(
        FixtureMindRuntime(),
        contexts: const _ThrowingContexts(),
      );
      await _pumpDashboard(tester, runtime);

      expect(
        find.byKey(const Key('mind.home.contexts.error')),
        findsOneWidget,
      );
      expect(find.text('The contexts is not available.'), findsOneWidget);
    });

    testWidgets(
      'names the capabilities port when CapabilityPort is unavailable',
      (tester) async {
        final runtime = _FaultyMindRuntime(
          FixtureMindRuntime(),
          capabilities: const _ThrowingCapabilities(),
        );
        await _pumpDashboard(tester, runtime);

        expect(
          find.byKey(const Key('mind.home.capabilities.error')),
          findsOneWidget,
        );
        expect(
          find.text('The capabilities is not available.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('never renders a spinner, with or without a port failure', (
      tester,
    ) async {
      // Happy path: no spinner while the futures/streams are in flight, and
      // none once they resolve.
      tester.view.physicalSize = _phoneViewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: MindHomeDashboard(runtime: FixtureMindRuntime())),
      );
      // Immediately after the first frame, before any future resolves.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Failure path: a missing sub-port must never be papered over with a
      // spinner either.
      final runtime = _FaultyMindRuntime(
        FixtureMindRuntime(),
        vault: const _ThrowingVault(),
        mesh: const _ThrowingMesh(),
      );
      await tester.pumpWidget(
        MaterialApp(home: MindHomeDashboard(runtime: runtime)),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
