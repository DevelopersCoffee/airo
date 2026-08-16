import 'dart:async';

import 'package:core_ai/core_ai.dart' as core_ai;

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
  RustMindRuntime({ModelPort? models}) : models = models ?? _RustModels();

  @override
  final VaultPort vault = const _RustVault();

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

class _RustVault implements VaultPort {
  const _RustVault();

  static const String _issue = '#1207, #1208, #1210';

  @override
  Future<VaultState> state() async => _pending('VaultPort', _issue);

  @override
  Future<List<MindDevice>> devices() async => _pending('VaultPort', _issue);

  @override
  Future<void> revokeDevice(DeviceFingerprint fingerprint) async =>
      _pending('VaultPort', _issue);
}

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
/// [load], [unload], [benchmark], and [thermal] all require a model running
/// in real inference memory, which needs the Rust engine bindings tracked by
/// #1628 (`LlmBackend` trait + llama.cpp GGUF backend) and #1638 (the Flutter
/// plugin seam over that FFI) -- neither has landed, so these four stay
/// honest [MindPortUnavailable] stubs naming those issues. (The blanket
/// "#1260" every method here used to cite is Vault/Operation-Log FFI, not
/// model management -- it never actually gated this port; #1628/#1638 are
/// the issues that do.)
///
/// [ModelResidency] has three states -- `loaded` (in inference memory),
/// `resident` (held on disk by a specific capability), and `available` (not
/// on disk). Without a wired inference engine or a [CapabilityPort] that
/// tracks which capability holds which model (#1222, also unimplemented),
/// this class can only tell the true two-state story disk access gives it:
/// a downloaded, verified model reports as `resident` with an empty
/// [MindModel.heldBy] (nothing artificially blocks unloading it), never as
/// `loaded`.
class _RustModels implements ModelPort {
  _RustModels({
    core_ai.ModelDownloadService? downloadService,
    List<core_ai.OfflineModelInfo>? catalog,
  }) : _downloadService = downloadService ?? core_ai.ModelDownloadService(),
       _catalog = catalog ?? core_ai.ModelCatalog.bundledModels;

  static const String _runtimeIssue = '#1628, #1638';

  final core_ai.ModelDownloadService _downloadService;
  final List<core_ai.OfflineModelInfo> _catalog;

  core_ai.OfflineModelInfo? _findCatalogModel(String modelId) {
    for (final model in _catalog) {
      if (model.id == modelId) return model;
    }
    return null;
  }

  @override
  Future<List<MindModel>> all() async {
    final results = await Future.wait(
      _catalog.map((model) async {
        final downloaded = await _downloadService.isModelDownloaded(
          model.id,
          model: model,
        );
        return MindModel(
          id: model.id,
          name: model.name,
          sizeBytes: model.fileSizeBytes,
          residency: downloaded
              ? ModelResidency.resident
              : ModelResidency.available,
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
  Future<void> load(String modelId) async =>
      _pending('ModelPort', _runtimeIssue);

  @override
  Future<void> unload(String modelId) async =>
      _pending('ModelPort', _runtimeIssue);

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
  Future<ModelBench> benchmark(String modelId) async =>
      _pending('ModelPort', _runtimeIssue);

  @override
  Stream<ThermalState> thermal() => _pendingStream('ModelPort', _runtimeIssue);
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
