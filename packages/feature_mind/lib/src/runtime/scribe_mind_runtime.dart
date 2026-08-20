import 'fixture/fixture_mind_runtime.dart';
import 'mind_runtime.dart';
import 'ports/capability_port.dart';
import 'ports/context_port.dart';
import 'ports/mesh_port.dart';
import 'ports/model_port.dart';
import 'ports/operation_log_port.dart';
import 'ports/portability_port.dart';
import 'ports/projection_port.dart';
import 'ports/vault_port.dart';
import 'rust/rust_mind_runtime_vault.dart';

/// Mind runtime for the standalone scribe shell: Rust vault + op log, fixture
/// elsewhere unless a [ModelPort] is injected.
///
/// Production (`mindRuntimeProvider`) injects `createProductionModelPort` so
/// Model Bench and load/unload talk to the GGUF engine. Tests that omit
/// [models] keep the fixture catalog (invented tok/s, no native load).
///
/// [VaultPort] reads the vault opened when [MindService.initialize] boots the
/// whisper library (`meetings::initialize` → `open_mind_runtime`). Contexts,
/// projections, and mesh stay on fixtures until their issues land.
class ScribeMindRuntime implements MindRuntime {
  ScribeMindRuntime({
    required OperationLogPort log,
    VaultPort? vault,
    ModelPort? models,
  }) : _inner = FixtureMindRuntime(),
       _log = log,
       _vault = vault ?? const RustMindRuntimeVault(),
       _models = models;

  final FixtureMindRuntime _inner;
  final OperationLogPort _log;
  final VaultPort _vault;
  final ModelPort? _models;

  @override
  VaultPort get vault => _vault;

  @override
  OperationLogPort get log => _log;

  @override
  ContextPort get contexts => _inner.contexts;

  @override
  ProjectionPort get projections => _inner.projections;

  @override
  MeshPort get mesh => _inner.mesh;

  @override
  CapabilityPort get capabilities => _inner.capabilities;

  @override
  ModelPort get models => _models ?? _inner.models;

  @override
  PortabilityPort get portability => _inner.portability;
}
