import '../models/mesh_models.dart';
import '../models/vault_models.dart';

/// Peer discovery and pairing over the local network. No relay, no account.
abstract interface class MeshPort {
  Stream<List<MindPeer>> peers();

  Stream<PairingRequest?> pendingRequest();

  Future<void> authorise(PairingRequest request);

  Future<void> deny(PairingRequest request);

  /// Pushes queued ops to one peer. Returns ops remaining when it settles.
  Future<int> push(DeviceFingerprint peer);
}
