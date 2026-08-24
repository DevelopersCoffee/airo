import 'dart:convert';
import 'dart:math';

import 'package:core_domain/core_domain.dart';

import '../secure/secure_storage.dart';
import 'flutter_secure_store.dart';
import 'secure_store.dart';

/// Platform secure-storage backed key manager for the encrypted LifeTrack DB.
class LifeTrackEncryptionKeyManager implements EncryptionKeyManager {
  LifeTrackEncryptionKeyManager({SecureStore? secureStore})
    : _secureStore = secureStore ?? SecureStoreFactory.createSecure();

  static const _storageKey = 'airo_lifetrack_db_encryption_key_v1';

  final SecureStore _secureStore;
  List<int>? _cachedKey;

  @override
  Future<Result<List<int>>> getDatabaseKey() async {
    if (_cachedKey != null) {
      return Ok(List<int>.from(_cachedKey!));
    }

    try {
      final stored = await _secureStore.read(key: _storageKey);
      if (stored != null && stored.isNotEmpty) {
        _cachedKey = base64Url.decode(stored);
        return Ok(List<int>.from(_cachedKey!));
      }

      final random = Random.secure();
      final newKey = List<int>.generate(32, (_) => random.nextInt(256));
      await _secureStore.write(
        key: _storageKey,
        value: base64Url.encode(newKey),
      );
      _cachedKey = newKey;
      return Ok(List<int>.from(newKey));
    } catch (error, stack) {
      return Err(
        SecureDestinationUnavailableError(
          'LifeTrack encryption key unavailable',
          originalError: error,
          originalStack: stack,
        ),
        stack,
      );
    }
  }

  @override
  Future<Result<void>> rotateKey() async {
    try {
      final random = Random.secure();
      final newKey = List<int>.generate(32, (_) => random.nextInt(256));
      await _secureStore.write(
        key: _storageKey,
        value: base64Url.encode(newKey),
      );
      _cachedKey = newKey;
      return const Ok(null);
    } catch (error, stack) {
      return Err(
        SecureDestinationUnavailableError(
          'LifeTrack encryption key rotation failed',
          originalError: error,
          originalStack: stack,
        ),
        stack,
      );
    }
  }

  @override
  Future<bool> isEncryptionAvailable() async {
    try {
      const probeKey = 'airo_lifetrack_secure_probe';
      await _secureStore.write(key: probeKey, value: 'ok');
      await _secureStore.delete(key: probeKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Result<void>> clearKeys() async {
    try {
      await _secureStore.delete(key: _storageKey);
      _cachedKey = null;
      return const Ok(null);
    } catch (error, stack) {
      return Err(error, stack);
    }
  }
}
