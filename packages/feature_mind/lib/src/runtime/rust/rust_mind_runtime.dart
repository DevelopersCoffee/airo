import 'dart:async';

import 'package:core_ai/core_ai.dart' as core_ai;
import 'package:flutter/foundation.dart';

import '../mind_runtime.dart';
import '../models/capability_models.dart';
import '../models/context_models.dart';
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
import '../persistent/persistent_operation_log.dart'
    show LazyPersistentOperationLog;
import '../persistent/rust_preferred_operation_log.dart';
import '../ports/portability_port.dart';
import '../ports/projection_port.dart';
import '../ports/vault_port.dart';
import '../../model_bench/generation_bench_runner.dart';
import '../../model_bench/generation_engine_controller.dart';
import '../../model_bench/model_bench_protocol.dart';
import 'rust_mind_runtime_vault.dart';

/// The real runtime, honest about what milestone 19 has not landed.
///
/// Every method here either delegates to a `rust/airo_mind_*` engine or reports
/// [MindPortUnavailable] naming its port and the issue that fills it in. As
/// those issues land, methods are replaced one at a time and no surface
/// changes — that is what the port bought.
///
/// This is the only file in the module allowed to import the generated bridge.
/// Nothing else may reach `src/api/` or `frb_generated`.
class RustMindRuntime implements MindRuntime {
  RustMindRuntime({
    ModelPort? models,
    GenerationBenchRunner? benchRunner,
    GenerationEngineController? engine,
    GenerationBenchMetadata? benchMetadata,
    @visibleForTesting core_ai.ModelDownloadService? downloadService,
    @visibleForTesting List<core_ai.OfflineModelInfo>? catalog,
    @visibleForTesting int? warmupIterations,
    @visibleForTesting int? timedIterations,
    @visibleForTesting Future<ThermalState> Function()? readThermal,
    @visibleForTesting Stream<ThermalState>? thermal,
  }) : models =
           models ??
           _RustModels(
             downloadService: downloadService,
             catalog: catalog,
             benchRunner: benchRunner,
             engine: engine,
             benchMetadata: benchMetadata,
             warmupIterations: warmupIterations,
             timedIterations: timedIterations,
             readThermal: readThermal,
             thermal: thermal,
           );

  @override
  final VaultPort vault = const RustMindRuntimeVault();

  @override
  final OperationLogPort log = RustPreferredOperationLog(
    LazyPersistentOperationLog(),
  );

  @override
  final ContextPort contexts = const _RustContexts();

  @override
  final ProjectionPort projections = const _RustProjections();

  @override
  final MeshPort mesh = const _RustMesh();

  @override
  final CapabilityPort capabilities = const _RustCapabilities();

  @override
  final ModelPort models;

  @override
  final PortabilityPort portability = const _RustPortability();
}

/// Reports a port as unimplemented from a `Future`-returning method.
///
/// Returns [Never] so a method body can be a single expression and still
/// satisfy any return type.
Never _pending(String port, String issue) =>
    throw MindPortUnavailable(port, 'not implemented yet — $issue');

/// The stream equivalent.
///
/// Streams fail on the stream rather than at call time: a surface subscribes
/// and renders an error state, where a synchronous throw would crash it before
/// the subscription formed.
Stream<T> _pendingStream<T>(String port, String issue) =>
    Stream<T>.error(MindPortUnavailable(port, 'not implemented yet — $issue'));

class _RustContexts implements ContextPort {
  const _RustContexts();

  static const String _issue = '#1228, #1229';

  @override
  Future<List<MindContext>> all() async => _pending('ContextPort', _issue);

  @override
  Future<MindContext?> byId(String id) async => _pending('ContextPort', _issue);

  @override
  Future<List<ContextLink>> linksFor(String contextId) async =>
      _pending('ContextPort', _issue);

  @override
  Future<MindContext> create({required String label}) async =>
      _pending('ContextPort', _issue);

