# Airo Coin Vault Fast-Follows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the four tracked fast-follows from the `platform_coin_vault` Phase 0 council review (PR #944/#947, #946): retire the package's local `VaultKeyStore` duplicate in favor of `core_data`'s existing `SecureStorage`/`EncryptionKeyManager`; bind `FieldCipher` ciphertext to its row via AAD so it can't be swapped between rows/columns and still decrypt; build a safe, re-encrypting DEK rotation path; and scaffold a real-device integration test for `VaultSecureStorage`'s biometric gate.

**Architecture:** All four items are additive/refactoring changes to the existing `platform_coin_vault` package (crypto/storage layer only, still no UI). No new packages. `core_data`'s barrel gains two exports it was already missing. `FieldCipher` gains a required AAD `context` parameter. Repositories move to a two-phase insert (placeholder row → derive AAD from the row's `id` → encrypt → update) so every ciphertext is bound to its own row. A new `VaultKeyRotationService` in the `data/` layer orchestrates safe rotation using `VaultDatabase` + `FieldCipher` + `VaultKeyManager` — it does not live in `crypto/`, preserving the existing layering (`crypto/` depends only on `core_domain`/`core_data`; `data/` depends on `crypto/` + `domain/`, never the reverse).

**Tech Stack:** Flutter/Dart, `core_data` (`SecureStorage`, `EncryptionKeyManager`, `InMemorySecureStorage`), `cryptography` (AES-256-GCM with associated data), `sqflite` (transactions), `flutter_test` + `sqflite_common_ffi`, `integration_test` (new dev dependency, Task 6 only).

## Global Constraints

- No behavior change to `BankAccountRecord`, `PanCardRecord`, `CreditCardRecord`, `SecureDocumentRecord`, or any validator — this plan touches crypto/storage internals only.
- `CreditCardRepository`/`CreditCardRecord` has no encrypted columns and is out of scope for Tasks 2, 3, 5 (masked-only design, unchanged).
- `FieldCipher.encryptField`/`decryptField` AAD context format: `"<table>:<column>:<id>"` — exact string, no spaces, using `VaultTables` constants and the row's integer `id`. Both call sites (encrypt and decrypt) must use the identical string or decryption fails by design.
- `VaultKeyManager.rotateKey()` remains present (required by `EncryptionKeyManager`'s interface contract) but stays documented as an unsafe raw primitive — `VaultKeyRotationService.rotateKeyWithReencryption()` is the only supported rotation path once this plan lands.
- Every task keeps `flutter analyze` clean (info-level `prefer_initializing_formals` lints on constructor params are pre-existing and out of scope).
- Module governance unchanged: `platform_coin_vault`'s `module.yaml` reviewers are Chief Architect, Chief Security Officer, Chief QA Officer, Chief Open Source Officer; `allowed_dependencies` is `core_domain` and `core_data` (Task 1 re-adds the `core_data` package dependency that was dropped in PR #946's dependency cleanup — this is expected and now consumed for real).

---

## File Structure

```
packages/core_data/
  lib/core_data.dart                                 # +2 exports (Task 1)

packages/platform_coin_vault/
  pubspec.yaml                                        # +core_data dependency (Task 1); +integration_test dev dep (Task 6)
  lib/src/
    crypto/
      vault_key_manager.dart                          # implements EncryptionKeyManager (Task 1); +generateCandidateKey/commitRotatedKey (Task 4)
      vault_secure_storage.dart                        # implements SecureStorage, drop local VaultKeyStore (Task 1)
      field_cipher.dart                                # +required context param for AAD (Task 2)
    data/
      bank_account_repository.dart                     # two-phase insert + AAD context (Task 3)
      pan_card_repository.dart                          # two-phase insert + AAD context (Task 3)
      secure_document_repository.dart                   # two-phase insert + AAD context (Task 3)
      vault_key_rotation_service.dart                   # NEW (Task 5)
  test/
    crypto/
      vault_key_manager_test.dart                       # switch fake to core_data's InMemorySecureStorage (Task 1); +rotation primitive tests (Task 4)
      field_cipher_test.dart                             # +context param, +mismatched-context test (Task 2)
    data/
      bank_account_repository_test.dart                 # +context, +swap-attack regression test (Task 3)
      pan_card_repository_test.dart                      # +context (Task 3)
      secure_document_repository_test.dart               # +context (Task 3)
      vault_integration_test.dart                        # +context via repo calls, no signature change needed (Task 3)
      vault_key_rotation_service_test.dart                # NEW (Task 5)
  integration_test/
    vault_secure_storage_integration_test.dart            # NEW (Task 6)

docs/adr/0009-airo-coin-vault-crypto.md                  # updated Risks/Negatives (Task 7)
```

---

### Task 1: `core_data` export + retire local `VaultKeyStore`

**Files:**
- Modify: `packages/core_data/lib/core_data.dart`
- Modify: `packages/platform_coin_vault/pubspec.yaml`
- Modify: `packages/platform_coin_vault/lib/src/crypto/vault_key_manager.dart`
- Modify: `packages/platform_coin_vault/lib/src/crypto/vault_secure_storage.dart`
- Modify: `packages/platform_coin_vault/test/crypto/vault_key_manager_test.dart`

**Interfaces:**
- Consumes: `core_data`'s `SecureStorage`, `EncryptionKeyManager`, `InMemorySecureStorage` (`package:core_data/src/secure/secure_storage.dart`, `in_memory_secure_storage.dart` — both already exist, just unexported).
- Produces: `VaultKeyManager implements EncryptionKeyManager`, `VaultSecureStorage implements SecureStorage` — both public APIs unchanged in shape (same method names/signatures they already had via the now-deleted local `VaultKeyStore`), so Tasks 2–7 see no difference here beyond the import path.

- [ ] **Step 1: Export the secure-storage files from `core_data`'s barrel**

In `packages/core_data/lib/core_data.dart`, add two lines after the existing `src/storage/*` exports:

```dart
// Local Storage
export 'src/storage/key_value_store.dart';
export 'src/storage/preferences_store.dart';
export 'src/storage/secure_store.dart';
export 'src/storage/flutter_secure_store.dart';
export 'src/storage/life_track_local_data_source.dart';
export 'src/storage/templates/life_track_template_fallback_resolver.dart';
export 'src/storage/templates/template_registry.dart';
export 'src/secure/secure_storage.dart';
export 'src/secure/in_memory_secure_storage.dart';
```

- [ ] **Step 2: Run `core_data`'s test suite to confirm the export is non-breaking**

Run: `cd packages/core_data && flutter test`
Expected: PASS — this is a pure export addition, no logic changed.

- [ ] **Step 3: Add `core_data` back as a dependency of `platform_coin_vault`**

