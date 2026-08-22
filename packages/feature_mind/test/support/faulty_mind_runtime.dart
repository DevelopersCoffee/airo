import 'package:feature_mind/src/runtime/fixture/fixture_mind_runtime.dart';
import 'package:feature_mind/src/runtime/mind_runtime.dart';
import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:feature_mind/src/runtime/ports/capability_port.dart';
import 'package:feature_mind/src/runtime/ports/context_port.dart';
import 'package:feature_mind/src/runtime/ports/mesh_port.dart';
import 'package:feature_mind/src/runtime/models/mesh_models.dart';
import 'package:feature_mind/src/runtime/ports/operation_log_port.dart';
import 'package:feature_mind/src/runtime/ports/vault_port.dart';
import 'package:feature_mind/src/runtime/models/vault_models.dart';
import 'package:feature_mind/src/runtime/ports/model_port.dart';
import 'package:feature_mind/src/runtime/ports/portability_port.dart';
import 'package:feature_mind/src/runtime/ports/projection_port.dart';

/// Delegates every sub-port to [FixtureMindRuntime] except explicit overrides.
class FaultyMindRuntime implements MindRuntime {
  FaultyMindRuntime(
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

class ThrowingOperationLogPort implements OperationLogPort {
  const ThrowingOperationLogPort({
    this.port = 'OperationLogPort',
    this.reason = 'not implemented yet — #1213',
  });

  final String port;
  final String reason;

  MindPortUnavailable get _error => MindPortUnavailable(port, reason);

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

class ThrowingMeshPort implements MeshPort {
  const ThrowingMeshPort({
    this.port = 'MeshPort',
    this.reason = 'not implemented yet — #1209',
  });

  final String port;
  final String reason;

  MindPortUnavailable get _error => MindPortUnavailable(port, reason);

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