  @override
  Future<void> link(String fromId, String toId) async =>
      _pending('ContextPort', _issue);

  @override
  Future<void> unlink(String fromId, String toId) async =>
      _pending('ContextPort', _issue);

  @override
  Future<List<String>> survivorsIfDestroyed(String contextId) async =>
      _pending('ContextPort', _issue);
}

class _RustProjections implements ProjectionPort {
  const _RustProjections();

  static const String _issue = '#1218, #1219, #1220';

  @override
  Future<ProjectionState> stateOf(ProjectionKind kind) async =>
      _pending('ProjectionPort', _issue);

  @override
  Future<List<ProjectionState>> states() async =>
      _pending('ProjectionPort', _issue);

  @override
  Stream<ProjectionState> rebuild(ProjectionKind kind) =>
      _pendingStream('ProjectionPort', _issue);

  @override
  Future<List<SearchHitRef>> search(String query, {String? contextId}) async =>
      _pending('ProjectionPort', _issue);
}

class _RustMesh implements MeshPort {
  const _RustMesh();

  static const String _issue = '#1200';

  @override
  Stream<List<MindPeer>> peers() => _pendingStream('MeshPort', _issue);

  @override
  Stream<PairingRequest?> pendingRequest() =>
      _pendingStream('MeshPort', _issue);

  @override
  Future<void> authorise(PairingRequest request) async =>
      _pending('MeshPort', _issue);

  @override
  Future<void> deny(PairingRequest request) async =>
      _pending('MeshPort', _issue);

  @override
  Future<int> push(DeviceFingerprint peer) async =>
      _pending('MeshPort', _issue);
}

class _RustCapabilities implements CapabilityPort {
  const _RustCapabilities();

  static const String _issue = '#1222';

  @override
  Future<List<InstalledCapability>> installed() async =>
      _pending('CapabilityPort', _issue);

  @override
  Future<InstalledCapability?> byId(String id) async =>
      _pending('CapabilityPort', _issue);

  @override
  Future<void> setActive(String id, {required bool active}) async =>
      _pending('CapabilityPort', _issue);

  @override
  Future<void> remove(String id) async => _pending('CapabilityPort', _issue);
}

/// Real (non-fixture) [ModelPort], backed by `core_ai`'s already-proven
/// download/storage pipeline -- the same `ModelDownloadService` and
/// `ModelStorageManager` `model_provider.dart`'s `DownloadModelProvider`
/// already uses for Mind's own whisper models.
///
/// # What is real here, and what still is not
///
/// [all], [storage], and [download] only need a catalog and a disk, so they
/// are implemented for real: resumable, checksum-verified, atomically
/// installed downloads, and an on-disk storage budget [core_ai]'s
/// `ModelStorageManager.enforceStorageQuota` actually enforces by deleting
/// files, not merely a RAM-residency cache that leaves every past download
/// on disk forever. [ModelManagementPanel] no longer has to run against
/// [FixtureMindRuntime] to exercise that behavior.
///
/// [load], [unload] stay [MindPortUnavailable] naming #1628/#1638 until a
/// [GenerationEngineController] is injected — typically
/// [LlamaGgufEngineController] over [LlamaGgufService]. With a controller,
/// [load] hydrates the on-disk path and asks the GGUF adapter to put the
/// model in inference memory; [all] then reports that id as
/// [ModelResidency.loaded]. Without a controller those two stay honest
/// stubs rather than pretending RAM residency.
///
/// [benchmark] runs the generation-bench protocol (warmup, median, backend
/// metadata including CUDA as a Windows seam) when a [GenerationBenchRunner]
/// is injected — typically [LlamaGgufBenchRunner] or
/// [BridgeGenerationBenchRunner] over a loaded llama engine. With no runner
/// it still reports unavailable rather than inventing tok/s. [thermal]
/// probes the device capability channel and emits on change.
///
/// [ModelResidency] has three states -- `loaded` (in inference memory),
/// `resident` (held on disk by a specific capability), and `available` (not
/// on disk). Without a wired inference engine or a [CapabilityPort] that
/// tracks which capability holds which model (#1222, also unimplemented),
/// this class can only tell the true two-state story disk access gives it:
/// a downloaded, verified model reports as `resident` with an empty
/// [MindModel.heldBy] (nothing artificially blocks unloading it), never as
/// `loaded` — unless a [GenerationEngineController] reports that id as
/// currently in inference memory.
class _RustModels implements ModelPort {
  _RustModels({
    core_ai.ModelDownloadService? downloadService,
    List<core_ai.OfflineModelInfo>? catalog,
    GenerationBenchRunner? benchRunner,
    GenerationEngineController? engine,
    GenerationBenchMetadata? benchMetadata,
    int? warmupIterations,
    int? timedIterations,
    Future<ThermalState> Function()? readThermal,
    Stream<ThermalState>? thermal,
  }) : _downloadService = downloadService ?? core_ai.ModelDownloadService(),
       _catalog = catalog ?? core_ai.ModelCatalog.bundledModels,
       _benchRunner = benchRunner,
       _engine = engine,
       _benchMetadata = benchMetadata ?? const GenerationBenchMetadata(),
       _warmupIterations = warmupIterations ?? kModelBenchWarmupIterations,
       _timedIterations = timedIterations ?? kModelBenchTimedIterations,
       _readThermal = readThermal,
       _thermal = thermal;

