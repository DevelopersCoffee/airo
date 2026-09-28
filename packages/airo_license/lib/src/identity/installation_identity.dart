import 'dart:math';

import '../storage/secure_storage.dart';

const kInstallationIdStorageKey = 'airo_license.installation_id';

/// Random installation identity. Not a hardware identifier.
class InstallationIdentity {
  InstallationIdentity({required LicenseSecureStorage storage, Random? random})
    : _storage = storage,
      _random = random ?? Random.secure();

  final LicenseSecureStorage _storage;
  final Random _random;

  Future<String> getOrCreateId() async {
    final existing = await _storage.read(kInstallationIdStorageKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _uuidV4();
    await _storage.write(kInstallationIdStorageKey, id);
    return id;
  }

  String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
    final b = bytes.map(hex).join();
    return '${b.substring(0, 8)}-${b.substring(8, 12)}-'
        '${b.substring(12, 16)}-${b.substring(16, 20)}-${b.substring(20)}';
  }
}

/// Placeholder key pair for the contract. Overlay builds replace this with
/// platform secure-enclave / keystore crypto. OSS never sends the private key.
abstract interface class InstallationKeyManager {
  Future<String?> publicKey();

  /// Device-held signature for installation-authenticated API calls.
  Future<String?> sign(String message);
}

/// In-memory / no-op keys. Does not talk to a network.
class MemoryInstallationKeyManager implements InstallationKeyManager {
  MemoryInstallationKeyManager({this.publicKeyValue});

  final String? publicKeyValue;

  @override
  Future<String?> publicKey() async => publicKeyValue;

  @override
  Future<String?> sign(String message) async => null;
}
