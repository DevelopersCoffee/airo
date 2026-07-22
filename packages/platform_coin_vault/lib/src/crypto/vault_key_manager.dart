// ignore_for_file: prefer_initializing_formals

import 'dart:math';

import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:local_auth/local_auth.dart';

const String _wrappedDekKey = 'airo_coin_wrapped_dek';

/// Biometric-gated encryption key manager for the Airo Coin vault.
///
/// The DEK (data-encryption key) is generated once and persisted via
/// [SecureStorage] (from `core_data`) — which is itself Keystore/Keychain-
/// backed, acting as the KEK boundary. No caller ever gets the key without a
/// successful biometric (or OS-fallback) authentication first.
class VaultKeyManager implements EncryptionKeyManager {
  VaultKeyManager({
    required LocalAuthentication localAuth,
    required SecureStorage secureStorage,
  }) : _authenticate = (() => localAuth.authenticate(
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
    required SecureStorage secureStorage,
    required Future<bool> Function() authenticate,
    Future<bool> Function()? isAvailable,
  }) : _secureStorage = secureStorage,
       _authenticate = authenticate,
       _localAuth = null,
       _isAvailable = isAvailable;

  final SecureStorage _secureStorage;
  final Future<bool> Function() _authenticate;
  final LocalAuthentication? _localAuth;

  /// Test-only seam for [isEncryptionAvailable]. `null` (the default under
  /// the production constructor and under [forTesting] when not supplied)
  /// means "no fake configured" — [forTesting] callers get `true` to keep
  /// existing tests passing unchanged, while the production constructor
  /// always exercises the real `local_auth` checks below.
  final Future<bool> Function()? _isAvailable;

  @override
  Future<Result<List<int>>> getDatabaseKey() async {
    final bool authenticated;
    try {
      authenticated = await _authenticate();
    } catch (e) {
      return Failure(
        AuthFailure(message: 'Biometric authentication failed', cause: e),
      );
    }
    if (!authenticated) {
      return const Failure(
        AuthFailure(message: 'Biometric authentication failed'),
      );
    }

    final existing = await _secureStorage.read(_wrappedDekKey);
    if (existing case Success(value: final stored?)) {
      try {
        return Success(_decodeKey(stored));
      } catch (e) {
        return Failure(
          CacheFailure(message: 'Stored vault key is corrupted', cause: e),
        );
      }
    }

    final newKey = _generateKeyBytes();
    final writeResult = await _secureStorage.write(
      _wrappedDekKey,
      _encodeKey(newKey),
    );
    if (writeResult.isFailure) {
      return Failure(writeResult.failure);
    }
    return Success(newKey);
  }

  /// Rotates the stored DEK to a newly generated 32-byte key.
  ///
  /// **DESTRUCTIVE — DO NOT CALL IN PRODUCTION.** This overwrites the stored
  /// DEK without re-encrypting any existing vault data; every record
  /// previously encrypted under the old DEK becomes permanently
  /// undecryptable the moment this returns success. For a safe rotation that
  /// re-encrypts existing data first, use
  /// `VaultKeyRotationService.rotateKeyWithReencryption()` instead — this raw
  /// primitive exists only to satisfy `EncryptionKeyManager`'s interface
  /// contract.
  @override
  Future<Result<void>> rotateKey() async {
    final bool authenticated;
    try {
      authenticated = await _authenticate();
    } catch (e) {
      return Failure(
        AuthFailure(message: 'Biometric authentication failed', cause: e),
      );
    }
    if (!authenticated) {
      return const Failure(
        AuthFailure(message: 'Biometric authentication failed'),
      );
    }

    final newKey = _generateKeyBytes();
    return _secureStorage.write(_wrappedDekKey, _encodeKey(newKey));
  }

  /// Generates a new candidate DEK without persisting it. Pair with
  /// [commitRotatedKey] via `VaultKeyRotationService.rotateKeyWithReencryption()`
  /// — never call [commitRotatedKey] with a candidate key before all vault
  /// data has been re-encrypted under it.
  List<int> generateCandidateKey() => _generateKeyBytes();

  /// Persists [newKeyBytes] as the active DEK. Only call this after all
  /// vault data has been re-encrypted under [newKeyBytes] — see
  /// `VaultKeyRotationService.rotateKeyWithReencryption()`.
  Future<Result<void>> commitRotatedKey(List<int> newKeyBytes) async {
    final bool authenticated;
    try {
      authenticated = await _authenticate();
    } catch (e) {
      return Failure(
        AuthFailure(message: 'Biometric authentication failed', cause: e),
      );
    }
    if (!authenticated) {
      return const Failure(
        AuthFailure(message: 'Biometric authentication failed'),
      );
    }
    return _secureStorage.write(_wrappedDekKey, _encodeKey(newKeyBytes));
  }

  /// Persists [newKeyBytes] as the active DEK WITHOUT re-authenticating.
  ///
  /// **Internal/trusted-caller primitive — do not call this directly.** It
  /// intentionally skips biometric re-authentication because it must only be
  /// called by `VaultKeyRotationService.rotateKeyWithReencryption()`
  /// immediately after a single upstream [getDatabaseKey] auth has already
  /// gated the whole rotation operation. Calling this independently of that
  /// flow would persist a new DEK with no authentication check at all.
  Future<Result<void>> persistRotatedKeyUnauthenticated(
    List<int> newKeyBytes,
  ) => _secureStorage.write(_wrappedDekKey, _encodeKey(newKeyBytes));

  @override
  Future<bool> isEncryptionAvailable() async {
    if (_localAuth == null) return _isAvailable?.call() ?? true;
    final canCheck = await _localAuth.canCheckBiometrics;
    final deviceSupported = await _localAuth.isDeviceSupported();
    return canCheck && deviceSupported;
  }

  @override
  Future<Result<void>> clearKeys() => _secureStorage.delete(_wrappedDekKey);

  List<int> _generateKeyBytes() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256));
  }

  String _encodeKey(List<int> bytes) => bytes.join(',');

  List<int> _decodeKey(String encoded) =>
      encoded.split(',').map(int.parse).toList();
}
