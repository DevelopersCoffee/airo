import '../../whisper/api/mind_runtime.dart';
import 'rust_mind_runtime_ready.dart';
import '../mind_runtime.dart';
import '../models/vault_models.dart';
import '../ports/vault_port.dart';

/// Vault state and device list backed by the Rust mind runtime vault.
class RustMindRuntimeVault implements VaultPort {
  const RustMindRuntimeVault();

  static const String _issue = '#1207, #1208, #1210';

  bool get _rustReady => mindRuntimeRustReady();

  Never _unavailable(String detail) =>
      throw MindPortUnavailable('VaultPort', 'not implemented yet — $_issue ($detail)');

  @override
  Future<VaultState> state() async {
    if (!_rustReady) _unavailable('Mind runtime is not initialised');
    try {
      final wire = mindRuntimeVaultState();
      return VaultState(
        isSealed: wire.isSealed,
        keyCount: wire.keyCount.toInt(),
        revokedCount: wire.revokedCount.toInt(),
        revocationEpoch: wire.revocationEpoch.toInt(),
        onDiskBytes: wire.onDiskBytes.toInt(),
      );
    } on MindPortUnavailable {
      rethrow;
    } on Object {
      _unavailable('vault state read failed');
    }
  }

  @override
  Future<List<MindDevice>> devices() async {
    if (!_rustReady) _unavailable('Mind runtime is not initialised');
    try {
      final wires = mindRuntimeVaultDevices();
      return wires
          .map(
            (wire) => MindDevice(
              name: wire.name,
              fingerprint: DeviceFingerprint(
                wire.fingerprintA,
                wire.fingerprintB,
                wire.fingerprintC,
              ),
              isThisDevice: wire.isThisDevice,
              revokedAtMs: wire.revokedAtMs == BigInt.zero
                  ? null
                  : wire.revokedAtMs.toInt(),
            ),
          )
          .toList(growable: false);
    } on MindPortUnavailable {
      rethrow;
    } on Object {
      _unavailable('vault devices read failed');
    }
  }

  @override
  Future<void> revokeDevice(DeviceFingerprint fingerprint) async {
    if (!_rustReady) _unavailable('Mind runtime is not initialised');
    try {
      mindRuntimeRevokeVaultDevice(
        fingerprintA: fingerprint.a,
        fingerprintB: fingerprint.b,
        fingerprintC: fingerprint.c,
      );
    } on MindPortUnavailable {
      rethrow;
    } on Object {
      _unavailable('device revoke failed');
    }
  }
}