  static const String _runtimeIssue = '#1628, #1638';
  static const Duration _thermalPollInterval = Duration(seconds: 15);

  final core_ai.ModelDownloadService _downloadService;
  final List<core_ai.OfflineModelInfo> _catalog;
  final GenerationBenchRunner? _benchRunner;
  final GenerationEngineController? _engine;
  final GenerationBenchMetadata _benchMetadata;
  final int _warmupIterations;
  final int _timedIterations;
  final Future<ThermalState> Function()? _readThermal;
  final Stream<ThermalState>? _thermal;

  core_ai.OfflineModelInfo? _findCatalogModel(String modelId) {
    for (final model in _catalog) {
      if (model.id == modelId) return model;
    }
    return null;
  }

  @override
  Future<List<MindModel>> all() async {
    final loadedId = _engine?.loadedModelId;
    final results = await Future.wait(
      _catalog.map((model) async {
        final downloaded = await _downloadService.isModelDownloaded(
          model.id,
          model: model,
        );
        final residency = loadedId == model.id
            ? ModelResidency.loaded
            : downloaded
            ? ModelResidency.resident
            : ModelResidency.available;
        return MindModel(
          id: model.id,
          name: model.name,
          sizeBytes: model.fileSizeBytes,
          residency: residency,
        );
      }),
    );
    return results;
  }

  @override
  Future<({int budgetBytes, int usedBytes})> storage() async {
    final usedBytes = await _downloadService.storageManager
        .installedArtifactsTotalBytes();
    return (
      usedBytes: usedBytes,
      budgetBytes: _downloadService.storageBudgetBytes,
    );
  }

  @override
  Future<void> load(String modelId) async {
    final engine = _engine;
    if (engine == null) return _pending('ModelPort', _runtimeIssue);
    final catalogModel = _findCatalogModel(modelId);
    if (catalogModel == null) {
      return _pending(
        'ModelPort',
        'unknown model id "$modelId" -- not in the catalog',
      );
    }
    final path = await _downloadService.resolveExistingModelPath(
      catalogModel.id,
      model: catalogModel,
    );
    if (path == null) {
      return _pending(
        'ModelPort',
        'model "$modelId" is not on disk — download it before loading',
      );
    }
    try {
      await engine.load(catalogModel.copyWith(filePath: path));
    } on Object catch (error) {
      return _pending('ModelPort', 'load failed — $_runtimeIssue ($error)');
    }
  }

