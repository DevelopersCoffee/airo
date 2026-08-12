import '../mind_runtime.dart';
import '../models/capability_models.dart';
import '../models/context_models.dart';
import '../models/log_models.dart';
import '../models/mesh_models.dart';
import '../models/model_models.dart';
import '../models/portability_models.dart';
import '../models/projection_models.dart';
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
      _contexts = _FixtureContexts(),
      _projections = _FixtureProjections(),
      _mesh = const _FixtureMesh(),
      _capabilities = _FixtureCapabilities(),
      _models = const _FixtureModels(),
      _portability = const _FixturePortability();

  final _FixtureVault _vault;
  final _FixtureLog _log;
  final _FixtureContexts _contexts;
  final _FixtureProjections _projections;
  final _FixtureMesh _mesh;
  final _FixtureCapabilities _capabilities;
  final _FixtureModels _models;
  final _FixturePortability _portability;

  @override
  VaultPort get vault => _vault;

  @override
  OperationLogPort get log => _log;

  @override
  ContextPort get contexts => _contexts;

  @override
  ProjectionPort get projections => _projections;

  @override
  MeshPort get mesh => _mesh;

  @override
  CapabilityPort get capabilities => _capabilities;

  @override
  ModelPort get models => _models;

  @override
  PortabilityPort get portability => _portability;
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

class _FixtureProjections implements ProjectionPort {
  /// The design shows the graph and search rebuilt and embeddings queued for
  /// the same op. Three states, not one summary.
  final Map<ProjectionKind, ProjectionState> _states = {
    ProjectionKind.graph: const ProjectionState(
      kind: ProjectionKind.graph,
      status: ProjectionStatus.fresh,
      lastRebuildMs: 3100,
      opsProcessed: 12481,
      opsTotal: 12481,
    ),
    ProjectionKind.timeline: const ProjectionState(
      kind: ProjectionKind.timeline,
      status: ProjectionStatus.fresh,
      lastRebuildMs: 900,
      opsProcessed: 12481,
      opsTotal: 12481,
    ),
    ProjectionKind.search: const ProjectionState(
      kind: ProjectionKind.search,
      status: ProjectionStatus.queued,
      lastRebuildMs: 3100,
      opsProcessed: 0,
      opsTotal: 12481,
    ),
  };

  @override
  Future<ProjectionState> stateOf(ProjectionKind kind) async => _states[kind]!;

  @override
  Future<List<ProjectionState>> states() async => [
    _states[ProjectionKind.graph]!,
    _states[ProjectionKind.timeline]!,
    _states[ProjectionKind.search]!,
  ];

  @override
  Stream<ProjectionState> rebuild(ProjectionKind kind) async* {
    const total = 12481;
    for (var step = 1; step <= 4; step++) {
      yield ProjectionState(
        kind: kind,
        status: ProjectionStatus.rebuilding,
        lastRebuildMs: 3100,
        opsProcessed: total ~/ 4 * step,
        opsTotal: total,
      );
    }
    final done = ProjectionState(
      kind: kind,
      status: ProjectionStatus.fresh,
      lastRebuildMs: 3100,
      opsProcessed: total,
      opsTotal: total,
    );
    _states[kind] = done;
    yield done;
  }

  @override
  Future<List<SearchHitRef>> search(String query, {String? contextId}) async {
    final needle = query.toLowerCase();
    return fixtureOps
        .where((op) => contextId == null || op.contextId == contextId)
        .where(
          (op) =>
              op.title.toLowerCase().contains(needle) ||
              op.detail.toLowerCase().contains(needle),
        )
        .map(
          (op) => SearchHitRef(
            opSequence: op.sequence,
            title: op.title,
            snippet: op.detail.isEmpty ? op.title : op.detail,
            contextIds: op.contextId.isEmpty ? const [] : [op.contextId],
          ),
        )
        .toList(growable: false);
  }
}

class _FixtureMesh implements MeshPort {
  const _FixtureMesh();

  @override
  Stream<List<MindPeer>> peers() => Stream.value(fixturePeers);

  @override
  Stream<PairingRequest?> pendingRequest() =>
      Stream.value(fixturePairingRequest);

  @override
  Future<void> authorise(PairingRequest request) async {}

  @override
  Future<void> deny(PairingRequest request) async {}

  @override
  Future<int> push(DeviceFingerprint peer) async => 0;
}

class _FixtureCapabilities implements CapabilityPort {
  final Set<String> _removed = {};

