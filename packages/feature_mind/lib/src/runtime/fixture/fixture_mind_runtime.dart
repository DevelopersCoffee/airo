import '../mind_runtime.dart';
import '../models/context_models.dart';
import '../models/log_models.dart';
import '../models/vault_models.dart';
import '../ports/capability_port.dart';
import '../ports/context_port.dart';
import '../ports/mesh_port.dart';
import '../ports/model_port.dart';
import '../ports/operation_log_port.dart';
import '../ports/portability_port.dart';
import '../ports/projection_port.dart';
import '../ports/vault_port.dart';
import 'fixture_data.dart';

/// A runtime that behaves like the real one and stores nothing.
///
/// Every surface is built and golden-tested against this while milestone 19
/// lands the real thing. It is not a mock: appending really does advance the
/// sequence, rebuilding really does report progress, and a search really does
/// filter. A double that resolves everything instantly would let a surface
/// ship that has never rendered a loading state.
class FixtureMindRuntime implements MindRuntime {
  FixtureMindRuntime()
    : _vault = const _FixtureVault(),
      _log = _FixtureLog(),
      _contexts = _FixtureContexts();

  final _FixtureVault _vault;
  final _FixtureLog _log;
  final _FixtureContexts _contexts;

  @override
  VaultPort get vault => _vault;

  @override
  OperationLogPort get log => _log;

  @override
  ContextPort get contexts => _contexts;

  @override
  ProjectionPort get projections => throw UnimplementedError();

  @override
  MeshPort get mesh => throw UnimplementedError();

  @override
  CapabilityPort get capabilities => throw UnimplementedError();

  @override
  ModelPort get models => throw UnimplementedError();

  @override
  PortabilityPort get portability => throw UnimplementedError();
}

class _FixtureVault implements VaultPort {
  const _FixtureVault();

  @override
  Future<VaultState> state() async => const VaultState(
    isSealed: true,
    keyCount: 4,
    revokedCount: 1,
    revocationEpoch: 3,
    onDiskBytes: 14200000000,
  );

  @override
  Future<List<MindDevice>> devices() async => fixtureDevices;

  @override
  Future<void> revokeDevice(DeviceFingerprint fingerprint) async {}
}

class _FixtureLog implements OperationLogPort {
  /// Ops appended during this session, oldest first.
  ///
  /// The 12,481 below them are implied rather than materialised: the fixture
  /// reports the real count and serves the nine the design shows, which is
  /// what every surface actually pages through.
  final List<MindOp> _appended = [];

  static const int _baseCount = 12481;

  List<MindOp> get _all => [..._appended.reversed, ...fixtureOps];

  @override
  Future<int> count() async => _baseCount + _appended.length;

  @override
  Future<List<MindOp>> range({required int offset, required int limit}) async {
    final all = _all;
    if (offset >= all.length) return const [];
    return all.skip(offset).take(limit).toList(growable: false);
  }

  @override
  Future<MindOp?> bySequence(int sequence) async {
    for (final op in _all) {
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
  }) async {
    final sequence = await count() + 1;
    _appended.add(
      MindOp(
        sequence: sequence,
        kind: kind,
        title: title,
        contextId: contextId,
        deviceName: 'Pixel 9 Pro',
        signature: SignatureState.verified,
        // Derived from the sequence, not the clock: two runs must produce the
        // same bytes or the goldens flake.
        recordedAtMs: fixtureNowMs + (sequence - _baseCount) * 1000,
        detail: detail,
      ),
    );
    return sequence;
  }

  @override
  Future<SignatureState> verify(int sequence) async =>
      (await bySequence(sequence))?.signature ?? SignatureState.unsigned;

  @override
  Stream<double> replayFrom(int sequence) async* {
    for (var step = 0; step <= 10; step++) {
      yield step / 10;
    }
  }
}

class _FixtureContexts implements ContextPort {
  final List<MindContext> _created = [];

  @override
  Future<List<MindContext>> all() async => [...fixtureContexts, ..._created];

  @override
  Future<MindContext?> byId(String id) async {
    for (final context in await all()) {
      if (context.id == id) return context;
    }
    return null;
  }

  @override
  Future<List<ContextLink>> linksFor(String contextId) async => fixtureLinks
      .where((link) => link.fromId == contextId || link.toId == contextId)
      .toList(growable: false);

  @override
  Future<MindContext> create({required String label}) async {
    final context = MindContext(
      id: label.replaceAll('#', '').toLowerCase(),
      label: label,
      itemCount: 0,
      opCount: 1,
      openedAtMs: fixtureNowMs,
      safetyClass: fixtureContexts.first.safetyClass,
    );
    _created.add(context);
    return context;
  }

  @override
  Future<void> link(String fromId, String toId) async {}

  @override
  Future<void> unlink(String fromId, String toId) async {}

  @override
  Future<List<String>> survivorsIfDestroyed(String contextId) async {
    final linked = await linksFor(contextId);
    final ids = linked
        .map((link) => link.fromId == contextId ? link.toId : link.fromId)
        .toSet();
    final everything = await all();
    return everything
        .where((context) => ids.contains(context.id))
        .map((context) => context.label)
        .toList(growable: false);
  }
}
