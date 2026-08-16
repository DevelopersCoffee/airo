import '../fixture/fixture_mind_runtime.dart';
import '../mind_runtime.dart';
import '../ports/capability_port.dart';
import '../ports/context_port.dart';
import '../ports/mesh_port.dart';
import '../ports/model_port.dart';
import '../ports/operation_log_port.dart';
import '../ports/portability_port.dart';
import '../ports/projection_port.dart';
import '../ports/vault_port.dart';

/// Mind runtime for the standalone scribe shell: real durable log, fixture elsewhere.
///
/// Wave 2 wire-up until `RustMindRuntime.log` ships (#1213). Assistant consent
/// and meeting IR extraction append to the same file [MindService] uses.
class ScribeMindRuntime implements MindRuntime {
  ScribeMindRuntime({required OperationLogPort log})
    : _inner = FixtureMindRuntime(),
      _log = log;

  final FixtureMindRuntime _inner;
  final OperationLogPort _log;

  @override
  VaultPort get vault => _inner.vault;

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
  ModelPort get models => _inner.models;

  @override
  PortabilityPort get portability => _inner.portability;
}
