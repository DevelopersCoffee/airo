import 'package:core_domain/core_domain.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'vault_key_manager.dart';

/// [VaultKeyStore] backed by `flutter_secure_storage` — Android Keystore /
/// iOS Keychain, same options pattern as core_data's `FlutterSecureStore`.
///
/// Not implemented against core_data's `SecureStorage`/`EncryptionKeyManager`
/// interfaces (`package:core_data/src/secure/secure_storage.dart`): that file
/// is not exported from `core_data.dart` and is not the pattern any other
/// package in the repo actually implements — `core_data`'s own
/// `FlutterSecureStore` implements the exported `SecureStore` interface
/// (`src/storage/secure_store.dart`) instead. `VaultKeyStore` is this
/// package's own minimal, `Result`-returning contract, defined locally so no
/// dependency on unexported `core_data` internals is needed.
class VaultSecureStorage implements VaultKeyStore {
  VaultSecureStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(
        aOptions: AndroidOptions.biometric(
          enforceBiometrics: true,
          storageNamespace: 'airo_coin_vault',
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
          accessControlFlags: [AccessControlFlag.biometryCurrentSet],
          accountName: 'airo_coin_vault',
        ),
      );

  final FlutterSecureStorage _storage;

  @override
  Future<Result<String?>> read(String key) async {
    try {
      return Success(await _storage.read(key: key));
    } catch (e) {
      return Failure(CacheFailure(message: 'Failed to read $key', cause: e));
    }
  }

  @override
  Future<Result<void>> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      return const Success(null);
    } catch (e) {
      return Failure(CacheFailure(message: 'Failed to write $key', cause: e));
    }
  }

  @override
  Future<Result<void>> delete(String key) async {
    try {
      await _storage.delete(key: key);
      return const Success(null);
    } catch (e) {
      return Failure(CacheFailure(message: 'Failed to delete $key', cause: e));
    }
  }

  @override
  Future<Result<void>> deleteAll() async {
    try {
      await _storage.deleteAll();
      return const Success(null);
    } catch (e) {
      return Failure(CacheFailure(message: 'Failed to delete all keys', cause: e));
    }
  }

  @override
  Future<Result<bool>> containsKey(String key) async {
    try {
      return Success(await _storage.containsKey(key: key));
    } catch (e) {
      return Failure(CacheFailure(message: 'Failed to check $key', cause: e));
    }
  }

  @override
  Future<Result<List<String>>> getAllKeys() async {
    try {
      final all = await _storage.readAll();
      return Success(all.keys.toList());
    } catch (e) {
      return Failure(CacheFailure(message: 'Failed to list keys', cause: e));
    }
  }
}
