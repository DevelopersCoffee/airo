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
  RustMindRuntime();

  @override
  final VaultPort vault = const _RustVault();

  @override
  final OperationLogPort log = const _RustLog();

  @override
  final ContextPort contexts = const _RustContexts();

  @override
  final ProjectionPort projections = const _RustProjections();

  @override
  final MeshPort mesh = const _RustMesh();

  @override
  final CapabilityPort capabilities = const _RustCapabilities();

  @override
  final ModelPort models = const _RustModels();

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

class _RustLog implements OperationLogPort {
  const _RustLog();

  static const String _issue = '#1213, #1214, #1215';

  @override
  Future<int> count() async => _pending('OperationLogPort', _issue);

  @override
  Future<List<MindOp>> range({required int offset, required int limit}) async =>
      _pending('OperationLogPort', _issue);

  @override
  Future<MindOp?> bySequence(int sequence) async =>
      _pending('OperationLogPort', _issue);

  @override
  Future<int> append({
    required MindOpKind kind,
    required String title,
    required String contextId,
    String detail = '',
  }) async => _pending('OperationLogPort', _issue);

  @override
  Future<SignatureState> verify(int sequence) async =>
      _pending('OperationLogPort', _issue);

  @override
  Stream<double> replayFrom(int sequence) =>
      _pendingStream('OperationLogPort', '#1216');
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

class _RustModels implements ModelPort {
  const _RustModels();

  static const String _issue = '#1260';

  @override
  Future<List<MindModel>> all() async => _pending('ModelPort', _issue);

  @override
  Future<({int budgetBytes, int usedBytes})> storage() async =>
      _pending('ModelPort', _issue);

  @override
  Future<void> load(String modelId) async => _pending('ModelPort', _issue);

  @override
  Future<void> unload(String modelId) async => _pending('ModelPort', _issue);

  @override
  Stream<({int received, int total})> download(String modelId) =>
      _pendingStream('ModelPort', _issue);

  @override
  Future<ModelBench> benchmark(String modelId) async =>
      _pending('ModelPort', _issue);

  @override
  Stream<ThermalState> thermal() => _pendingStream('ModelPort', _issue);
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