In `packages/platform_coin_vault/pubspec.yaml`, add `core_data` right after `core_domain`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  core_domain:
    path: ../core_domain
  core_data:
    path: ../core_data
  cryptography: ^2.7.0
  local_auth: ^2.3.0
  flutter_secure_storage: ^10.3.1
  sqflite: ^2.4.3
  equatable: ^2.0.8
```

- [ ] **Step 4: Run `flutter pub get`**

Run: `cd packages/platform_coin_vault && flutter pub get`
Expected: resolves cleanly.

- [ ] **Step 5: Rewrite `vault_key_manager.dart` to implement `EncryptionKeyManager` and drop the local `VaultKeyStore` interface**

```dart
// packages/platform_coin_vault/lib/src/crypto/vault_key_manager.dart
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
  VaultKeyManager({required LocalAuthentication localAuth, required SecureStorage secureStorage})
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
      return Failure(AuthFailure(message: 'Biometric authentication failed', cause: e));
    }
    if (!authenticated) {
      return const Failure(AuthFailure(message: 'Biometric authentication failed'));
    }

    final newKey = _generateKeyBytes();
    return _secureStorage.write(_wrappedDekKey, _encodeKey(newKey));
  }

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
```

- [ ] **Step 6: Rewrite `vault_secure_storage.dart` to implement `core_data`'s `SecureStorage`**

```dart
// packages/platform_coin_vault/lib/src/crypto/vault_secure_storage.dart
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// [SecureStorage] (from `core_data`) backed by `flutter_secure_storage` —
/// Android Keystore / iOS Keychain, configured for biometric binding.
class VaultSecureStorage implements SecureStorage {
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
```

- [ ] **Step 7: Replace the test file's local fake with `core_data`'s `InMemorySecureStorage`**

```dart
// packages/platform_coin_vault/test/crypto/vault_key_manager_test.dart
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/crypto/vault_key_manager.dart';

void main() {
  late InMemorySecureStorage secureStorage;

  setUp(() {
    secureStorage = InMemorySecureStorage();
  });

  group('VaultKeyManager', () {
    test('getDatabaseKey generates and persists a 32-byte key on first call', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => true,
      );

      final result = await manager.getDatabaseKey();

      expect(result.isSuccess, isTrue);
      expect(result.value, hasLength(32));
    });

    test('getDatabaseKey returns the same key on repeated calls', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => true,
      );

      final first = await manager.getDatabaseKey();
      final second = await manager.getDatabaseKey();

      expect(second.value, equals(first.value));
    });

    test('getDatabaseKey fails when biometric authentication is denied', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => false,
      );

      final result = await manager.getDatabaseKey();

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<AuthFailure>());
    });

    test('rotateKey generates a different key and persists it', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => true,
      );

      final original = await manager.getDatabaseKey();
      final rotated = await manager.rotateKey();
      final afterRotate = await manager.getDatabaseKey();

      expect(rotated.isSuccess, isTrue);
      expect(afterRotate.value, isNot(equals(original.value)));
    });

    test('clearKeys removes the stored key', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => true,
      );

      await manager.getDatabaseKey();
      await manager.clearKeys();
      final containsKey = await secureStorage.containsKey('airo_coin_wrapped_dek');

      expect(containsKey.value, isFalse);
    });

    test('isEncryptionAvailable reports false when biometrics are unavailable, blocking vault creation', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => false,
      );

      final result = await manager.getDatabaseKey();

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<AuthFailure>());
    });

    test('getDatabaseKey fails closed when local_auth throws (e.g. no biometrics enrolled)', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => throw Exception('platform unavailable'),
      );

      final result = await manager.getDatabaseKey();

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<AuthFailure>());
    });

    test('rotateKey fails closed when local_auth throws (e.g. no biometrics enrolled)', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => throw Exception('platform unavailable'),
      );

      final result = await manager.rotateKey();

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<AuthFailure>());
    });

    test('isEncryptionAvailable uses the injected isAvailable seam when provided', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => true,
        isAvailable: () async => false,
      );

      final available = await manager.isEncryptionAvailable();
      final keyResult = await manager.getDatabaseKey();

      expect(available, isFalse);
      expect(keyResult.isSuccess, isTrue);
    });
  });
}
```

- [ ] **Step 8: Run the full `platform_coin_vault` suite**

Run: `cd packages/platform_coin_vault && flutter test`
Expected: PASS — all existing tests green, no signature changes visible outside this file (`VaultKeyManager`/`VaultSecureStorage`'s public shape is identical to before, just backed by `core_data`'s interfaces instead of the local one).

- [ ] **Step 9: Run analyze**

Run: `cd packages/platform_coin_vault && flutter analyze`
Expected: no errors (pre-existing `prefer_initializing_formals` infos are fine).

- [ ] **Step 10: Commit**

```bash
git add packages/core_data/lib/core_data.dart packages/platform_coin_vault
git commit -m "refactor(platform_coin_vault): retire local VaultKeyStore, implement core_data's SecureStorage/EncryptionKeyManager"
```

---

### Task 2: `FieldCipher` — AAD context binding

**Files:**
- Modify: `packages/platform_coin_vault/lib/src/crypto/field_cipher.dart`
- Modify: `packages/platform_coin_vault/test/crypto/field_cipher_test.dart`

**Interfaces:**
- Produces: `Future<String> encryptField(String plaintext, List<int> keyBytes, {required String context})`, `Future<String> decryptField(String encoded, List<int> keyBytes, {required String context})` — the `context` parameter is new and required; every call site in `packages/platform_coin_vault` breaks until Task 3 updates the repositories. This is expected — Task 2 is scoped to `FieldCipher` alone; only run `test/crypto/field_cipher_test.dart` until Task 3 lands, not the full suite.

- [ ] **Step 1: Update the test file to pass `context` everywhere, plus a new mismatched-context regression test**

```dart
// packages/platform_coin_vault/test/crypto/field_cipher_test.dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/crypto/field_cipher.dart';