  @override
  Future<List<InstalledCapability>> installed() async => fixtureCapabilities
      .where((capability) => !_removed.contains(capability.id))
      .toList(growable: false);

  @override
  Future<InstalledCapability?> byId(String id) async {
    for (final capability in await installed()) {
      if (capability.id == id) return capability;
    }
    return null;
  }

  @override
  Future<void> setActive(String id, {required bool active}) async {}

  /// Removes the pack and nothing else.
  ///
  /// Contexts it created survive. That is the invariant, and a fixture that
  /// quietly dropped them would let a surface ship claiming otherwise.
  @override
  Future<void> remove(String id) async {
    _removed.add(id);
  }
}

class _FixtureModels implements ModelPort {
  const _FixtureModels();

  @override
  Future<List<MindModel>> all() async => fixtureModels;

  @override
  Future<({int budgetBytes, int usedBytes})> storage() async =>
      (usedBytes: 6800000000, budgetBytes: 12000000000);

  @override
  Future<void> load(String modelId) async {}

  @override
  Future<void> unload(String modelId) async {
    final model = fixtureModels.firstWhere((m) => m.id == modelId);
    if (model.residency == ModelResidency.resident) {
      throw StateError('Unloading ${model.name} would break ${model.heldBy}.');
    }
  }

  @override
  Stream<({int received, int total})> download(String modelId) async* {
    final total = fixtureModels.firstWhere((m) => m.id == modelId).sizeBytes;
    for (var step = 1; step <= 5; step++) {
      yield (received: total ~/ 5 * step, total: total);
    }
  }

  @override
  Future<ModelBench> benchmark(String modelId) async {
    final model = fixtureModels.firstWhere((m) => m.id == modelId);
    return model.bench ??
        ModelBench(
          tokensPerSecond: 17,
          firstTokenMs: 900,
          residentBytes: model.sizeBytes,
          batteryPercentPerHour: 9,
          measuredUnder: ThermalState.nominal,
          measuredAtMs: fixtureNowMs,
        );
  }

  @override
  Stream<ThermalState> thermal() => Stream.value(ThermalState.nominal);
}

class _FixturePortability implements PortabilityPort {
  const _FixturePortability();

  /// Per-context bytes, split the way the design's bar splits them.
  static const Map<String, List<ContentClassSize>> _perContext = {
    'kneesurgery2026': [
      ContentClassSize('Scans', 620000000),
      ContentClassSize('Audio', 410000000),
      ContentClassSize('Log', 180000000),
    ],
    'downtownapartment': [
      ContentClassSize('Scans', 240000000),
      ContentClassSize('Audio', 190000000),
      ContentClassSize('Log', 90000000),
    ],
    'q3taxfiling': [
      ContentClassSize('Scans', 340000000),
      ContentClassSize('Audio', 180000000),
      ContentClassSize('Log', 120000000),
    ],
    'airoarchitecture': [
      ContentClassSize('Scans', 0),
      ContentClassSize('Audio', 0),
      ContentClassSize('Log', 30000000),
    ],
  };

  @override
  Future<RecoveryPackagePlan> plan(List<String> contextIds) async {
    var scans = 0;
    var audio = 0;
    var log = 0;
    for (final id in contextIds) {
      final bands = _perContext[id];
      if (bands == null) continue;
      scans += bands[0].bytes;
      audio += bands[1].bytes;
      log += bands[2].bytes;
    }
    return RecoveryPackagePlan(
      selectedContextIds: List.unmodifiable(contextIds),
      breakdown: [
        ContentClassSize('Scans', scans),
        ContentClassSize('Audio', audio),
        ContentClassSize('Log', log),
      ],
      fileName: 'airo-2026-08-01.airobackup',
    );
  }

  @override
  Stream<({int total, int written})> seal({
    required RecoveryPackagePlan plan,
    required String passphrase,
    required PackageDestination destination,
  }) async* {
    final total = plan.totalBytes;
    for (var step = 1; step <= 5; step++) {
      // A real scheduler turn between steps, not real wall-clock delay.
      // Without it every yield lands in the same microtask flush a caller's
      // single tester.pump() already drained, so a UI consuming this stream
      // could never actually observe a mid-seal frame -- the same "reports
      // real progress" principle ProjectionPort.rebuild and ModelPort.download
      // already hold elsewhere in this file.
      await Future<void>.delayed(Duration.zero);
      yield (written: total ~/ 5 * step, total: total);
    }
  }
}
