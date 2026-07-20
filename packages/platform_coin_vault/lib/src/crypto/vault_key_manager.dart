import 'dart:math';

import 'package:core_domain/core_domain.dart';
import 'package:local_auth/local_auth.dart';

/// Structural interface matching the subset of core_data's `SecureStorage`
/// that `VaultKeyManager` needs — lets the test fake avoid depending on
/// core_data's concrete import path while staying interface-compatible.
abstract interface class VaultKeyStore {
  Future<Result<String?>> read(String key);
  Future<Result<void>> write(String key, String value);
  Future<Result<void>> delete(String key);
  Future<Result<void>> deleteAll();
  Future<Result<bool>> containsKey(String key);
  Future<Result<List<String>>> getAllKeys();
}

const String _wrappedDekKey = 'airo_coin_wrapped_dek';

/// Biometric-gated encryption key manager for the Airo Coin vault.
///
/// The DEK (data-encryption key) is generated once and persisted via
/// [VaultKeyStore] — which is itself Keystore/Keychain-backed, acting as the
/// KEK boundary. No caller ever gets the key without a successful
/// biometric (or OS-fallback) authentication first.
class VaultKeyManager {
  VaultKeyManager({required LocalAuthentication localAuth, required VaultKeyStore secureStorage})
    : _authenticate = (() => localAuth.authenticate(
        localizedReason: 'Unlock your Airo Coin vault',
        options: const AuthenticationOptions(biometricOnly: false),
      )),
      _localAuth = localAuth,
      _secureStorage = secureStorage,
      _isAvailable = null;

  /// Test-only constructor: bypasses the real `local_auth` plugin and
  /// `flutter_secure_storage` platform channel, both of which are
  /// unavailable in plain `flutter test`.
  VaultKeyManager.forTesting({
    required VaultKeyStore secureStorage,
    required Future<bool> Function() authenticate,
    Future<bool> Function()? isAvailable,
  }) : _secureStorage = secureStorage,
       _authenticate = authenticate,
       _localAuth = null,
       _isAvailable = isAvailable;

  final VaultKeyStore _secureStorage;
  final Future<bool> Function() _authenticate;
  final LocalAuthentication? _localAuth;

  /// Test-only seam for [isEncryptionAvailable]. `null` (the default under
  /// the production constructor and under [forTesting] when not supplied)
  /// means "no fake configured" — [forTesting] callers get `true` to keep
  /// existing tests passing unchanged, while the production constructor
  /// always exercises the real `local_auth` checks below.
  final Future<bool> Function()? _isAvailable;

  Future<Result<List<int>>> getDatabaseKey() async {
    final bool authenticated;
    try {
      authenticated = await _authenticate();
    } catch (e) {
      return Failure(AuthFailure(message: 'Biometric authentication failed', cause: e));
    }
    if (!authenticated) {
      return const Failure(AuthFailure(message: 'Biometric authentication failed'));
    }

    final existing = await _secureStorage.read(_wrappedDekKey);
    if (existing case Success(value: final stored?)) {
      try {
        return Success(_decodeKey(stored));
      } catch (e) {
        return Failure(CacheFailure(message: 'Stored vault key is corrupted', cause: e));
      }
    }

    final newKey = _generateKeyBytes();
    final writeResult = await _secureStorage.write(_wrappedDekKey, _encodeKey(newKey));
    if (writeResult.isFailure) {
      return Failure(writeResult.failure);
    }
    return Success(newKey);
  }

  /// Rotates the stored DEK to a newly generated 32-byte key.
  ///
  /// **DESTRUCTIVE — DO NOT CALL IN PRODUCTION YET.** This overwrites the
  /// stored DEK without re-encrypting any existing vault data. Every record
  /// previously encrypted under the old DEK becomes permanently
  /// undecryptable the moment this returns success — there is no recovery
  /// path. No re-encryption migration exists in this package today; building
  /// one (decrypt all field-encrypted records under the old DEK, then
  /// re-encrypt under the new DEK, atomically) is a separate, larger effort
  /// tracked outside this fix pass. Callers must not invoke this in
  /// production until that migration exists.
  Future<Result<void>> rotateKey() async {
    final bool authenticated;
    try {
      authenticated = await _authenticate();
    } catch (e) {
      return Failure(AuthFailure(message: 'Biometric authentication failed', cause: e));
    }
    if (!authenticated) {
      return const Failure(AuthFailure(message: 'Biometric authentication failed'));
    }

    final newKey = _generateKeyBytes();
    return _secureStorage.write(_wrappedDekKey, _encodeKey(newKey));
  }

  Future<bool> isEncryptionAvailable() async {
    if (_localAuth == null) return _isAvailable?.call() ?? true;
    final canCheck = await _localAuth.canCheckBiometrics;
    final deviceSupported = await _localAuth.isDeviceSupported();
    return canCheck && deviceSupported;
  }

  Future<Result<void>> clearKeys() => _secureStorage.delete(_wrappedDekKey);

  List<int> _generateKeyBytes() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256));
  }

  String _encodeKey(List<int> bytes) => bytes.join(',');

  List<int> _decodeKey(String encoded) =>
      encoded.split(',').map(int.parse).toList();
}
