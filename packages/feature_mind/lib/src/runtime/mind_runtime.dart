import 'ports/capability_port.dart';
import 'ports/context_port.dart';
import 'ports/mesh_port.dart';
import 'ports/model_port.dart';
import 'ports/operation_log_port.dart';
import 'ports/portability_port.dart';
import 'ports/projection_port.dart';
import 'ports/vault_port.dart';

/// One sub-port is not implemented on this runtime yet.
///
/// Names the port rather than the product. "Airo Mind is unavailable" tells a
/// person nothing; "the mesh is not implemented yet" tells them the rest of
/// the app works, which is true and useful while milestone 19 lands.
class MindPortUnavailable implements Exception {
  const MindPortUnavailable(this.port, this.reason);

  final String port;
  final String reason;

  @override
  String toString() => 'MindPortUnavailable: $port — $reason';
}

/// Everything a Mind surface is allowed to do.
///
/// Eight sub-ports rather than one wide interface so a screen depends on the
/// slice it uses. The Devices screen takes a [MeshPort] and a [VaultPort]; it
/// has no way to reach the model downloader.
///
/// This is the contract milestone 19 implements against. A runtime that cannot
/// satisfy a method here files an ADR — it does not quietly reshape the port.
abstract interface class MindRuntime {
  /// The eight names, for the conformance test that guards against a ninth.
  static const Set<String> portNames = {
    'vault',
    'log',
    'contexts',
    'projections',
    'mesh',
    'capabilities',
    'models',
    'portability',
  };

  VaultPort get vault;
  OperationLogPort get log;
  ContextPort get contexts;
  ProjectionPort get projections;
  MeshPort get mesh;
  CapabilityPort get capabilities;
  ModelPort get models;
  PortabilityPort get portability;
}