  @override
  Future<void> unload(String modelId) async {
    final engine = _engine;
    if (engine == null) return _pending('ModelPort', _runtimeIssue);
    if (engine.loadedModelId != modelId) return;
    try {
      await engine.unload();
    } on Object catch (error) {
      return _pending('ModelPort', 'unload failed — $_runtimeIssue ($error)');
    }
  }

  @override
  Stream<({int received, int total})> download(String modelId) {
    final model = _findCatalogModel(modelId);
    if (model == null) {
      return _pendingStream(
        'ModelPort',
        'unknown model id "$modelId" -- not in the catalog',
      );
    }
    return _downloadService
        .downloadModel(model)
        .transform(
          StreamTransformer<
            core_ai.ModelDownloadProgress,
            ({int received, int total})
          >.fromHandlers(
            handleData: (progress, sink) {
              sink.add((
                received: progress.downloadedBytes,
                total: progress.totalBytes,
              ));
              switch (progress.status) {
                case core_ai.ModelDownloadStatus.completed:
                  sink.close();
                case core_ai.ModelDownloadStatus.failed:
                case core_ai.ModelDownloadStatus.cancelled:
                  sink.addError(
                    MindPortUnavailable(
                      'ModelPort',
                      progress.error ?? 'download did not complete',
                    ),
                  );
                  sink.close();
                case core_ai.ModelDownloadStatus.pending:
                case core_ai.ModelDownloadStatus.downloading:
                case core_ai.ModelDownloadStatus.paused:
                case core_ai.ModelDownloadStatus.verifying:
                  break;
              }
            },
          ),
        );
  }

  @override
  Future<ModelBench> benchmark(String modelId) async {
    final catalogModel = _findCatalogModel(modelId);
    if (catalogModel == null) {
      return _pending(
        'ModelPort',
        'unknown model id "$modelId" -- not in the catalog',
      );
    }
    final downloaded = await _downloadService.isModelDownloaded(
      catalogModel.id,
      model: catalogModel,
    );
    if (!downloaded) {
      return _pending(
        'ModelPort',
        'model "$modelId" is not on disk — download it before benchmarking',
      );
    }
    final runner = _benchRunner;
    if (runner == null) {
      return _pending('ModelPort', _runtimeIssue);
    }
    final GenerationBenchReport report;
    try {
      report = await runGenerationBench(
        sample: runner.sample,
        warmupIterations: _warmupIterations,
        timedIterations: _timedIterations,
        metadata: _benchMetadata,
      );
    } on Object catch (error) {
      return _pending(
        'ModelPort',
        'generation bench failed — $_runtimeIssue ($error)',
      );
    }
    return report.toModelBench(
      residentBytes: catalogModel.fileSizeBytes,
      measuredUnder: await _currentThermal(),
      measuredAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<ThermalState> _currentThermal() async {
    final readThermal = _readThermal;
    if (readThermal != null) return readThermal();
    try {
      final device = await core_ai.DeviceCapabilityService().getDeviceInfo();
      return thermalStateFromSummary(device.thermalSummary);
    } on Object {
      return ThermalState.nominal;
    }
  }

  @override
  Stream<ThermalState> thermal() {
    final thermal = _thermal;
    if (thermal != null) return thermal;
    return _probeThermal();
  }

  Stream<ThermalState> _probeThermal() async* {
    ThermalState? last;
    while (true) {
      final next = await _currentThermal();
      if (last != next) {
        last = next;
        yield next;
      }
      await Future<void>.delayed(_thermalPollInterval);
    }
  }
}

class _RustPortability implements PortabilityPort {
  const _RustPortability();

  static const String _issue = '#1211, #1305';

  @override
  Future<RecoveryPackagePlan> plan(List<String> contextIds) async =>
      _pending('PortabilityPort', _issue);

  @override
  Stream<({int total, int written})> seal({
    required RecoveryPackagePlan plan,
    required String passphrase,
    required PackageDestination destination,
  }) => _pendingStream('PortabilityPort', _issue);
}
