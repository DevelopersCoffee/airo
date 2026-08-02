import '../models/vault_models.dart';

/// Root identity, device keys, and revocation.
///
/// Read-only from the surfaces' point of view except for [revokeDevice] —
/// authorising and revoking are the only two writes a person makes here, and
/// both are deliberate acts with their own confirmation.
abstract interface class VaultPort {
  Future<VaultState> state();

  /// Authorised devices, revoked ones included. Revoked devices are evidence
  /// and stay in the list.
  Future<List<MindDevice>> devices();

  /// Revokes every key held by [fingerprint] at once.
  ///
  /// O(contexts), never O(content): the wrapping keys are re-wrapped, the
  /// ciphertext is untouched.
  Future<void> revokeDevice(DeviceFingerprint fingerprint);
}