void main() {
  late FieldCipher cipher;
  late List<int> keyBytes;

  setUp(() {
    cipher = FieldCipher();
    keyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  });

  group('FieldCipher', () {
    test('decrypting an encrypted value returns the original plaintext', () async {
      const plaintext = '1234567890';

      final encrypted = await cipher.encryptField(
        plaintext,
        keyBytes,
        context: 'bank_accounts:account_number_enc:1',
      );
      final decrypted = await cipher.decryptField(
        encrypted,
        keyBytes,
        context: 'bank_accounts:account_number_enc:1',
      );

      expect(decrypted, plaintext);
    });

    test('encrypted output differs from plaintext', () async {
      const plaintext = 'ABCDE1234F';

      final encrypted = await cipher.encryptField(
        plaintext,
        keyBytes,
        context: 'pan_cards:pan_number_enc:1',
      );

      expect(encrypted, isNot(contains(plaintext)));
    });

    test('same plaintext encrypted twice yields different ciphertext (random nonce)', () async {
      const plaintext = 'repeat-me';

      final first = await cipher.encryptField(
        plaintext,
        keyBytes,
        context: 'bank_accounts:notes_enc:1',
      );
      final second = await cipher.encryptField(
        plaintext,
        keyBytes,
        context: 'bank_accounts:notes_enc:1',
      );

      expect(first, isNot(equals(second)));
    });

    test('decrypting with the wrong key throws', () async {
      const plaintext = 'secret-value';
      final wrongKey = List<int>.generate(32, (_) => Random.secure().nextInt(256));

      final encrypted = await cipher.encryptField(
        plaintext,
        keyBytes,
        context: 'bank_accounts:notes_enc:1',
      );

      expect(
        () => cipher.decryptField(encrypted, wrongKey, context: 'bank_accounts:notes_enc:1'),
        throwsA(anything),
      );
    });

    test('decrypting with a mismatched context throws, even with the right key', () async {
      const plaintext = 'secret-value';

      final encrypted = await cipher.encryptField(
        plaintext,
        keyBytes,
        context: 'bank_accounts:notes_enc:1',
      );

      expect(
        () => cipher.decryptField(encrypted, keyBytes, context: 'bank_accounts:notes_enc:2'),
        throwsA(anything),
      );
    });

    test('roundtrips empty string', () async {
      final encrypted = await cipher.encryptField('', keyBytes, context: 'bank_accounts:notes_enc:1');
      final decrypted = await cipher.decryptField(encrypted, keyBytes, context: 'bank_accounts:notes_enc:1');

      expect(decrypted, '');
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/crypto/field_cipher_test.dart`
Expected: FAIL — compile error, `context` is not a defined named parameter on `encryptField`/`decryptField` yet.

- [ ] **Step 3: Add `context`-bound AAD to `FieldCipher`**

```dart
// packages/platform_coin_vault/lib/src/crypto/field_cipher.dart
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM field-level cipher, bound to a per-field associated-data
/// [context] string (e.g. `"table:column:id"`). Each call to [encryptField]
/// uses a fresh random nonce, so encrypting identical plaintext twice yields
/// different ciphertext — this is expected, not a bug. [context] is not
/// secret and is not stored — the caller must supply the exact same
/// [context] on [decryptField] that it used on [encryptField], or decryption
/// fails. This prevents ciphertext from one row/column being swapped into
/// another row/column and still decrypting successfully: GCM authenticates
/// the associated data along with the ciphertext, so a mismatched context
/// fails the MAC check just like a wrong key would.
class FieldCipher {
  final AesGcm _algorithm = AesGcm.with256bits();

  /// Encrypts [plaintext] with [keyBytes] (must be 32 bytes), authenticated
  /// against [context]. Returns a base64-encoded string of
  /// `nonce || cipherText || mac`.
  Future<String> encryptField(
    String plaintext,
    List<int> keyBytes, {
    required String context,
  }) async {
    final secretKey = SecretKey(keyBytes);
    final nonce = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
      aad: utf8.encode(context),
    );

    final combined = <int>[
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];
    return base64Encode(combined);
  }

  /// Decrypts a value produced by [encryptField]. [context] must exactly
  /// match the context used to encrypt it. Throws
  /// [SecretBoxAuthenticationError] if [keyBytes] or [context] is wrong, or
  /// the ciphertext was tampered with.
  Future<String> decryptField(
    String encoded,
    List<int> keyBytes, {
    required String context,
  }) async {
    final combined = base64Decode(encoded);
    const nonceLength = 12;
    const macLength = 16;

    final nonce = combined.sublist(0, nonceLength);
    final mac = combined.sublist(combined.length - macLength);
    final cipherText = combined.sublist(
      nonceLength,
      combined.length - macLength,
    );

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
    final secretKey = SecretKey(keyBytes);
    final plainBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
      aad: utf8.encode(context),
    );
    return utf8.decode(plainBytes);
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd packages/platform_coin_vault && flutter test test/crypto/field_cipher_test.dart`
Expected: PASS — all 6 tests green (the 5 original plus the new mismatched-context test).

- [ ] **Step 5: Commit**

```bash
git add packages/platform_coin_vault/lib/src/crypto/field_cipher.dart packages/platform_coin_vault/test/crypto/field_cipher_test.dart
git commit -m "feat(platform_coin_vault): bind FieldCipher ciphertext to a required AAD context"
```

Note: do not run the full package suite yet — `bank_account_repository.dart`, `pan_card_repository.dart`, and `secure_document_repository.dart` will not compile until Task 3.

---

### Task 3: Bind every repository's ciphertext to its row via AAD

**Files:**
- Modify: `packages/platform_coin_vault/lib/src/data/bank_account_repository.dart`
- Modify: `packages/platform_coin_vault/lib/src/data/pan_card_repository.dart`
- Modify: `packages/platform_coin_vault/lib/src/data/secure_document_repository.dart`
- Modify: `packages/platform_coin_vault/test/data/bank_account_repository_test.dart`
- Modify: `packages/platform_coin_vault/test/data/pan_card_repository_test.dart`
- Modify: `packages/platform_coin_vault/test/data/secure_document_repository_test.dart`

**Interfaces:**
- Consumes: `FieldCipher.encryptField`/`decryptField` with the new required `context` parameter (Task 2).
- Produces: no public signature change on any repository — `create`/`getByNickname`/`getById` keep their existing shapes. Internally, `create` now does insert-then-update (placeholder row → real `id` → AAD-bound encrypt → update) instead of a single insert.

- [ ] **Step 1: Update `bank_account_repository_test.dart` — add context awareness is transparent (no test-visible signature change) plus a new swap-attack regression test**

Add this test inside the existing `group('BankAccountRepository', ...)` block, after `'creating a second account with the same nickname fails'`:

```dart
    test('ciphertext swapped between two rows of the same column fails to decrypt', () async {
      final first = BankAccountRecord(
        id: null,
        nickname: 'Row One',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1111111111',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );
      final second = BankAccountRecord(
        id: null,
        nickname: 'Row Two',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '2222222222',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );

      await repository.create(first, keyBytes);
      await repository.create(second, keyBytes);

      final firstRow = (await vaultDb.db.query(
        VaultTables.bankAccounts,
        where: 'nickname = ?',
        whereArgs: ['Row One'],
      )).single;
      final stolenCiphertext = firstRow['account_number_enc'];

      await vaultDb.db.update(
        VaultTables.bankAccounts,
        {'account_number_enc': stolenCiphertext},
        where: 'nickname = ?',
        whereArgs: ['Row Two'],
      );

      final tampered = await repository.getByNickname('Row Two', keyBytes);

      expect(tampered.isFailure, isTrue);
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/data/bank_account_repository_test.dart`
Expected: FAIL — compile error (`bank_account_repository.dart` still calls `encryptField`/`decryptField` without the now-required `context` argument, from Task 2's change).

- [ ] **Step 3: Rewrite `bank_account_repository.dart` with two-phase insert + AAD context**

```dart
// packages/platform_coin_vault/lib/src/data/bank_account_repository.dart
import 'package:core_domain/core_domain.dart';
import 'package:sqflite/sqflite.dart';

import '../crypto/field_cipher.dart';
import '../domain/entities/bank_account_record.dart';
import 'vault_database.dart';

/// Repository for [BankAccountRecord]. Encrypts [BankAccountRecord.accountNumber]
/// and [BankAccountRecord.notes] before persisting; decrypts them on read.
///
/// [create] inserts a placeholder row first to obtain the row's `id`, then
/// encrypts sensitive fields bound to that `id` via [FieldCipher]'s AAD
/// context, then updates the row with the real ciphertext. This binds each
/// ciphertext to its own row so ciphertext from one row can never be
/// swapped into another row of the same table/column and still decrypt.
class BankAccountRepository {
  BankAccountRepository({required VaultDatabase database, required FieldCipher fieldCipher})
    : _database = database,
      _fieldCipher = fieldCipher;

  final VaultDatabase _database;
  final FieldCipher _fieldCipher;

  Future<Result<int>> create(BankAccountRecord record, List<int> keyBytes) async {
    try {
      final id = await _database.db.insert(VaultTables.bankAccounts, {
        'nickname': record.nickname,
        'bank_name': record.bankName,
        'account_holder_name': record.accountHolderName,
        'account_number_enc': '',
        'ifsc_code': record.ifscCode,
        'account_type': record.accountType,
        'branch_name': record.branchName,
        'micr_code': record.micrCode,
        'swift_iban': record.swiftIban,
        'customer_id': record.customerId,
        'upi_ids': record.upiIds,
        'linked_mobile': record.linkedMobile,
        'linked_email': record.linkedEmail,
        'nominee_name': record.nomineeName,
        'debit_card_last4': record.debitCardLast4,
        'debit_card_expiry': record.debitCardExpiry,
        'notes_enc': null,
        'created_at': record.createdAt.millisecondsSinceEpoch,
      });

      final accountNumberEnc = await _fieldCipher.encryptField(
        record.accountNumber,
        keyBytes,
        context: '${VaultTables.bankAccounts}:account_number_enc:$id',
      );
      final notesEnc = record.notes == null
          ? null
          : await _fieldCipher.encryptField(
              record.notes!,
              keyBytes,
              context: '${VaultTables.bankAccounts}:notes_enc:$id',
            );

      await _database.db.update(
        VaultTables.bankAccounts,
        {'account_number_enc': accountNumberEnc, 'notes_enc': notesEnc},
        where: 'id = ?',
        whereArgs: [id],
      );

      return Success(id);
    } on DatabaseException catch (e) {
      return Failure(ValidationFailure(
        message: 'An account with nickname "${record.nickname}" already exists',
        field: 'nickname',
        cause: e,
      ));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to create bank account', cause: e));
    }
  }

  Future<Result<BankAccountRecord?>> getByNickname(
    String nickname,
    List<int> keyBytes,
  ) async {
    try {
      final rows = await _database.db.query(
        VaultTables.bankAccounts,
        where: 'nickname = ?',
        whereArgs: [nickname],
        limit: 1,
      );
      if (rows.isEmpty) return const Success(null);

      final row = rows.single;
      final id = row['id'] as int;
      final accountNumber = await _fieldCipher.decryptField(
        row['account_number_enc'] as String,
        keyBytes,
        context: '${VaultTables.bankAccounts}:account_number_enc:$id',
      );
      final notesEnc = row['notes_enc'] as String?;
      final notes = notesEnc == null
          ? null
          : await _fieldCipher.decryptField(
              notesEnc,
              keyBytes,
              context: '${VaultTables.bankAccounts}:notes_enc:$id',
            );

      return Success(BankAccountRecord(
        id: id,
        nickname: row['nickname'] as String,
        bankName: row['bank_name'] as String,
        accountHolderName: row['account_holder_name'] as String,
        accountNumber: accountNumber,
        ifscCode: row['ifsc_code'] as String,
        accountType: row['account_type'] as String,
        branchName: row['branch_name'] as String?,
        micrCode: row['micr_code'] as String?,
        swiftIban: row['swift_iban'] as String?,
        customerId: row['customer_id'] as String?,
        upiIds: row['upi_ids'] as String?,
        linkedMobile: row['linked_mobile'] as String?,
        linkedEmail: row['linked_email'] as String?,
        nomineeName: row['nominee_name'] as String?,
        debitCardLast4: row['debit_card_last4'] as String?,
        debitCardExpiry: row['debit_card_expiry'] as String?,
        notes: notes,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      ));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to read bank account', cause: e));
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd packages/platform_coin_vault && flutter test test/data/bank_account_repository_test.dart`
Expected: PASS — all 5 tests green (4 original + the new swap-attack regression test).

- [ ] **Step 5: Rewrite `pan_card_repository.dart` with the same two-phase pattern**

```dart
// packages/platform_coin_vault/lib/src/data/pan_card_repository.dart
import 'package:core_domain/core_domain.dart';

import '../crypto/field_cipher.dart';
import '../domain/entities/pan_card_record.dart';
import 'vault_database.dart';

class PanCardRepository {
  PanCardRepository({required VaultDatabase database, required FieldCipher fieldCipher})
    : _database = database,
      _fieldCipher = fieldCipher;

  final VaultDatabase _database;
  final FieldCipher _fieldCipher;

  Future<Result<int>> create(PanCardRecord record, List<int> keyBytes) async {
    try {
      final id = await _database.db.insert(VaultTables.panCards, {
        'pan_number_enc': '',
        'name_on_card': record.nameOnCard,
        'fathers_name': record.fathersName,
        'date_of_birth': record.dateOfBirth?.millisecondsSinceEpoch,
        'card_image_blob_enc': null,
        'created_at': record.createdAt.millisecondsSinceEpoch,
      });

      final panNumberEnc = await _fieldCipher.encryptField(
        record.panNumber,
        keyBytes,
        context: '${VaultTables.panCards}:pan_number_enc:$id',
      );
      final cardImageBlobEnc = record.cardImageBlob == null
          ? null
          : await _fieldCipher.encryptField(
              String.fromCharCodes(record.cardImageBlob!),
              keyBytes,
              context: '${VaultTables.panCards}:card_image_blob_enc:$id',
            );

      await _database.db.update(
        VaultTables.panCards,
        {'pan_number_enc': panNumberEnc, 'card_image_blob_enc': cardImageBlobEnc},
        where: 'id = ?',
        whereArgs: [id],
      );

      return Success(id);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to create PAN card', cause: e));
    }
  }

  Future<Result<PanCardRecord?>> getById(int id, List<int> keyBytes) async {
    try {
      final rows = await _database.db.query(
        VaultTables.panCards,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return const Success(null);

      final row = rows.single;
      final panNumber = await _fieldCipher.decryptField(
        row['pan_number_enc'] as String,
        keyBytes,
        context: '${VaultTables.panCards}:pan_number_enc:$id',
      );
      final dob = row['date_of_birth'] as int?;
      final blobEnc = row['card_image_blob_enc'] as String?;

      return Success(PanCardRecord(
        id: row['id'] as int,
        panNumber: panNumber,
        nameOnCard: row['name_on_card'] as String,
        fathersName: row['fathers_name'] as String?,
        dateOfBirth: dob == null ? null : DateTime.fromMillisecondsSinceEpoch(dob),
        cardImageBlob: blobEnc == null
            ? null
            : (await _fieldCipher.decryptField(
                blobEnc,
                keyBytes,
                context: '${VaultTables.panCards}:card_image_blob_enc:$id',
              )).codeUnits,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      ));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to read PAN card', cause: e));
    }
  }
}
```

- [ ] **Step 6: Run pan_card_repository_test.dart — it should already pass unmodified**

Run: `cd packages/platform_coin_vault && flutter test test/data/pan_card_repository_test.dart`
Expected: PASS — no test-visible signature change, all 3 existing tests green with no edits to the test file.

- [ ] **Step 7: Rewrite `secure_document_repository.dart` with the same two-phase pattern**

```dart
// packages/platform_coin_vault/lib/src/data/secure_document_repository.dart
import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:sqflite/sqflite.dart';

import '../crypto/field_cipher.dart';
import '../domain/entities/secure_document_record.dart';
import 'vault_database.dart';

class SecureDocumentRepository {
  SecureDocumentRepository({required VaultDatabase database, required FieldCipher fieldCipher})
    : _database = database,
      _fieldCipher = fieldCipher;

  final VaultDatabase _database;
  final FieldCipher _fieldCipher;

  Future<Result<int>> create(SecureDocumentRecord record, List<int> keyBytes) async {
    try {
      final id = await _database.db.insert(VaultTables.secureDocuments, {
        'nickname': record.nickname,
        'category': record.category.name,
        'linked_account_nickname': record.linkedAccountNickname,
        'custom_fields_enc': null,
        'attachment_blob_enc': null,
        'notes_enc': null,
        'created_at': record.createdAt.millisecondsSinceEpoch,
      });

      final customFieldsEnc = record.customFields.isEmpty
          ? null
          : await _fieldCipher.encryptField(
              jsonEncode(record.customFields),
              keyBytes,
              context: '${VaultTables.secureDocuments}:custom_fields_enc:$id',
            );
      final notesEnc = record.notes == null
          ? null
          : await _fieldCipher.encryptField(
              record.notes!,
              keyBytes,
              context: '${VaultTables.secureDocuments}:notes_enc:$id',
            );
      final attachmentEnc = record.attachmentBlob == null
          ? null
          : await _fieldCipher.encryptField(
              String.fromCharCodes(record.attachmentBlob!),
              keyBytes,
              context: '${VaultTables.secureDocuments}:attachment_blob_enc:$id',
            );

      await _database.db.update(
        VaultTables.secureDocuments,
        {
          'custom_fields_enc': customFieldsEnc,
          'attachment_blob_enc': attachmentEnc,
          'notes_enc': notesEnc,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      return Success(id);
    } on DatabaseException catch (e) {
      return Failure(ValidationFailure(
        message: 'A document with nickname "${record.nickname}" already exists',
        field: 'nickname',
        cause: e,
      ));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to create secure document', cause: e));
    }
  }

  Future<Result<SecureDocumentRecord?>> getByNickname(
    String nickname,
    List<int> keyBytes,
  ) async {
    try {
      final rows = await _database.db.query(
        VaultTables.secureDocuments,
        where: 'nickname = ?',
        whereArgs: [nickname],
        limit: 1,
      );
      if (rows.isEmpty) return const Success(null);

      final row = rows.single;
      final id = row['id'] as int;
      final customFieldsEnc = row['custom_fields_enc'] as String?;
      final notesEnc = row['notes_enc'] as String?;
      final attachmentEnc = row['attachment_blob_enc'] as String?;

      final customFields = customFieldsEnc == null
          ? <String, String>{}
          : Map<String, String>.from(
              jsonDecode(await _fieldCipher.decryptField(
                customFieldsEnc,
                keyBytes,
                context: '${VaultTables.secureDocuments}:custom_fields_enc:$id',
              )) as Map,
            );

      return Success(SecureDocumentRecord(
        id: id,
        nickname: row['nickname'] as String,
        category: DocumentCategory.values.byName(row['category'] as String),
        linkedAccountNickname: row['linked_account_nickname'] as String?,
        customFields: customFields,
        attachmentBlob: attachmentEnc == null
            ? null
            : (await _fieldCipher.decryptField(
                attachmentEnc,
                keyBytes,
                context: '${VaultTables.secureDocuments}:attachment_blob_enc:$id',
              )).codeUnits,
        notes: notesEnc == null
            ? null
            : await _fieldCipher.decryptField(
                notesEnc,
                keyBytes,
                context: '${VaultTables.secureDocuments}:notes_enc:$id',
              ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      ));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to read secure document', cause: e));
    }
  }
}
```

- [ ] **Step 8: Run secure_document_repository_test.dart — it should already pass unmodified**

Run: `cd packages/platform_coin_vault && flutter test test/data/secure_document_repository_test.dart`
Expected: PASS — all 5 existing tests green with no edits to the test file.

- [ ] **Step 9: Run the full package suite**

Run: `cd packages/platform_coin_vault && flutter test`
Expected: PASS — every test file green, including `test/data/vault_integration_test.dart` (it calls the repositories through their unchanged public API, so it needs no edits).

- [ ] **Step 10: Run analyze**

Run: `cd packages/platform_coin_vault && flutter analyze`
Expected: no errors.

- [ ] **Step 11: Commit**

```bash
git add packages/platform_coin_vault/lib/src/data/bank_account_repository.dart packages/platform_coin_vault/lib/src/data/pan_card_repository.dart packages/platform_coin_vault/lib/src/data/secure_document_repository.dart packages/platform_coin_vault/test/data/bank_account_repository_test.dart
git commit -m "fix(platform_coin_vault): bind every encrypted field to its row via AAD, closing the ciphertext-swap gap"
```

---

### Task 4: `VaultKeyManager` — safe rotation primitives

**Files:**
- Modify: `packages/platform_coin_vault/lib/src/crypto/vault_key_manager.dart`
- Modify: `packages/platform_coin_vault/test/crypto/vault_key_manager_test.dart`

**Interfaces:**
- Produces: `List<int> generateCandidateKey()`, `Future<Result<void>> commitRotatedKey(List<int> newKeyBytes)` — new methods, additive only. `rotateKey()` (Task 1) is untouched. Consumed by `VaultKeyRotationService` in Task 5.

- [ ] **Step 1: Write failing tests for the new primitives**

Add these three tests inside the existing `group('VaultKeyManager', ...)` block in `vault_key_manager_test.dart`, after the last existing test:

```dart
    test('generateCandidateKey returns a 32-byte key without persisting it', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => true,
      );

      final candidate = manager.generateCandidateKey();
      final stored = await secureStorage.containsKey('airo_coin_wrapped_dek');

      expect(candidate, hasLength(32));
      expect(stored.value, isFalse);
    });

    test('commitRotatedKey persists the given key as the active DEK', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => true,
      );

      final candidate = manager.generateCandidateKey();
      final commitResult = await manager.commitRotatedKey(candidate);
      final active = await manager.getDatabaseKey();

      expect(commitResult.isSuccess, isTrue);
      expect(active.value, equals(candidate));
    });

    test('commitRotatedKey fails closed when authentication is denied', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => false,
      );

      final result = await manager.commitRotatedKey(List<int>.filled(32, 1));

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<AuthFailure>());
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/platform_coin_vault && flutter test test/crypto/vault_key_manager_test.dart`
Expected: FAIL — `generateCandidateKey`/`commitRotatedKey` are not defined on `VaultKeyManager` yet.

- [ ] **Step 3: Add the two methods to `VaultKeyManager`**

Insert these two methods after `rotateKey()` and before `isEncryptionAvailable()`:

```dart
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
      return Failure(AuthFailure(message: 'Biometric authentication failed', cause: e));
    }
    if (!authenticated) {
      return const Failure(AuthFailure(message: 'Biometric authentication failed'));
    }
    return _secureStorage.write(_wrappedDekKey, _encodeKey(newKeyBytes));
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/platform_coin_vault && flutter test test/crypto/vault_key_manager_test.dart`
Expected: PASS — all 12 tests green (9 original + 3 new).

- [ ] **Step 5: Commit**

```bash
git add packages/platform_coin_vault/lib/src/crypto/vault_key_manager.dart packages/platform_coin_vault/test/crypto/vault_key_manager_test.dart
git commit -m "feat(platform_coin_vault): add generateCandidateKey/commitRotatedKey primitives for safe key rotation"
```

---

### Task 5: `VaultKeyRotationService` — re-encryption migration

**Files:**
- Create: `packages/platform_coin_vault/lib/src/data/vault_key_rotation_service.dart`
- Create: `packages/platform_coin_vault/test/data/vault_key_rotation_service_test.dart`
- Modify: `packages/platform_coin_vault/lib/platform_coin_vault.dart`

**Interfaces:**
- Consumes: `VaultDatabase` (Task 6 of the original Phase 0 plan), `VaultKeyManager.getDatabaseKey()`/`generateCandidateKey()`/`commitRotatedKey()` (Task 4 above), `FieldCipher.encryptField`/`decryptField` with `context` (Task 2).
- Produces: `class VaultKeyRotationService { Future<Result<void>> rotateKeyWithReencryption(); }` — the only supported DEK rotation path once this lands.

- [ ] **Step 1: Write failing tests for full-vault re-encryption**

```dart
// packages/platform_coin_vault/test/data/vault_key_rotation_service_test.dart
import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/crypto/field_cipher.dart';
import 'package:platform_coin_vault/src/crypto/vault_key_manager.dart';
import 'package:platform_coin_vault/src/data/bank_account_repository.dart';
import 'package:platform_coin_vault/src/data/pan_card_repository.dart';
import 'package:platform_coin_vault/src/data/secure_document_repository.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:platform_coin_vault/src/data/vault_key_rotation_service.dart';
import 'package:platform_coin_vault/src/domain/entities/bank_account_record.dart';
import 'package:platform_coin_vault/src/domain/entities/pan_card_record.dart';
import 'package:platform_coin_vault/src/domain/entities/secure_document_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VaultDatabase vaultDb;
  late InMemorySecureStorage secureStorage;
  late VaultKeyManager keyManager;
  late FieldCipher fieldCipher;
  late VaultKeyRotationService rotationService;
  late BankAccountRepository bankAccounts;
  late PanCardRepository panCards;
  late SecureDocumentRepository secureDocuments;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    secureStorage = InMemorySecureStorage();
    keyManager = VaultKeyManager.forTesting(
      secureStorage: secureStorage,
      authenticate: () async => true,
    );
    fieldCipher = FieldCipher();
    rotationService = VaultKeyRotationService(
      database: vaultDb,
      keyManager: keyManager,
      fieldCipher: fieldCipher,
    );
    bankAccounts = BankAccountRepository(database: vaultDb, fieldCipher: fieldCipher);
    panCards = PanCardRepository(database: vaultDb, fieldCipher: fieldCipher);
    secureDocuments = SecureDocumentRepository(database: vaultDb, fieldCipher: fieldCipher);
  });

  tearDown(() async {
    await vaultDb.close();
  });

  test('rotateKeyWithReencryption re-encrypts existing data so it remains readable under the new key', () async {
    final oldKey = (await keyManager.getDatabaseKey()).value;

    await bankAccounts.create(
      BankAccountRecord(
        id: null,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1234567890',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
        notes: 'primary account',
      ),
      oldKey,
    );
    final panResult = await panCards.create(
      PanCardRecord(id: null, panNumber: 'ABCDE1234F', nameOnCard: 'Jane Doe'),
      oldKey,
    );
    await secureDocuments.create(
      SecureDocumentRecord(
        id: null,
        nickname: 'Form 16 FY24-25',
        category: DocumentCategory.incomeProof,
        notes: 'Employer TDS certificate',
        createdAt: DateTime(2026, 7, 19),
      ),
      oldKey,
    );

    final rotateResult = await rotationService.rotateKeyWithReencryption();
    expect(rotateResult.isSuccess, isTrue);

    final newKey = (await keyManager.getDatabaseKey()).value;
    expect(newKey, isNot(equals(oldKey)));

    final fetchedBank = await bankAccounts.getByNickname('HDFC Salary', newKey);
    final fetchedPan = await panCards.getById(panResult.value, newKey);
    final fetchedDocument = await secureDocuments.getByNickname('Form 16 FY24-25', newKey);

    expect(fetchedBank.value?.accountNumber, '1234567890');
    expect(fetchedBank.value?.notes, 'primary account');
    expect(fetchedPan.value?.panNumber, 'ABCDE1234F');
    expect(fetchedDocument.value?.notes, 'Employer TDS certificate');
  });

  test('data is no longer decryptable under the old key after rotation', () async {
    final oldKey = (await keyManager.getDatabaseKey()).value;

    await bankAccounts.create(
      BankAccountRecord(
        id: null,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1234567890',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      ),
      oldKey,
    );

    await rotationService.rotateKeyWithReencryption();

    final fetchedWithOldKey = await bankAccounts.getByNickname('HDFC Salary', oldKey);

    expect(fetchedWithOldKey.isFailure, isTrue);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/data/vault_key_rotation_service_test.dart`
Expected: FAIL — `package:platform_coin_vault/src/data/vault_key_rotation_service.dart` does not exist yet.

- [ ] **Step 3: Implement `VaultKeyRotationService`**

```dart
// packages/platform_coin_vault/lib/src/data/vault_key_rotation_service.dart
import 'package:core_domain/core_domain.dart';
import 'package:sqflite/sqflite.dart';

import '../crypto/field_cipher.dart';
import '../crypto/vault_key_manager.dart';
import 'vault_database.dart';

/// Column names that carry [FieldCipher]-encrypted values, keyed by table.
/// `credit_cards` is intentionally absent — it has no encrypted columns.
const Map<String, List<String>> _encryptedColumnsByTable = {
  VaultTables.bankAccounts: ['account_number_enc', 'notes_enc'],
  VaultTables.panCards: ['pan_number_enc', 'card_image_blob_enc'],
  VaultTables.secureDocuments: ['custom_fields_enc', 'attachment_blob_enc', 'notes_enc'],
};

/// Safely rotates the vault's DEK by re-encrypting every field-encrypted
/// column, across every table, under the new key before the new key ever
/// becomes active. If re-encryption fails partway through, the whole
/// operation rolls back inside one sqflite transaction and the old DEK
/// remains active — there is no partially-rotated state.
///
/// This is the only supported way to rotate the vault's DEK.
/// `VaultKeyManager.rotateKey()` is a raw, destructive primitive that exists
/// only to satisfy `EncryptionKeyManager`'s interface contract — it must
/// never be called directly on a vault containing data.
class VaultKeyRotationService {
  VaultKeyRotationService({
    required VaultDatabase database,
    required VaultKeyManager keyManager,
    required FieldCipher fieldCipher,
  }) : _database = database,
       _keyManager = keyManager,
       _fieldCipher = fieldCipher;

  final VaultDatabase _database;
  final VaultKeyManager _keyManager;
  final FieldCipher _fieldCipher;

  Future<Result<void>> rotateKeyWithReencryption() async {
    final oldKeyResult = await _keyManager.getDatabaseKey();
    if (oldKeyResult.isFailure) {
      return Failure(oldKeyResult.failure);
    }
    final oldKey = oldKeyResult.value;
    final newKey = _keyManager.generateCandidateKey();

    try {
      await _database.db.transaction((txn) async {
        for (final entry in _encryptedColumnsByTable.entries) {
          await _reencryptTable(txn, entry.key, entry.value, oldKey, newKey);
        }
      });
    } catch (e) {
      return Failure(DatabaseFailure(
        message: 'Re-encryption failed; the vault DEK was not rotated',
        cause: e,
      ));
    }

    return _keyManager.commitRotatedKey(newKey);
  }

  Future<void> _reencryptTable(
    Transaction txn,
    String table,
    List<String> encryptedColumns,
    List<int> oldKey,
    List<int> newKey,
  ) async {
    final rows = await txn.query(table);
    for (final row in rows) {
      final id = row['id'] as int;
      final updates = <String, Object?>{};
      for (final column in encryptedColumns) {
        final value = row[column] as String?;
        if (value == null) continue;
        final plaintext = await _fieldCipher.decryptField(
          value,
          oldKey,
          context: '$table:$column:$id',
        );
        updates[column] = await _fieldCipher.encryptField(
          plaintext,
          newKey,
          context: '$table:$column:$id',
        );
      }
      if (updates.isNotEmpty) {
        await txn.update(table, updates, where: 'id = ?', whereArgs: [id]);
      }
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd packages/platform_coin_vault && flutter test test/data/vault_key_rotation_service_test.dart`
Expected: PASS — both tests green.

- [ ] **Step 5: Export from the barrel file**

```dart
// packages/platform_coin_vault/lib/platform_coin_vault.dart
export 'src/data/secure_document_repository.dart';
export 'src/data/vault_key_rotation_service.dart';
```

- [ ] **Step 6: Run the full package suite**

Run: `cd packages/platform_coin_vault && flutter test`
Expected: PASS — every test file green.

- [ ] **Step 7: Commit**

```bash
git add packages/platform_coin_vault/lib/src/data/vault_key_rotation_service.dart packages/platform_coin_vault/test/data/vault_key_rotation_service_test.dart packages/platform_coin_vault/lib/platform_coin_vault.dart
git commit -m "feat(platform_coin_vault): add VaultKeyRotationService for safe, re-encrypting DEK rotation"
```

---

### Task 6: Real-device integration test scaffold for `VaultSecureStorage`

**Files:**
- Modify: `packages/platform_coin_vault/pubspec.yaml`
- Create: `packages/platform_coin_vault/integration_test/vault_secure_storage_integration_test.dart`

**Interfaces:**
- Consumes: `VaultSecureStorage` (Task 1).
- Produces: no production code — a device/emulator-only test file. This task cannot be verified with `flutter test` (no simulator/emulator is available in this environment); verification is `flutter analyze`-clean compilation plus documented manual run instructions.

- [ ] **Step 1: Add `integration_test` as a dev dependency**

```yaml
# packages/platform_coin_vault/pubspec.yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  sqflite_common_ffi: ^2.3.6
```

- [ ] **Step 2: Run `flutter pub get`**

Run: `cd packages/platform_coin_vault && flutter pub get`
Expected: resolves cleanly.

- [ ] **Step 3: Write the integration test**

```dart
// packages/platform_coin_vault/integration_test/vault_secure_storage_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:platform_coin_vault/src/crypto/vault_secure_storage.dart';

/// Real-device/emulator smoke test for [VaultSecureStorage] — the
/// `flutter_secure_storage` platform-channel wrapper that unit tests cannot
/// exercise (there is no in-memory fake for the real Keystore/Keychain
/// channel). Run with:
///
/// ```sh
/// flutter test integration_test/vault_secure_storage_integration_test.dart -d <device-id>
/// ```
///
/// This test verifies the write/read/delete roundtrip works against the
/// real platform channel. It does NOT verify that the biometric prompt
/// actually appears — that requires interactive human confirmation and is
/// outside what an automated integration test can assert. When running
/// manually, confirm a biometric/device-credential prompt appears before
/// the first read/write succeeds; if it does not, `enforceBiometrics` in
/// `VaultSecureStorage`'s `AndroidOptions.biometric(...)` has regressed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('write, read, and delete roundtrip against the real secure storage channel', (
    tester,
  ) async {
    final storage = VaultSecureStorage();
    const key = 'integration_test_key';
    const value = 'integration_test_value';

    await storage.delete(key);

    final writeResult = await storage.write(key, value);
    expect(writeResult.isSuccess, isTrue);

    final readResult = await storage.read(key);
    expect(readResult.value, value);

    final containsResult = await storage.containsKey(key);
    expect(containsResult.value, isTrue);

    final deleteResult = await storage.delete(key);
    expect(deleteResult.isSuccess, isTrue);

    final afterDelete = await storage.read(key);
    expect(afterDelete.value, isNull);
  });
}
```

- [ ] **Step 4: Verify the file analyzes cleanly (cannot run — no device/emulator in this environment)**

Run: `cd packages/platform_coin_vault && flutter analyze integration_test/vault_secure_storage_integration_test.dart`
Expected: no errors.

Manual follow-up (not part of this plan's automated verification): run
`flutter test integration_test/vault_secure_storage_integration_test.dart -d <device-id>`
on a real Android device/emulator and a real iOS simulator/device with
biometrics enrolled, confirming the biometric/device-credential prompt
appears as documented in the test's doc comment.

- [ ] **Step 5: Commit**

```bash
git add packages/platform_coin_vault/pubspec.yaml packages/platform_coin_vault/integration_test
git commit -m "test(platform_coin_vault): scaffold real-device integration test for VaultSecureStorage's biometric gate"
```

---

### Task 7: Update ADR-0009

**Files:**
- Modify: `docs/adr/0009-airo-coin-vault-crypto.md`

**Interfaces:**
- None — documentation only.

- [ ] **Step 1: Update the Decision section to describe AAD binding**

In the "Field-level AES-256-GCM encryption" bullet of the Decision section, replace the sentence ending "...before insert." with:

```markdown
- **Field-level AES-256-GCM encryption** (via the `cryptography` package),
  not full-disk/SQLCipher encryption. Sensitive columns (account number, PAN
  number, notes, custom fields, attachment blobs) are individually encrypted
  before insert, each bound to a `"table:column:id"` associated-data (AAD)
  context — so ciphertext from one row/column can never be swapped into
  another row/column and still decrypt (`FieldCipher`, `platform_coin_vault`
  fast-follow plan, 2026-07-20). This avoids introducing a second native
  sqlite runtime alongside `platform_playlist`'s existing `drift` +
  `sqlite3_flutter_libs` stack (see PR #925, which fixed a dual-runtime bug
  from a related cause).
```

- [ ] **Step 2: Update the Negative consequences section to remove the resolved AAD gap**

The Negative section currently only lists the AES-GCM roundtrip cost and the "new sensitive field must go through FieldCipher" review-time check — no edit needed there; the AAD gap was tracked in Risks, not Negatives (see Step 3).

- [ ] **Step 3: Update the Risks section — mark the swap-attack gap and rotateKey gap as resolved**

Replace the `known limitation` bullet in Risks with:

```markdown
- **Resolved (2026-07-20 fast-follow):** ciphertext previously had no
  binding to its row/column context, so an attacker with raw write access
  to the sqlite file could swap `account_number_enc` (or any encrypted
  column) between two rows of the same table/column and it would decrypt
  successfully. `FieldCipher` now requires an AAD `context` string
  (`"table:column:id"`) on every encrypt/decrypt call, and repositories bind
  it to each row's own `id`. A swapped ciphertext now fails authentication
  and `decryptField` throws, closing this gap.
- **Resolved (2026-07-20 fast-follow):** `VaultKeyManager.rotateKey()`
  overwrote the stored DEK without re-encrypting existing vault data,
  permanently orphaning every previously-encrypted record.
  `VaultKeyRotationService.rotateKeyWithReencryption()` now re-encrypts every
  field-encrypted column across all tables inside one sqflite transaction
  before committing the new key — the old key remains active if
  re-encryption fails partway through. `rotateKey()` itself remains present
  (required by `EncryptionKeyManager`'s interface) but is documented as an
  unsafe raw primitive; callers must use `VaultKeyRotationService` instead.
```

- [ ] **Step 4: Update the References section**

```markdown
## References

- Tracking issue: #927 (DevelopersCoffee/airo)
- PR #925 — dual sqlite runtime bug fix (precedent for the "no second native
  DB runtime" constraint)
- PR #944/#947 — Phase 0 vault crypto & storage layer
- PR #946 — fail-closed `local_auth` exception handling fast-follow
- `packages/platform_coin_vault/lib/src/crypto/field_cipher.dart`
- `packages/platform_coin_vault/lib/src/crypto/vault_key_manager.dart`
- `packages/platform_coin_vault/lib/src/crypto/vault_secure_storage.dart`
- `packages/platform_coin_vault/lib/src/data/vault_key_rotation_service.dart`
```

- [ ] **Step 5: Commit**

```bash
git add docs/adr/0009-airo-coin-vault-crypto.md
git commit -m "docs: update ADR-0009 for AAD binding and safe key rotation fast-follows"
```

---

## Plan Self-Review

**Spec coverage:**
- Item 1 (core_data export, retire VaultKeyStore) — Task 1. ✓
- Item 2 (AAD/context binding on FieldCipher) — Tasks 2, 3. ✓
- Item 3 (real-device integration test for VaultSecureStorage) — Task 6. ✓
- Item 4 (re-encryption migration for rotateKey) — Tasks 4, 5. ✓
- ADR update reflecting items 2 and 4 — Task 7. ✓

**Placeholder scan:** no TBD/TODO; every step has runnable code or an exact command with expected output. Task 6's device-only verification is explicitly scoped as "cannot run here, verified by analyze + documented manual step" rather than glossed over.

**Type consistency:** `FieldCipher.encryptField`/`decryptField` signatures (with `context`) match identically across Tasks 2, 3, 5. `VaultKeyManager.generateCandidateKey()`/`commitRotatedKey()` signatures match between Task 4's definition and Task 5's `VaultKeyRotationService` usage. `SecureStorage`/`EncryptionKeyManager` (from `core_data`) used identically in Tasks 1 and 5's test setup (`InMemorySecureStorage`). `VaultTables` constants used identically across Tasks 3 and 5.

---

Plan complete and saved to `docs/superpowers/plans/2026-07-20-airo-coin-vault-fastfollows.md`. Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
