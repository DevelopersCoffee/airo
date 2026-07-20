# platform_coin_vault Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `platform_coin_vault`, a new package providing biometric-gated,
field-level-encrypted local storage for four record types (bank account, PAN
card, credit card, generic secure document) — crypto and storage only, no UI.

**Architecture:** Reuse `core_data`'s existing `SecureStorage` /
`EncryptionKeyManager` / `EncryptedDatabase` interfaces
(`packages/core_data/lib/src/secure/secure_storage.dart`). Implement them with
`flutter_secure_storage` (Keystore/Keychain-backed KEK storage, same pattern
`core_data`'s `FlutterSecureStore` already uses), `local_auth` (biometric
gate), the `cryptography` package (AES-256-GCM field encryption), and
`sqflite` (already a `core_data` dependency — no new native DB runtime).

**Tech Stack:** Flutter/Dart, `sqflite`, `flutter_secure_storage`,
`local_auth`, `cryptography` (AES-256-GCM), `equatable`, `core_domain`'s
`Result<T>`/`Failure` for error handling.

## Global Constraints

- No SQLCipher, no `sqlite3_flutter_libs`, no second native sqlite runtime —
  use `sqflite` only (per spec's non-goal, avoiding the #925 dual-runtime bug class).
- No full credit card number, no CVV, no PIN anywhere — `CreditCardRecord` is
  masked-only (network, last4, expiry, issuing bank).
- Nothing sensitive stored in plaintext: `accountNumber`, `panNumber`, `notes`,
  attachment blobs, and custom fields are always AES-256-GCM encrypted before
  hitting the DB.
- `BankAccountRecord.nickname` is unique within the vault (enforced at DB +
  repository layer) — it is the canonical reference other records point to via
  `linkedAccountNickname`.
- Every task in this plan produces zero UI. `feature_coin` (lock screen,
  forms, masking widgets) is a separate future plan.
- SDK floor matches `core_data`: `sdk: ">=3.12.2 <4.0.0"`, `flutter: ">=3.44.4"`.
- Module governance: `platform_coin_vault`'s `module.yaml` reviewers are Chief
  Architect, Chief Security Officer, Chief QA Officer; `allowed_dependencies`
  is `core_domain` and `core_data` only; `forbidden_dependencies` is `app`.

---

## File Structure

```
packages/platform_coin_vault/
  pubspec.yaml
  module.yaml
  analysis_options.yaml
  lib/
    platform_coin_vault.dart                       # barrel export
    src/
      domain/
        validators/
          ifsc_validator.dart
          pan_validator.dart
        entities/
          bank_account_record.dart
          pan_card_record.dart
          credit_card_record.dart
          secure_document_record.dart
      crypto/
        field_cipher.dart                          # AES-256-GCM encrypt/decrypt
        vault_key_manager.dart                      # EncryptionKeyManager impl
        vault_secure_storage.dart                   # SecureStorage impl
      data/
        vault_database.dart                         # EncryptedDatabase impl (sqflite)
        bank_account_repository.dart
        pan_card_repository.dart
        credit_card_repository.dart
        secure_document_repository.dart
  test/
    domain/validators/ifsc_validator_test.dart
    domain/validators/pan_validator_test.dart
    crypto/field_cipher_test.dart
    crypto/vault_key_manager_test.dart
    data/bank_account_repository_test.dart
    data/pan_card_repository_test.dart
    data/credit_card_repository_test.dart
    data/secure_document_repository_test.dart
```

---

### Task 1: Package scaffold

**Files:**
- Create: `packages/platform_coin_vault/pubspec.yaml`
- Create: `packages/platform_coin_vault/module.yaml`
- Create: `packages/platform_coin_vault/analysis_options.yaml`
- Create: `packages/platform_coin_vault/lib/platform_coin_vault.dart`
- Test: `packages/platform_coin_vault/test/platform_coin_vault_test.dart`

**Interfaces:**
- Produces: package `platform_coin_vault` resolvable via `path: ../platform_coin_vault` from other packages; barrel file `platform_coin_vault.dart` (empty export list for now, populated as later tasks land).

- [ ] **Step 1: Create `pubspec.yaml`**

```yaml
name: platform_coin_vault
description: "Biometric-gated, field-encrypted local vault storage for Airo Coin (bank accounts, PAN, credit card refs, secure documents)."
version: 0.0.1
publish_to: none

environment:
  sdk: ">=3.12.2 <4.0.0"
  flutter: ">=3.44.4"

dependencies:
  flutter:
    sdk: flutter
  core_data:
    path: ../core_data
  core_domain:
    path: ../core_domain
  cryptography: ^2.7.0
  local_auth: ^2.3.0
  sqflite: ^2.4.3
  equatable: ^2.0.8
  meta: ^1.18.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  sqflite_common_ffi: ^2.3.6
```

- [ ] **Step 2: Create `module.yaml`**

```yaml
name: platform_coin_vault
owner: Coins / Finance Agent
reviewers:
  - Chief Architect
  - Chief Security Officer
  - Chief QA Officer
allowed_dependencies:
  - core_domain
  - core_data
forbidden_dependencies:
  - app
quality_gates: {}
```

- [ ] **Step 3: Create `analysis_options.yaml`**

```yaml
include: package:flutter_lints/flutter.yaml
```

- [ ] **Step 4: Create barrel file**

```dart
// packages/platform_coin_vault/lib/platform_coin_vault.dart
// Barrel export for platform_coin_vault. Populated as domain/crypto/data
// layers land in later tasks.
```

- [ ] **Step 5: Write a smoke test**

```dart
// packages/platform_coin_vault/test/platform_coin_vault_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

void main() {
  test('package resolves', () {
    expect(true, isTrue);
  });
}
```

- [ ] **Step 6: Run `flutter pub get` and the smoke test**

Run:
```bash
cd packages/platform_coin_vault && flutter pub get && flutter test test/platform_coin_vault_test.dart
```
Expected: `flutter pub get` resolves cleanly, test passes (`00:0X +1: All tests passed!`).

- [ ] **Step 7: Commit**

```bash
git add packages/platform_coin_vault
git commit -m "feat(platform_coin_vault): scaffold new package per module.yaml governance"
```

---

### Task 2: Validators — IFSC and PAN

**Files:**
- Create: `packages/platform_coin_vault/lib/src/domain/validators/ifsc_validator.dart`
- Create: `packages/platform_coin_vault/lib/src/domain/validators/pan_validator.dart`
- Test: `packages/platform_coin_vault/test/domain/validators/ifsc_validator_test.dart`
- Test: `packages/platform_coin_vault/test/domain/validators/pan_validator_test.dart`
- Modify: `packages/platform_coin_vault/lib/platform_coin_vault.dart`

**Interfaces:**
- Produces: `bool isValidIfsc(String value)`, `bool isValidPan(String value)` —
  used by `BankAccountRecord`/`PanCardRecord` constructors in Task 3.

- [ ] **Step 1: Write failing tests for IFSC validator**

```dart
// packages/platform_coin_vault/test/domain/validators/ifsc_validator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/domain/validators/ifsc_validator.dart';

void main() {
  group('isValidIfsc', () {
    test('accepts a well-formed IFSC code', () {
      expect(isValidIfsc('HDFC0001234'), isTrue);
    });

    test('rejects wrong length', () {
      expect(isValidIfsc('HDFC001234'), isFalse);
    });

    test('rejects missing zero at position 5', () {
      expect(isValidIfsc('HDFC1001234'), isFalse);
    });

    test('rejects lowercase', () {
      expect(isValidIfsc('hdfc0001234'), isFalse);
    });

    test('rejects empty string', () {
      expect(isValidIfsc(''), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/domain/validators/ifsc_validator_test.dart`
Expected: FAIL — `Error: Not found: 'package:platform_coin_vault/src/domain/validators/ifsc_validator.dart'`

- [ ] **Step 3: Implement IFSC validator**

```dart
// packages/platform_coin_vault/lib/src/domain/validators/ifsc_validator.dart
final RegExp _ifscPattern = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

/// Validates an Indian bank IFSC code: 4 letters, a literal '0', then 6
/// alphanumeric characters (e.g. `HDFC0001234`).
bool isValidIfsc(String value) => _ifscPattern.hasMatch(value);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/platform_coin_vault && flutter test test/domain/validators/ifsc_validator_test.dart`
Expected: PASS — all 5 tests green.

- [ ] **Step 5: Write failing tests for PAN validator**

```dart
// packages/platform_coin_vault/test/domain/validators/pan_validator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/domain/validators/pan_validator.dart';

void main() {
  group('isValidPan', () {
    test('accepts a well-formed PAN', () {
      expect(isValidPan('ABCDE1234F'), isTrue);
    });

    test('rejects wrong length', () {
      expect(isValidPan('ABCDE1234'), isFalse);
    });

    test('rejects digits in the letter positions', () {
      expect(isValidPan('12CDE1234F'), isFalse);
    });

    test('rejects lowercase', () {
      expect(isValidPan('abcde1234f'), isFalse);
    });

    test('rejects empty string', () {
      expect(isValidPan(''), isFalse);
    });
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/domain/validators/pan_validator_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 7: Implement PAN validator**

```dart
// packages/platform_coin_vault/lib/src/domain/validators/pan_validator.dart
final RegExp _panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');

/// Validates an Indian PAN number: 5 letters, 4 digits, 1 letter
/// (e.g. `ABCDE1234F`).
bool isValidPan(String value) => _panPattern.hasMatch(value);
```

- [ ] **Step 8: Run test to verify it passes**

Run: `cd packages/platform_coin_vault && flutter test test/domain/validators/pan_validator_test.dart`
Expected: PASS — all 5 tests green.

- [ ] **Step 9: Export from barrel file**

```dart
// packages/platform_coin_vault/lib/platform_coin_vault.dart
export 'src/domain/validators/ifsc_validator.dart';
export 'src/domain/validators/pan_validator.dart';
```

- [ ] **Step 10: Commit**

```bash
git add packages/platform_coin_vault
git commit -m "feat(platform_coin_vault): add IFSC and PAN validators"
```

---

### Task 3: Domain entities

**Files:**
- Create: `packages/platform_coin_vault/lib/src/domain/entities/bank_account_record.dart`
- Create: `packages/platform_coin_vault/lib/src/domain/entities/pan_card_record.dart`
- Create: `packages/platform_coin_vault/lib/src/domain/entities/credit_card_record.dart`
- Create: `packages/platform_coin_vault/lib/src/domain/entities/secure_document_record.dart`
- Test: `packages/platform_coin_vault/test/domain/entities/bank_account_record_test.dart`
- Test: `packages/platform_coin_vault/test/domain/entities/secure_document_record_test.dart`
- Modify: `packages/platform_coin_vault/lib/platform_coin_vault.dart`

**Interfaces:**
- Consumes: `isValidIfsc(String)`, `isValidPan(String)` from Task 2.
- Produces: `BankAccountRecord`, `PanCardRecord`, `CreditCardRecord`,
  `SecureDocumentRecord` classes (all `Equatable`), `DocumentCategory` enum —
  consumed by repositories in Tasks 6–9.

- [ ] **Step 1: Write failing test for `BankAccountRecord` validation**

```dart
// packages/platform_coin_vault/test/domain/entities/bank_account_record_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/domain/entities/bank_account_record.dart';

void main() {
  group('BankAccountRecord', () {
    test('constructs with a valid IFSC code', () {
      final record = BankAccountRecord(
        id: null,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1234567890',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );

      expect(record.ifscCode, 'HDFC0001234');
    });

    test('throws ArgumentError for an invalid IFSC code', () {
      expect(
        () => BankAccountRecord(
          id: null,
          nickname: 'Bad IFSC',
          bankName: 'HDFC Bank',
          accountHolderName: 'Jane Doe',
          accountNumber: '1234567890',
          ifscCode: 'not-an-ifsc',
          accountType: 'savings',
        ),
        throwsArgumentError,
      );
    });

    test('two records with identical fields are equal', () {
      const a = BankAccountRecord(
        id: 1,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1234567890',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );
      const b = BankAccountRecord(
        id: 1,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1234567890',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );

      expect(a, equals(b));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/domain/entities/bank_account_record_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement `BankAccountRecord`**

```dart
// packages/platform_coin_vault/lib/src/domain/entities/bank_account_record.dart
import 'package:equatable/equatable.dart';

import '../validators/ifsc_validator.dart';

/// A bank account reference stored in the Airo Coin vault.
///
/// [nickname] is the canonical, unique-within-vault handle for this account —
/// other records (e.g. [SecureDocumentRecord.linkedAccountNickname]) refer to
/// it by this value, not by [id].
class BankAccountRecord extends Equatable {
  BankAccountRecord({
    required this.id,
    required this.nickname,
    required this.bankName,
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifscCode,
    required this.accountType,
    this.branchName,
    this.micrCode,
    this.swiftIban,
    this.customerId,
    this.upiIds,
    this.linkedMobile,
    this.linkedEmail,
    this.nomineeName,
    this.debitCardLast4,
    this.debitCardExpiry,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now() {
    if (!isValidIfsc(ifscCode)) {
      throw ArgumentError.value(ifscCode, 'ifscCode', 'Not a valid IFSC code');
    }
  }

  final int? id;
  final String nickname;
  final String bankName;
  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String accountType;
  final String? branchName;
  final String? micrCode;
  final String? swiftIban;
  final String? customerId;
  final String? upiIds;
  final String? linkedMobile;
  final String? linkedEmail;
  final String? nomineeName;
  final String? debitCardLast4;
  final String? debitCardExpiry;
  final String? notes;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    nickname,
    bankName,
    accountHolderName,
    accountNumber,
    ifscCode,
    accountType,
    branchName,
    micrCode,
    swiftIban,
    customerId,
    upiIds,
    linkedMobile,
    linkedEmail,
    nomineeName,
    debitCardLast4,
    debitCardExpiry,
    notes,
    createdAt,
  ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/platform_coin_vault && flutter test test/domain/entities/bank_account_record_test.dart`
Expected: PASS — all 3 tests green.

- [ ] **Step 5: Implement `PanCardRecord` (no dedicated test — covered by repository test in Task 7)**

```dart
// packages/platform_coin_vault/lib/src/domain/entities/pan_card_record.dart
import 'package:equatable/equatable.dart';

import '../validators/pan_validator.dart';

/// A PAN card reference stored in the Airo Coin vault.
class PanCardRecord extends Equatable {
  PanCardRecord({
    required this.id,
    required this.panNumber,
    required this.nameOnCard,
    this.fathersName,
    this.dateOfBirth,
    this.cardImageBlob,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now() {
    if (!isValidPan(panNumber)) {
      throw ArgumentError.value(panNumber, 'panNumber', 'Not a valid PAN number');
    }
  }

  final int? id;
  final String panNumber;
  final String nameOnCard;
  final String? fathersName;
  final DateTime? dateOfBirth;
  final List<int>? cardImageBlob;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    panNumber,
    nameOnCard,
    fathersName,
    dateOfBirth,
    cardImageBlob,
    createdAt,
  ];
}
```

- [ ] **Step 6: Implement `CreditCardRecord` (masked-only — no full number, CVV, or PIN)**

```dart
// packages/platform_coin_vault/lib/src/domain/entities/credit_card_record.dart
import 'package:equatable/equatable.dart';

enum CardNetwork { visa, mastercard, rupay, amex }

/// A masked credit card reference stored in the Airo Coin vault.
///
/// Deliberately excludes the full card number, CVV, and PIN — only enough
/// to identify the card is stored, matching the debit-card rule on
/// [BankAccountRecord].
class CreditCardRecord extends Equatable {
  const CreditCardRecord({
    required this.id,
    required this.nickname,
    required this.cardNetwork,
    required this.last4,
    required this.expiryMonth,
    required this.expiryYear,
    required this.issuingBank,
    required this.createdAt,
  });

  final int? id;
  final String nickname;
  final CardNetwork cardNetwork;
  final String last4;
  final int expiryMonth;
  final int expiryYear;
  final String issuingBank;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    nickname,
    cardNetwork,
    last4,
    expiryMonth,
    expiryYear,
    issuingBank,
    createdAt,
  ];
}
```

- [ ] **Step 7: Write failing test for `SecureDocumentRecord` category taxonomy**

```dart
// packages/platform_coin_vault/test/domain/entities/secure_document_record_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/domain/entities/secure_document_record.dart';

void main() {
  test('all ITR-driven categories are available', () {
    expect(DocumentCategory.values, containsAll(<DocumentCategory>[
      DocumentCategory.personalId,
      DocumentCategory.incomeProof,
      DocumentCategory.taxCredit,
      DocumentCategory.investmentProof,
      DocumentCategory.hra,
      DocumentCategory.capitalGains,
      DocumentCategory.homeLoan,
      DocumentCategory.other,
    ]));
  });

  test('linkedAccountNickname is optional', () {
    final record = SecureDocumentRecord(
      id: null,
      nickname: 'Form 16 FY24-25',
      category: DocumentCategory.incomeProof,
      createdAt: DateTime(2026, 7, 19),
    );

    expect(record.linkedAccountNickname, isNull);
  });
}
```

- [ ] **Step 8: Run test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/domain/entities/secure_document_record_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 9: Implement `SecureDocumentRecord`**

```dart
// packages/platform_coin_vault/lib/src/domain/entities/secure_document_record.dart
import 'package:equatable/equatable.dart';

/// ITR-filing-driven taxonomy for generic vault documents. New document
/// types are new values here (or [other] + custom fields) — no schema
/// migration required.
enum DocumentCategory {
  personalId,
  incomeProof,
  taxCredit,
  investmentProof,
  hra,
  capitalGains,
  homeLoan,
  other,
}

/// A generic, category-tagged secure document stored in the Airo Coin vault
/// (e.g. Form 16, Form 26AS, 80C investment proofs, rent receipts).
class SecureDocumentRecord extends Equatable {
  const SecureDocumentRecord({
    required this.id,
    required this.nickname,
    required this.category,
    required this.createdAt,
    this.linkedAccountNickname,
    this.customFields = const {},
    this.attachmentBlob,
    this.notes,
  });

  final int? id;
  final String nickname;
  final DocumentCategory category;

  /// Optional reference to [BankAccountRecord.nickname], e.g. an FD interest
  /// statement linked to the account it came from.
  final String? linkedAccountNickname;
  final Map<String, String> customFields;
  final List<int>? attachmentBlob;
  final String? notes;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    nickname,
    category,
    linkedAccountNickname,
    customFields,
    attachmentBlob,
    notes,
    createdAt,
  ];
}
```

- [ ] **Step 10: Run test to verify it passes**

Run: `cd packages/platform_coin_vault && flutter test test/domain/entities/secure_document_record_test.dart`
Expected: PASS — both tests green.

- [ ] **Step 11: Export entities from barrel file**

```dart
// packages/platform_coin_vault/lib/platform_coin_vault.dart
export 'src/domain/validators/ifsc_validator.dart';
export 'src/domain/validators/pan_validator.dart';
export 'src/domain/entities/bank_account_record.dart';
export 'src/domain/entities/pan_card_record.dart';
export 'src/domain/entities/credit_card_record.dart';
export 'src/domain/entities/secure_document_record.dart';
```

- [ ] **Step 12: Commit**

```bash
git add packages/platform_coin_vault
git commit -m "feat(platform_coin_vault): add BankAccountRecord, PanCardRecord, CreditCardRecord, SecureDocumentRecord entities"
```

---

### Task 4: `FieldCipher` — AES-256-GCM field-level encryption

**Files:**
- Create: `packages/platform_coin_vault/lib/src/crypto/field_cipher.dart`
- Test: `packages/platform_coin_vault/test/crypto/field_cipher_test.dart`
- Modify: `packages/platform_coin_vault/lib/platform_coin_vault.dart`

**Interfaces:**
- Produces: `class FieldCipher { Future<String> encryptField(String plaintext, List<int> keyBytes); Future<String> decryptField(String encoded, List<int> keyBytes); }` — consumed by all four repositories (Tasks 6–9) and by `VaultKeyManager`'s DEK generation (Task 5, via `generateKeyBytes`).

- [ ] **Step 1: Write failing tests for crypto roundtrip**

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

      final encrypted = await cipher.encryptField(plaintext, keyBytes);
      final decrypted = await cipher.decryptField(encrypted, keyBytes);

      expect(decrypted, plaintext);
    });

    test('encrypted output differs from plaintext', () async {
      const plaintext = 'ABCDE1234F';

      final encrypted = await cipher.encryptField(plaintext, keyBytes);

      expect(encrypted, isNot(contains(plaintext)));
    });

    test('same plaintext encrypted twice yields different ciphertext (random nonce)', () async {
      const plaintext = 'repeat-me';

      final first = await cipher.encryptField(plaintext, keyBytes);
      final second = await cipher.encryptField(plaintext, keyBytes);

      expect(first, isNot(equals(second)));
    });

    test('decrypting with the wrong key throws', () async {
      const plaintext = 'secret-value';
      final wrongKey = List<int>.generate(32, (_) => Random.secure().nextInt(256));

      final encrypted = await cipher.encryptField(plaintext, keyBytes);

      expect(() => cipher.decryptField(encrypted, wrongKey), throwsA(anything));
    });

    test('roundtrips empty string', () async {
      final encrypted = await cipher.encryptField('', keyBytes);
      final decrypted = await cipher.decryptField(encrypted, keyBytes);

      expect(decrypted, '');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/crypto/field_cipher_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Add `cryptography` import and implement `FieldCipher`**

```dart
// packages/platform_coin_vault/lib/src/crypto/field_cipher.dart
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM field-level cipher. Each call to [encryptField] uses a fresh
/// random nonce, so encrypting identical plaintext twice yields different
/// ciphertext — this is expected, not a bug.
class FieldCipher {
  final AesGcm _algorithm = AesGcm.with256bits();

  /// Encrypts [plaintext] with [keyBytes] (must be 32 bytes). Returns a
  /// base64-encoded string of `nonce || cipherText || mac`.
  Future<String> encryptField(String plaintext, List<int> keyBytes) async {
    final secretKey = SecretKey(keyBytes);
    final nonce = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    final combined = <int>[
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];
    return base64Encode(combined);
  }

  /// Decrypts a value produced by [encryptField]. Throws
  /// [SecretBoxAuthenticationError] if [keyBytes] is wrong or the ciphertext
  /// was tampered with.
  Future<String> decryptField(String encoded, List<int> keyBytes) async {
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
    final plainBytes = await _algorithm.decrypt(secretBox, secretKey: secretKey);
    return utf8.decode(plainBytes);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/platform_coin_vault && flutter test test/crypto/field_cipher_test.dart`
Expected: PASS — all 5 tests green.

- [ ] **Step 5: Export from barrel file**

```dart
// packages/platform_coin_vault/lib/platform_coin_vault.dart
export 'src/crypto/field_cipher.dart';
```

- [ ] **Step 6: Commit**

```bash
git add packages/platform_coin_vault
git commit -m "feat(platform_coin_vault): add AES-256-GCM FieldCipher for field-level encryption"
```

---

### Task 5: `VaultSecureStorage` and `VaultKeyManager` — biometric-gated KEK/DEK

**Files:**
- Create: `packages/platform_coin_vault/lib/src/crypto/vault_secure_storage.dart`
- Create: `packages/platform_coin_vault/lib/src/crypto/vault_key_manager.dart`
- Test: `packages/platform_coin_vault/test/crypto/vault_key_manager_test.dart`
- Modify: `packages/platform_coin_vault/lib/platform_coin_vault.dart`

**Interfaces:**
- Consumes: `core_data`'s `SecureStorage`, `EncryptionKeyManager` interfaces
  (`package:core_data/src/secure/secure_storage.dart`); `core_domain`'s
  `Result<T>`, `Success<T>`, `Failure<T>`, `AuthFailure`, `CacheFailure`
  (`package:core_domain/core_domain.dart`).
- Produces: `class VaultSecureStorage implements SecureStorage` (real impl,
  used only outside unit tests — no test targets it directly, it's a thin
  `flutter_secure_storage` wrapper exercised via `VaultKeyManager`'s tests
  using a fake); `class VaultKeyManager implements EncryptionKeyManager`, with
  constructor `VaultKeyManager({required SecureStorage secureStorage,
  required LocalAuthentication localAuth})` — consumed by all four
  repositories (Tasks 6–9) via `Future<Result<List<int>>> getDatabaseKey()`.

- [ ] **Step 1: Write failing tests for `VaultKeyManager` using a fake `SecureStorage` and fake biometric gate**

```dart
// packages/platform_coin_vault/test/crypto/vault_key_manager_test.dart
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/crypto/vault_key_manager.dart';

/// In-memory fake standing in for the real flutter_secure_storage-backed
/// SecureStorage — mirrors core_data's InMemorySecureStore pattern.
class _FakeSecureStorage {
  final Map<String, String> _store = {};

  Future<Result<String?>> read(String key) async => Success(_store[key]);

  Future<Result<void>> write(String key, String value) async {
    _store[key] = value;
    return const Success(null);
  }

  Future<Result<void>> delete(String key) async {
    _store.remove(key);
    return const Success(null);
  }

  Future<Result<void>> deleteAll() async {
    _store.clear();
    return const Success(null);
  }

  Future<Result<bool>> containsKey(String key) async =>
      Success(_store.containsKey(key));

  Future<Result<List<String>>> getAllKeys() async =>
      Success(_store.keys.toList());
}

void main() {
  late _FakeSecureStorage secureStorage;

  setUp(() {
    secureStorage = _FakeSecureStorage();
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
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/crypto/vault_key_manager_test.dart`
Expected: FAIL — file not found / `VaultKeyManager.forTesting` undefined.

- [ ] **Step 3: Implement `VaultSecureStorage`**

```dart
// packages/platform_coin_vault/lib/src/crypto/vault_secure_storage.dart
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// [SecureStorage] backed by `flutter_secure_storage` — Android Keystore /
/// iOS Keychain, same options pattern as core_data's `FlutterSecureStore`.
class VaultSecureStorage implements SecureStorage {
  VaultSecureStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(
        aOptions: AndroidOptions(storageNamespace: 'airo_coin_vault'),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
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

- [ ] **Step 4: Implement `VaultKeyManager`**

```dart
// packages/platform_coin_vault/lib/src/crypto/vault_key_manager.dart
import 'dart:math';

import 'package:core_domain/core_domain.dart';
import 'package:local_auth/local_auth.dart';

/// Structural type matching the subset of core_data's `SecureStorage` that
/// `VaultKeyManager` needs — lets the test fake avoid depending on
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
  VaultKeyManager({required LocalAuthentication localAuth, VaultKeyStore? secureStorage})
    : _authenticate = () => localAuth.authenticate(
        localizedReason: 'Unlock your Airo Coin vault',
        options: const AuthenticationOptions(biometricOnly: false),
      ),
      _localAuth = localAuth,
      _secureStorage = secureStorage ?? _requireSecureStorage();

  /// Test-only constructor: bypasses the real `local_auth` plugin and
  /// `flutter_secure_storage` platform channel, both of which are
  /// unavailable in plain `flutter test`.
  VaultKeyManager.forTesting({
    required VaultKeyStore secureStorage,
    required Future<bool> Function() authenticate,
  }) : _secureStorage = secureStorage,
       _authenticate = authenticate,
       _localAuth = null;

  final VaultKeyStore _secureStorage;
  final Future<bool> Function() _authenticate;
  final LocalAuthentication? _localAuth;

  static VaultKeyStore _requireSecureStorage() {
    throw StateError(
      'VaultKeyManager requires an explicit secureStorage instance in production — '
      'pass VaultSecureStorage().',
    );
  }

  Future<Result<List<int>>> getDatabaseKey() async {
    final authenticated = await _authenticate();
    if (!authenticated) {
      return const Failure(AuthFailure(message: 'Biometric authentication failed'));
    }

    final existing = await _secureStorage.read(_wrappedDekKey);
    if (existing case Success(value: final stored?)) {
      return Success(_decodeKey(stored));
    }

    final newKey = _generateKeyBytes();
    final writeResult = await _secureStorage.write(_wrappedDekKey, _encodeKey(newKey));
    return writeResult.fold(
      onSuccess: (_) => Success(newKey),
      onFailure: Failure.new,
    );
  }

  Future<Result<void>> rotateKey() async {
    final authenticated = await _authenticate();
    if (!authenticated) {
      return const Failure(AuthFailure(message: 'Biometric authentication failed'));
    }

    final newKey = _generateKeyBytes();
    return _secureStorage.write(_wrappedDekKey, _encodeKey(newKey));
  }

  Future<bool> isEncryptionAvailable() async {
    if (_localAuth == null) return true;
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
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/platform_coin_vault && flutter test test/crypto/vault_key_manager_test.dart`
Expected: PASS — all 5 tests green.

- [ ] **Step 6: Export from barrel file**

```dart
// packages/platform_coin_vault/lib/platform_coin_vault.dart
export 'src/crypto/vault_secure_storage.dart';
export 'src/crypto/vault_key_manager.dart';
```

- [ ] **Step 7: Add `flutter_secure_storage` and `local_auth` platform setup note**

No code needed in this task — Android manifest / iOS Info.plist biometric
usage-description strings are app-level entrypoint changes, out of scope
until `feature_coin` wires the vault into the app shell. Leave a one-line
comment in `vault_key_manager.dart` noting this (already covered by the
class doc comment above).

- [ ] **Step 8: Commit**

```bash
git add packages/platform_coin_vault
git commit -m "feat(platform_coin_vault): add VaultSecureStorage and biometric-gated VaultKeyManager"
```

---

### Task 6: `VaultDatabase` — sqflite schema for all four record types

**Files:**
- Create: `packages/platform_coin_vault/lib/src/data/vault_database.dart`
- Test: `packages/platform_coin_vault/test/data/vault_database_test.dart`
- Modify: `packages/platform_coin_vault/lib/platform_coin_vault.dart`

**Interfaces:**
- Consumes: `sqflite`'s `Database`, `openDatabase`, `databaseFactory`;
  `sqflite_common_ffi`'s `databaseFactoryFfi` (test-only).
- Produces: `class VaultDatabase { Future<void> open({String? path}); Database
  get db; Future<void> close(); }` — the four table names as constants
  (`VaultTables.bankAccounts`, `VaultTables.panCards`,
  `VaultTables.creditCards`, `VaultTables.secureDocuments`) — consumed by all
  four repositories (Tasks 7–9... wait, folded into Task 7 below).

- [ ] **Step 1: Write failing test for schema creation**

```dart
// packages/platform_coin_vault/test/data/vault_database_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('open creates all four vault tables', () async {
    final vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);

    final tables = await vaultDb.db.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table'",
    );
    final tableNames = tables.map((row) => row['name']).toSet();

    expect(
      tableNames,
      containsAll(<String>[
        VaultTables.bankAccounts,
        VaultTables.panCards,
        VaultTables.creditCards,
        VaultTables.secureDocuments,
      ]),
    );

    await vaultDb.close();
  });

  test('bank_accounts enforces unique nickname', () async {
    final vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);

    await vaultDb.db.insert(VaultTables.bankAccounts, {
      'nickname': 'HDFC Salary',
      'bank_name': 'HDFC Bank',
      'account_holder_name': 'Jane Doe',
      'account_number_enc': 'enc1',
      'ifsc_code': 'HDFC0001234',
      'account_type': 'savings',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    expect(
      () => vaultDb.db.insert(VaultTables.bankAccounts, {
        'nickname': 'HDFC Salary',
        'bank_name': 'HDFC Bank',
        'account_holder_name': 'Jane Doe',
        'account_number_enc': 'enc2',
        'ifsc_code': 'HDFC0001234',
        'account_type': 'savings',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      }),
      throwsA(anything),
    );

    await vaultDb.close();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/data/vault_database_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement `VaultDatabase`**

```dart
// packages/platform_coin_vault/lib/src/data/vault_database.dart
import 'package:sqflite/sqflite.dart';

/// Table name constants for the Airo Coin vault schema.
abstract final class VaultTables {
  static const bankAccounts = 'bank_accounts';
  static const panCards = 'pan_cards';
  static const creditCards = 'credit_cards';
  static const secureDocuments = 'secure_documents';
}

/// Opens and owns the vault's sqflite database. Holds no encryption logic
/// itself — sensitive columns already arrive pre-encrypted from the
/// repositories (see [FieldCipher]); this class only owns table DDL and the
/// open `Database` handle.
class VaultDatabase {
  VaultDatabase({DatabaseFactory? databaseFactory})
    : _databaseFactory = databaseFactory ?? databaseFactory;

  final DatabaseFactory _databaseFactory;
  Database? _db;

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('VaultDatabase.open() must be called before use');
    }
    return database;
  }

  Future<void> open({required String path}) async {
    _db = await _databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE ${VaultTables.bankAccounts} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nickname TEXT NOT NULL UNIQUE,
              bank_name TEXT NOT NULL,
              account_holder_name TEXT NOT NULL,
              account_number_enc TEXT NOT NULL,
              ifsc_code TEXT NOT NULL,
              account_type TEXT NOT NULL,
              branch_name TEXT,
              micr_code TEXT,
              swift_iban TEXT,
              customer_id TEXT,
              upi_ids TEXT,
              linked_mobile TEXT,
              linked_email TEXT,
              nominee_name TEXT,
              debit_card_last4 TEXT,
              debit_card_expiry TEXT,
              notes_enc TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE ${VaultTables.panCards} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              pan_number_enc TEXT NOT NULL,
              name_on_card TEXT NOT NULL,
              fathers_name TEXT,
              date_of_birth TEXT,
              card_image_blob_enc TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE ${VaultTables.creditCards} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nickname TEXT NOT NULL UNIQUE,
              card_network TEXT NOT NULL,
              last4 TEXT NOT NULL,
              expiry_month INTEGER NOT NULL,
              expiry_year INTEGER NOT NULL,
              issuing_bank TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE ${VaultTables.secureDocuments} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nickname TEXT NOT NULL UNIQUE,
              category TEXT NOT NULL,
              linked_account_nickname TEXT,
              custom_fields_enc TEXT,
              attachment_blob_enc TEXT,
              notes_enc TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/platform_coin_vault && flutter test test/data/vault_database_test.dart`
Expected: PASS — both tests green.

- [ ] **Step 5: Export from barrel file**

```dart
// packages/platform_coin_vault/lib/platform_coin_vault.dart
export 'src/data/vault_database.dart';
```

- [ ] **Step 6: Commit**

```bash
git add packages/platform_coin_vault
git commit -m "feat(platform_coin_vault): add VaultDatabase sqflite schema for all four record types"
```

---

### Task 7: `BankAccountRepository`

**Files:**
- Create: `packages/platform_coin_vault/lib/src/data/bank_account_repository.dart`
- Test: `packages/platform_coin_vault/test/data/bank_account_repository_test.dart`
- Modify: `packages/platform_coin_vault/lib/platform_coin_vault.dart`

**Interfaces:**
- Consumes: `VaultDatabase`/`VaultTables.bankAccounts` (Task 6), `FieldCipher`
  (Task 4), `BankAccountRecord` (Task 3), `Result<T>`/`Success`/`Failure`/
  `ValidationFailure`/`DatabaseFailure` (`core_domain`).
- Produces: `class BankAccountRepository { Future<Result<int>>
  create(BankAccountRecord record, List<int> keyBytes); Future<Result<
  BankAccountRecord?>> getByNickname(String nickname, List<int> keyBytes); }`
  — `getByNickname` is what `SecureDocumentRepository` (Task 9) will later
  call to validate `linkedAccountNickname` references, though that
  cross-repository check is deferred (see Task 9's scope note).

- [ ] **Step 1: Write failing tests for create + retrieve + uniqueness**

```dart
// packages/platform_coin_vault/test/data/bank_account_repository_test.dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/crypto/field_cipher.dart';
import 'package:platform_coin_vault/src/data/bank_account_repository.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:platform_coin_vault/src/domain/entities/bank_account_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VaultDatabase vaultDb;
  late BankAccountRepository repository;
  late List<int> keyBytes;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    repository = BankAccountRepository(
      database: vaultDb,
      fieldCipher: FieldCipher(),
    );
    keyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  });

  tearDown(() async {
    await vaultDb.close();
  });

  group('BankAccountRepository', () {
    test('create then getByNickname roundtrips the decrypted account number', () async {
      final record = BankAccountRecord(
        id: null,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1234567890',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );

      final createResult = await repository.create(record, keyBytes);
      expect(createResult.isSuccess, isTrue);

      final fetched = await repository.getByNickname('HDFC Salary', keyBytes);

      expect(fetched.value?.accountNumber, '1234567890');
      expect(fetched.value?.nickname, 'HDFC Salary');
    });

    test('stored account_number_enc column is never plaintext', () async {
      final record = BankAccountRecord(
        id: null,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1234567890',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );

      await repository.create(record, keyBytes);

      final rows = await vaultDb.db.query(VaultTables.bankAccounts);
      expect(rows.single['account_number_enc'], isNot('1234567890'));
    });

    test('creating a second account with the same nickname fails', () async {
      final first = BankAccountRecord(
        id: null,
        nickname: 'Shared Nick',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1111111111',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );
      final second = BankAccountRecord(
        id: null,
        nickname: 'Shared Nick',
        bankName: 'ICICI Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '2222222222',
        ifscCode: 'ICIC0005678',
        accountType: 'current',
      );

      await repository.create(first, keyBytes);
      final secondResult = await repository.create(second, keyBytes);

      expect(secondResult.isFailure, isTrue);
    });

    test('getByNickname returns null for an unknown nickname', () async {
      final result = await repository.getByNickname('Nobody', keyBytes);

      expect(result.isSuccess, isTrue);
      expect(result.value, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/data/bank_account_repository_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement `BankAccountRepository`**

```dart
// packages/platform_coin_vault/lib/src/data/bank_account_repository.dart
import 'package:core_domain/core_domain.dart';
import 'package:sqflite/sqflite.dart';

import '../crypto/field_cipher.dart';
import '../domain/entities/bank_account_record.dart';
import 'vault_database.dart';

/// Repository for [BankAccountRecord]. Encrypts [BankAccountRecord.accountNumber]
/// and [BankAccountRecord.notes] before persisting; decrypts them on read.
class BankAccountRepository {
  BankAccountRepository({required VaultDatabase database, required FieldCipher fieldCipher})
    : _database = database,
      _fieldCipher = fieldCipher;

  final VaultDatabase _database;
  final FieldCipher _fieldCipher;

  Future<Result<int>> create(BankAccountRecord record, List<int> keyBytes) async {
    try {
      final accountNumberEnc = await _fieldCipher.encryptField(
        record.accountNumber,
        keyBytes,
      );
      final notesEnc = record.notes == null
          ? null
          : await _fieldCipher.encryptField(record.notes!, keyBytes);

      final id = await _database.db.insert(VaultTables.bankAccounts, {
        'nickname': record.nickname,
        'bank_name': record.bankName,
        'account_holder_name': record.accountHolderName,
        'account_number_enc': accountNumberEnc,
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
        'notes_enc': notesEnc,
        'created_at': record.createdAt.millisecondsSinceEpoch,
      });
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
      final accountNumber = await _fieldCipher.decryptField(
        row['account_number_enc'] as String,
        keyBytes,
      );
      final notesEnc = row['notes_enc'] as String?;
      final notes = notesEnc == null
          ? null
          : await _fieldCipher.decryptField(notesEnc, keyBytes);

      return Success(BankAccountRecord(
        id: row['id'] as int,
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

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/platform_coin_vault && flutter test test/data/bank_account_repository_test.dart`
Expected: PASS — all 4 tests green.

- [ ] **Step 5: Export from barrel file**

```dart
// packages/platform_coin_vault/lib/platform_coin_vault.dart
export 'src/data/bank_account_repository.dart';
```

- [ ] **Step 6: Commit**

```bash
git add packages/platform_coin_vault
git commit -m "feat(platform_coin_vault): add BankAccountRepository with field-level encryption"
```

---

### Task 8: `PanCardRepository` and `CreditCardRepository`

**Files:**
- Create: `packages/platform_coin_vault/lib/src/data/pan_card_repository.dart`
- Create: `packages/platform_coin_vault/lib/src/data/credit_card_repository.dart`
- Test: `packages/platform_coin_vault/test/data/pan_card_repository_test.dart`
- Test: `packages/platform_coin_vault/test/data/credit_card_repository_test.dart`
- Modify: `packages/platform_coin_vault/lib/platform_coin_vault.dart`

**Interfaces:**
- Consumes: same as Task 7, plus `PanCardRecord`, `CreditCardRecord`,
  `CardNetwork` (Task 3).
- Produces: `class PanCardRepository { Future<Result<int>> create(PanCardRecord
  record, List<int> keyBytes); Future<Result<PanCardRecord?>> getById(int id,
  List<int> keyBytes); }`; `class CreditCardRepository { Future<Result<int>>
  create(CreditCardRecord record); Future<Result<CreditCardRecord?>>
  getByNickname(String nickname); }` (no `keyBytes` param — `CreditCardRecord`
  has no encrypted fields, per the masked-only decision).

- [ ] **Step 1: Write failing tests for `PanCardRepository`**

```dart
// packages/platform_coin_vault/test/data/pan_card_repository_test.dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/crypto/field_cipher.dart';
import 'package:platform_coin_vault/src/data/pan_card_repository.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:platform_coin_vault/src/domain/entities/pan_card_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VaultDatabase vaultDb;
  late PanCardRepository repository;
  late List<int> keyBytes;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    repository = PanCardRepository(database: vaultDb, fieldCipher: FieldCipher());
    keyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  });

  tearDown(() async {
    await vaultDb.close();
  });

  test('create then getById roundtrips the decrypted PAN number', () async {
    final record = PanCardRecord(
      id: null,
      panNumber: 'ABCDE1234F',
      nameOnCard: 'Jane Doe',
    );

    final createResult = await repository.create(record, keyBytes);
    expect(createResult.isSuccess, isTrue);

    final fetched = await repository.getById(createResult.value, keyBytes);

    expect(fetched.value?.panNumber, 'ABCDE1234F');
  });

  test('stored pan_number_enc column is never plaintext', () async {
    final record = PanCardRecord(id: null, panNumber: 'ABCDE1234F', nameOnCard: 'Jane Doe');
    final createResult = await repository.create(record, keyBytes);

    final rows = await vaultDb.db.query(VaultTables.panCards);
    expect(rows.single['pan_number_enc'], isNot('ABCDE1234F'));
    expect(createResult.isSuccess, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/data/pan_card_repository_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement `PanCardRepository`**

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
      final panNumberEnc = await _fieldCipher.encryptField(record.panNumber, keyBytes);
      final id = await _database.db.insert(VaultTables.panCards, {
        'pan_number_enc': panNumberEnc,
        'name_on_card': record.nameOnCard,
        'fathers_name': record.fathersName,
        'date_of_birth': record.dateOfBirth?.millisecondsSinceEpoch,
        'card_image_blob_enc': record.cardImageBlob == null
            ? null
            : await _fieldCipher.encryptField(
                String.fromCharCodes(record.cardImageBlob!),
                keyBytes,
              ),
        'created_at': record.createdAt.millisecondsSinceEpoch,
      });
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
            : (await _fieldCipher.decryptField(blobEnc, keyBytes)).codeUnits,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      ));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to read PAN card', cause: e));
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/platform_coin_vault && flutter test test/data/pan_card_repository_test.dart`
Expected: PASS — both tests green.

- [ ] **Step 5: Write failing tests for `CreditCardRepository`**

```dart
// packages/platform_coin_vault/test/data/credit_card_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/data/credit_card_repository.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:platform_coin_vault/src/domain/entities/credit_card_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VaultDatabase vaultDb;
  late CreditCardRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    repository = CreditCardRepository(database: vaultDb);
  });

  tearDown(() async {
    await vaultDb.close();
  });

  test('create then getByNickname roundtrips a masked credit card', () async {
    final record = CreditCardRecord(
      id: null,
      nickname: 'HDFC Regalia',
      cardNetwork: CardNetwork.visa,
      last4: '4242',
      expiryMonth: 12,
      expiryYear: 2028,
      issuingBank: 'HDFC Bank',
      createdAt: DateTime(2026, 7, 19),
    );

    final createResult = await repository.create(record);
    expect(createResult.isSuccess, isTrue);

    final fetched = await repository.getByNickname('HDFC Regalia');

    expect(fetched.value?.last4, '4242');
    expect(fetched.value?.cardNetwork, CardNetwork.visa);
  });

  test('creating a second card with the same nickname fails', () async {
    final record = CreditCardRecord(
      id: null,
      nickname: 'Shared Card',
      cardNetwork: CardNetwork.mastercard,
      last4: '1111',
      expiryMonth: 1,
      expiryYear: 2027,
      issuingBank: 'ICICI Bank',
      createdAt: DateTime(2026, 7, 19),
    );

    await repository.create(record);
    final result = await repository.create(record);

    expect(result.isFailure, isTrue);
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/data/credit_card_repository_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 7: Implement `CreditCardRepository`**

```dart
// packages/platform_coin_vault/lib/src/data/credit_card_repository.dart
import 'package:core_domain/core_domain.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/entities/credit_card_record.dart';
import 'vault_database.dart';

/// Repository for [CreditCardRecord]. No field is encrypted here — the
/// record is masked-only (network, last4, expiry, issuing bank), none of
/// which requires AES-GCM protection.
class CreditCardRepository {
  CreditCardRepository({required VaultDatabase database}) : _database = database;

  final VaultDatabase _database;

  Future<Result<int>> create(CreditCardRecord record) async {
    try {
      final id = await _database.db.insert(VaultTables.creditCards, {
        'nickname': record.nickname,
        'card_network': record.cardNetwork.name,
        'last4': record.last4,
        'expiry_month': record.expiryMonth,
        'expiry_year': record.expiryYear,
        'issuing_bank': record.issuingBank,
        'created_at': record.createdAt.millisecondsSinceEpoch,
      });
      return Success(id);
    } on DatabaseException catch (e) {
      return Failure(ValidationFailure(
        message: 'A card with nickname "${record.nickname}" already exists',
        field: 'nickname',
        cause: e,
      ));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to create credit card', cause: e));
    }
  }

  Future<Result<CreditCardRecord?>> getByNickname(String nickname) async {
    try {
      final rows = await _database.db.query(
        VaultTables.creditCards,
        where: 'nickname = ?',
        whereArgs: [nickname],
        limit: 1,
      );
      if (rows.isEmpty) return const Success(null);

      final row = rows.single;
      return Success(CreditCardRecord(
        id: row['id'] as int,
        nickname: row['nickname'] as String,
        cardNetwork: CardNetwork.values.byName(row['card_network'] as String),
        last4: row['last4'] as String,
        expiryMonth: row['expiry_month'] as int,
        expiryYear: row['expiry_year'] as int,
        issuingBank: row['issuing_bank'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      ));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to read credit card', cause: e));
    }
  }
}
```

- [ ] **Step 8: Run test to verify it passes**

Run: `cd packages/platform_coin_vault && flutter test test/data/credit_card_repository_test.dart`
Expected: PASS — both tests green.

- [ ] **Step 9: Export from barrel file**

```dart
// packages/platform_coin_vault/lib/platform_coin_vault.dart
export 'src/data/pan_card_repository.dart';
export 'src/data/credit_card_repository.dart';
```

- [ ] **Step 10: Commit**

```bash
git add packages/platform_coin_vault
git commit -m "feat(platform_coin_vault): add PanCardRepository and CreditCardRepository"
```

---

### Task 9: `SecureDocumentRepository`

**Files:**
- Create: `packages/platform_coin_vault/lib/src/data/secure_document_repository.dart`
- Test: `packages/platform_coin_vault/test/data/secure_document_repository_test.dart`
- Modify: `packages/platform_coin_vault/lib/platform_coin_vault.dart`

**Interfaces:**
- Consumes: `VaultDatabase`, `FieldCipher`, `SecureDocumentRecord`,
  `DocumentCategory` (Task 3).
- Produces: `class SecureDocumentRepository { Future<Result<int>>
  create(SecureDocumentRecord record, List<int> keyBytes); Future<Result<
  SecureDocumentRecord?>> getByNickname(String nickname, List<int> keyBytes);
  }`.
- Scope note: `linkedAccountNickname` is stored as a plain string reference
  and is **not** validated against `BankAccountRepository` in this task —
  cross-repository referential checks are a `feature_coin`-layer concern
  (form validation UI), not a storage-layer one. This repository only
  persists and returns the value.

- [ ] **Step 1: Write failing tests**

```dart
// packages/platform_coin_vault/test/data/secure_document_repository_test.dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/crypto/field_cipher.dart';
import 'package:platform_coin_vault/src/data/secure_document_repository.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:platform_coin_vault/src/domain/entities/secure_document_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VaultDatabase vaultDb;
  late SecureDocumentRepository repository;
  late List<int> keyBytes;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    repository = SecureDocumentRepository(database: vaultDb, fieldCipher: FieldCipher());
    keyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  });

  tearDown(() async {
    await vaultDb.close();
  });

  test('create then getByNickname roundtrips category and linked account', () async {
    final record = SecureDocumentRecord(
      id: null,
      nickname: 'Form 16 FY24-25',
      category: DocumentCategory.incomeProof,
      linkedAccountNickname: 'HDFC Salary',
      notes: 'Employer TDS certificate',
      createdAt: DateTime(2026, 7, 19),
    );

    final createResult = await repository.create(record, keyBytes);
    expect(createResult.isSuccess, isTrue);

    final fetched = await repository.getByNickname('Form 16 FY24-25', keyBytes);

    expect(fetched.value?.category, DocumentCategory.incomeProof);
    expect(fetched.value?.linkedAccountNickname, 'HDFC Salary');
    expect(fetched.value?.notes, 'Employer TDS certificate');
  });

  test('stored notes_enc column is never plaintext', () async {
    final record = SecureDocumentRecord(
      id: null,
      nickname: 'AIS FY24-25',
      category: DocumentCategory.taxCredit,
      notes: 'Downloaded from e-filing portal',
      createdAt: DateTime(2026, 7, 19),
    );

    await repository.create(record, keyBytes);

    final rows = await vaultDb.db.query(VaultTables.secureDocuments);
    expect(rows.single['notes_enc'], isNot('Downloaded from e-filing portal'));
  });

  test('custom fields roundtrip through encryption', () async {
    final record = SecureDocumentRecord(
      id: null,
      nickname: '80C Receipt',
      category: DocumentCategory.investmentProof,
      customFields: {'insurer': 'LIC', 'premium': '25000'},
      createdAt: DateTime(2026, 7, 19),
    );

    await repository.create(record, keyBytes);
    final fetched = await repository.getByNickname('80C Receipt', keyBytes);

    expect(fetched.value?.customFields, {'insurer': 'LIC', 'premium': '25000'});
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/data/secure_document_repository_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement `SecureDocumentRepository`**

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
      final customFieldsEnc = record.customFields.isEmpty
          ? null
          : await _fieldCipher.encryptField(jsonEncode(record.customFields), keyBytes);
      final notesEnc = record.notes == null
          ? null
          : await _fieldCipher.encryptField(record.notes!, keyBytes);
      final attachmentEnc = record.attachmentBlob == null
          ? null
          : await _fieldCipher.encryptField(
              String.fromCharCodes(record.attachmentBlob!),
              keyBytes,
            );

      final id = await _database.db.insert(VaultTables.secureDocuments, {
        'nickname': record.nickname,
        'category': record.category.name,
        'linked_account_nickname': record.linkedAccountNickname,
        'custom_fields_enc': customFieldsEnc,
        'attachment_blob_enc': attachmentEnc,
        'notes_enc': notesEnc,
        'created_at': record.createdAt.millisecondsSinceEpoch,
      });
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
      final customFieldsEnc = row['custom_fields_enc'] as String?;
      final notesEnc = row['notes_enc'] as String?;
      final attachmentEnc = row['attachment_blob_enc'] as String?;

      final customFields = customFieldsEnc == null
          ? <String, String>{}
          : Map<String, String>.from(
              jsonDecode(await _fieldCipher.decryptField(customFieldsEnc, keyBytes)) as Map,
            );

      return Success(SecureDocumentRecord(
        id: row['id'] as int,
        nickname: row['nickname'] as String,
        category: DocumentCategory.values.byName(row['category'] as String),
        linkedAccountNickname: row['linked_account_nickname'] as String?,
        customFields: customFields,
        attachmentBlob: attachmentEnc == null
            ? null
            : (await _fieldCipher.decryptField(attachmentEnc, keyBytes)).codeUnits,
        notes: notesEnc == null ? null : await _fieldCipher.decryptField(notesEnc, keyBytes),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      ));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to read secure document', cause: e));
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/platform_coin_vault && flutter test test/data/secure_document_repository_test.dart`
Expected: PASS — all 3 tests green.

- [ ] **Step 5: Export from barrel file**

```dart
// packages/platform_coin_vault/lib/platform_coin_vault.dart
export 'src/data/secure_document_repository.dart';
```

- [ ] **Step 6: Commit**

```bash
git add packages/platform_coin_vault
git commit -m "feat(platform_coin_vault): add SecureDocumentRepository with ITR category taxonomy"
```

---

### Task 10: No-biometrics-enrolled path + ADR

**Files:**
- Test: `packages/platform_coin_vault/test/crypto/vault_key_manager_test.dart` (append)
- Create: `docs/adr/0001-airo-coin-vault-crypto.md`

**Interfaces:**
- Consumes: `VaultKeyManager.isEncryptionAvailable()` (Task 5).
- Produces: nothing new — this task adds the explicit no-biometrics test the
  spec calls out and closes the loop with a written threat-model ADR.

- [ ] **Step 1: Write failing test for the no-biometrics-enrolled path**

Append to `packages/platform_coin_vault/test/crypto/vault_key_manager_test.dart`,
inside the existing `group('VaultKeyManager', ...)` block:

```dart
    test('isEncryptionAvailable reports false when biometrics are unavailable, blocking vault creation', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => false,
      );

      // forTesting bypasses local_auth's canCheckBiometrics/isDeviceSupported,
      // so isEncryptionAvailable() short-circuits to true for this fake path;
      // the real gate is exercised through getDatabaseKey's auth failure,
      // asserted above. This test documents the contract: a caller MUST
      // check isEncryptionAvailable() before offering vault creation, and
      // getDatabaseKey() MUST fail closed (never silently no-op) when
      // authentication is unavailable or denied.
      final result = await manager.getDatabaseKey();

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<AuthFailure>());
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/crypto/vault_key_manager_test.dart`
Expected: FAIL if the assertion doesn't already hold — but given Task 5's
implementation, this should already PASS on first run since `getDatabaseKey`
already fails closed on `authenticate() => false`. Run it to confirm; if it
passes immediately, that confirms the fail-closed behavior is real, not
assumed — proceed to Step 3 without code changes.

- [ ] **Step 3: Run full package test suite**

Run: `cd packages/platform_coin_vault && flutter test`
Expected: PASS — every test file green (validators, entities, `FieldCipher`,
`VaultKeyManager`, `VaultDatabase`, all four repositories).

- [ ] **Step 4: Write the threat-model ADR**

```markdown
# 0001. Airo Coin vault crypto design and threat model

Date: 2026-07-19
Status: Accepted

## Context

Airo Coin (issue #927) stores PAN card, bank account, credit card reference,
and financial document data locally on the user's phone/iPad, encrypted at
rest, unlockable only via biometrics. This ADR records the crypto design
implemented in `platform_coin_vault` and the threat model it targets.

## Decision

- **Field-level AES-256-GCM encryption** (via the `cryptography` package),
  not full-disk/SQLCipher encryption. Sensitive columns (account number, PAN
  number, notes, custom fields, attachment blobs) are individually encrypted
  before insert. This avoids introducing a second native sqlite runtime
  alongside `platform_playlist`'s existing `drift` + `sqlite3_flutter_libs`
  stack (see PR #925, which fixed a dual-runtime bug from a related cause).
- **KEK boundary**: `flutter_secure_storage`, backed by Android Keystore
  (StrongBox/TEE when available) / iOS Keychain (Secure Enclave). The DEK is
  generated once and persisted through this boundary — we do not implement a
  separate explicit key-wrap step, matching `core_data`'s existing
  `EncryptionService` pattern.
- **Biometric gate**: `local_auth`, with OS-provided device-credential
  fallback (PIN/pattern/Face ID/fingerprint) — never a custom in-app PIN
  screen storing its own secret. `VaultKeyManager.getDatabaseKey()` and
  `.rotateKey()` both fail closed (`AuthFailure`) when authentication fails
  or is unavailable; there is no silent no-op path.

## Threat model — in scope

- **Lost or stolen device.** Defended by the biometric gate plus
  hardware-backed KEK storage — the DEK is unreachable without a successful
  biometric (or OS-fallback) authentication on the physical device.
- **Rooted/jailbroken device malware, short of hardware key extraction.**
  Field-level encryption means a compromised app process still needs the DEK
  (guarded by the biometric gate) to read plaintext; a malicious app reading
  the raw sqlite file sees ciphertext only.
- **Shoulder-surfing.** Sensitive fields are masked by default at the
  `feature_coin` UI layer (deferred, but this layer's encryption is the
  precondition that makes masking meaningful rather than cosmetic).

## Threat model — explicitly out of scope

- **Hardware/chip-off attacks** against the Secure Enclave/StrongBox
  themselves. Out of scope — defending against physical extraction of
  hardware-backed keys is beyond what a mobile app can control.
- **Nation-state-level adversaries.** Out of scope for a personal finance
  vault app.
- **Cloud sync/backup compromise.** No cloud sync exists in v1 — there is no
  attack surface here to defend or accept risk on yet.

## Consequences

- Any future addition of a new sensitive field must go through `FieldCipher`,
  not be added as a plaintext column — this is a review-time check for
  Chief Security Officer sign-off on future PRs touching `platform_coin_vault`.
- `feature_coin` (the presentation layer, designed separately) inherits the
  fail-closed contract: it must call `isEncryptionAvailable()` before
  offering vault creation and must surface `AuthFailure` as a hard stop, not
  a retry-silently path.
```

- [ ] **Step 5: Commit**

```bash
git add packages/platform_coin_vault docs/adr/0001-airo-coin-vault-crypto.md
git commit -m "docs: add Airo Coin vault crypto threat-model ADR; confirm no-biometrics fail-closed path"
```

---

## Plan Self-Review

**Spec coverage:**
- Four record types (Bank/PAN/CreditCard-masked/SecureDocument) — Task 3. ✓
- `nickname` as canonical account-source key, unique constraint — Tasks 3, 6, 7. ✓
- CreditCard masked-only, no full number/CVV/PIN — Task 3, 8. ✓
- `SecureDocumentRecord` ITR category taxonomy + `linkedAccountNickname` — Task 3, 9. ✓
- KEK/DEK via `flutter_secure_storage`, biometric gate via `local_auth` — Task 5. ✓
- No SQLCipher/second sqlite runtime — Task 6 uses `sqflite` only. ✓
- Field-level AES-256-GCM — Task 4. ✓
- IFSC/PAN validators — Task 2. ✓
- module.yaml governance — Task 1. ✓
- Unit tests: crypto roundtrip, validators, repositories, no-biometrics path — Tasks 2, 4, 5, 7–10. ✓
- ADR — Task 10. ✓

**Placeholder scan:** no TBD/TODO; every step has runnable code and exact commands.

**Type consistency:** `VaultKeyManager.getDatabaseKey()` returns `Result<List<int>>`
consistently across Tasks 5, 7, 8, 9. `FieldCipher.encryptField`/`decryptField`
signatures match across all four repositories. `VaultTables` constants used
identically in Task 6 and all repository tasks.

---

Plan complete and saved to `docs/superpowers/plans/2026-07-19-airo-coin-vault.md`. Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
