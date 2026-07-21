# feature_coin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Airo Coin vault presentation layer (`feature_coin`) on top of `platform_coin_vault`, per `docs/superpowers/specs/2026-07-20-feature-coin-design.md`.

**Architecture:** Four slices, each a separate PR. (1) Extend `platform_coin_vault` repos with no-key summary projections + update/delete. (2) Rename `packages/airomoney` → `packages/feature_coin` and build the session core (VaultSession Riverpod notifier owning the DEK, clipboard service). (3) Vault UI: gate/lock screens, summary-driven home list, reveal-on-demand detail sheet, add/edit forms. (4) Shell wiring under the existing `/money` (Coins) branch, FLAG_SECURE, pubspec swaps.

**Tech Stack:** Flutter, Riverpod 3.3.2 (`Notifier`/`NotifierProvider`), sqflite (+`sqflite_common_ffi` for tests), `local_auth`, `screen_protector`, `go_router`, `core_domain` Result types, `core_ui` widgets.

**Working dir:** `.worktrees/feature-coin` (branch `feature/feature-coin`). All paths below are relative to the repo root inside that worktree. All iterative commits end with `[skip ci]` (AGENTS.md CI cost rule).

**Key repo facts (verified against source):**
- `Result<T>` from `package:core_domain/core_domain.dart`: `Success(value)` / `Failure(failure)`; helpers `isSuccess`, `isFailure`, `value`, `valueOrNull`, `failure`. Failure types: `ValidationFailure(message:, field:)`, `AuthFailure`, `DatabaseFailure`, `CacheFailure`, `NotFoundFailure(message:, resourceType:, resourceId:)`.
- Repos: `BankAccountRepository({required VaultDatabase database, required FieldCipher fieldCipher})`; same for PAN/secure-document; `CreditCardRepository({required VaultDatabase database})` (no cipher, nothing encrypted). `FieldCipher()` no-arg constructor.
- **`pan_cards` table has NO nickname column** — PAN records are keyed by row `id`.
- `BankAccountRecord`/`PanCardRecord` constructors throw `ArgumentError` on invalid IFSC/PAN. `SecureDocumentRecord.createdAt` and `CreditCardRecord.createdAt` are required (no default).
- Test pattern: `sqfliteFfiInit()` in `setUpAll`, `VaultDatabase(databaseFactory: databaseFactoryFfi)` + `await db.open(path: inMemoryDatabasePath)` per test.
- `VaultKeyManager.forTesting({required VaultKeyStore secureStorage, required Future<bool> Function() authenticate, Future<bool> Function()? isAvailable})` is the test seam.
- `core_ui` exports `EmptyStateWidget({required message, title, icon, action})` and `ErrorView({required message, title, icon, onRetry, retryLabel})`.

---

## File Structure

**Slice 1 — `packages/platform_coin_vault/`:**
- Create `lib/src/domain/entities/vault_entry_summary.dart` — sealed summary projections (unencrypted columns only)
- Modify `lib/src/data/bank_account_repository.dart`, `pan_card_repository.dart`, `credit_card_repository.dart`, `secure_document_repository.dart` — add `listAllSummaries`/`update`/delete
- Modify `lib/platform_coin_vault.dart` — export summaries
- Create `test/data/bank_account_crud_test.dart`, `pan_card_crud_test.dart`, `credit_card_crud_test.dart`, `secure_document_crud_test.dart`, `test/domain/entities/vault_entry_summary_test.dart`

**Slice 2 — `packages/airomoney` → `packages/feature_coin/` (git mv, then gut):**
- `pubspec.yaml`, `module.yaml`, `lib/feature_coin.dart` (barrel)
- Create `lib/src/application/vault_config.dart` — timing constants
- Create `lib/src/application/vault_providers.dart` — DB/repos/key-manager providers
- Create `lib/src/application/vault_session.dart` — VaultSession state + notifier
- Create `lib/src/presentation/widgets/vault_lifecycle_observer.dart` — background→lock wiring
- Create `lib/src/application/clipboard_service.dart` — copy-with-auto-clear
- Tests mirror each file under `test/`

**Slice 3 — `packages/feature_coin/`:**
- `lib/src/presentation/screens/vault_lock_screen.dart` — lock/unavailable/auth-error views
- `lib/src/application/vault_summaries_provider.dart` — aggregated summaries provider
- `lib/src/presentation/widgets/masked_vault_field.dart` — masked field row
- `lib/src/presentation/widgets/record_detail_sheet.dart` — detail/reveal/copy/edit/delete
- `lib/src/presentation/screens/vault_home_screen.dart` — grouped list + FAB
- `lib/src/presentation/screens/vault_gate_screen.dart` — session switch + screen security
- `lib/src/application/screen_security.dart` — screen_protector wrapper
- `lib/src/presentation/screens/vault_record_form_screen.dart` — form dispatcher + `VaultRecordType`
- `lib/src/presentation/widgets/forms/{bank_account_form,pan_card_form,credit_card_form,secure_document_form}.dart`

**Slice 4 — `app/`:**
- Modify `app/lib/core/routing/route_names.dart`, `app/lib/core/routing/app_router.dart`
- Modify `app/lib/features/coins/presentation/screens/coins_dashboard_screen.dart`
- Modify `app/lib/features/home/screens/home_screen.dart`
- Modify `app/pubspec.yaml`, `app/pubspec_ios_spm.yaml` (never `app/pubspec_tv.yaml`)

---

### Task 0: GitHub issue with deterministic use cases (AGENTS.md lifecycle gate)

**Files:** none (GitHub only)

- [ ] **Step 1: Create the issue**

Write `/tmp/feature-coin-issue.md`:

```markdown
## feature_coin: Airo Coin vault presentation layer

Spec: `docs/superpowers/specs/2026-07-20-feature-coin-design.md`
Plan: `docs/superpowers/plans/2026-07-20-feature-coin.md`
Builds on: platform_coin_vault (#944/#946/#947), ADR 0009.

Owner: Coins / Finance Agent (application). Impacted modules:
`platform_coin_vault` (framework — council review), `feature_coin`
(rename of `airomoney`), `app` shell.

## Deterministic use cases

- UC-1: Fresh vault → tap Secure Vault → biometric prompt → unlock → empty
  grouped list shown. (widget test)
- UC-2: Add bank account with invalid IFSC → inline field error, nothing
  persisted. Valid IFSC → record appears in list. (widget + repo test)
- UC-3: Detail sheet → account number masked by default → tap reveal →
  plaintext shown → copy → clipboard auto-clears after 30s unless clipboard
  changed. (widget test with fakeAsync)
- UC-4: 60s idle → auto-lock; app background → immediate lock; manual lock
  button → lock. DEK bytes zeroed. (notifier test with fakeAsync)
- UC-5: Delete → confirmation dialog → fresh OS biometric prompt → record
  gone from list. (widget test with mocked local_auth)
- UC-6: Device without biometrics → `isEncryptionAvailable()` false →
  unavailable empty state, no vault creation offered. (notifier + widget test)
- UC-7: Duplicate nickname → `ValidationFailure(field: nickname)` → inline
  error on nickname field. (repo + widget test)
- UC-8: FLAG_SECURE active while vault routes visible, removed on exit.
  (manual dogfood on Android device; code = screen_protector wrapper)
- UC-9: PAN records keyed by row id (no nickname); edit/delete by id works.
  (repo test)
- UC-10: List screens render without the DEK (summaries built from
  unencrypted columns only). (repo test: list succeeds with no keyBytes)

## Automation flows

- `flutter test` in packages/platform_coin_vault and packages/feature_coin
- `dart analyze` in both packages and app
- Manual dogfood: biometric prompt, FLAG_SECURE, background→lock on a
  physical Android device

## Slice PRs

1. platform_coin_vault list/update/delete + summaries
2. airomoney→feature_coin rename + VaultSession + clipboard
3. Vault UI (gate/lock, home, detail sheet, forms)
4. Shell wiring (/money/vault routes, dashboard card, pubspec swaps)

Out of scope: attachments, rotateKey UI (destructive until re-encryption
migration exists), TV/desktop, cloud sync, transactions/balances.
```

Run:

```bash
gh issue create --title "feature_coin: Airo Coin vault presentation layer" --body-file /tmp/feature-coin-issue.md
```

- [ ] **Step 2: Commit nothing** (issue only; note the issue number for PR bodies)

---

## SLICE 1 — platform_coin_vault: summaries + update/delete (PR 1)

### Task 1: VaultEntrySummary domain types

**Files:**
- Create: `packages/platform_coin_vault/lib/src/domain/entities/vault_entry_summary.dart`
- Modify: `packages/platform_coin_vault/lib/platform_coin_vault.dart`
- Test: `packages/platform_coin_vault/test/domain/entities/vault_entry_summary_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/domain/entities/credit_card_record.dart';
import 'package:platform_coin_vault/src/domain/entities/secure_document_record.dart';
import 'package:platform_coin_vault/src/domain/entities/vault_entry_summary.dart';

void main() {
  group('VaultEntrySummary types', () {
    test('BankAccountSummary equality is value-based', () {
      const a = BankAccountSummary(
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );
      const b = BankAccountSummary(
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );
      expect(a, equals(b));
    });

    test('PanCardSummary is keyed by row id', () {
      const summary = PanCardSummary(id: 7, nameOnCard: 'JANE DOE');
      expect(summary.id, 7);
      expect(summary.fathersName, isNull);
    });

    test('CreditCardSummary carries only masked-only fields', () {
      const summary = CreditCardSummary(
        nickname: 'ICICI Amazon Pay',
        cardNetwork: CardNetwork.visa,
        last4: '4321',
        expiryMonth: 8,
        expiryYear: 2029,
        issuingBank: 'ICICI Bank',
      );
      expect(summary.last4, '4321');
      expect(summary.cardNetwork, CardNetwork.visa);
    });

    test('SecureDocumentSummary exposes hasAttachment without decrypting', () {
      const summary = SecureDocumentSummary(
        nickname: 'Form 16 FY25',
        category: DocumentCategory.incomeProof,
        linkedAccountNickname: 'HDFC Salary',
        hasAttachment: false,
      );
      expect(summary.category, DocumentCategory.incomeProof);
      expect(summary.hasAttachment, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/domain/entities/vault_entry_summary_test.dart`
Expected: FAIL — `vault_entry_summary.dart` does not exist.

- [ ] **Step 3: Write the implementation**

`packages/platform_coin_vault/lib/src/domain/entities/vault_entry_summary.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'credit_card_record.dart';
import 'secure_document_record.dart';

/// List-screen projection of a vault record, built only from columns stored
/// unencrypted. Rendering a summary never requires the vault DEK, so list
/// screens perform no decryption at all.
sealed class VaultEntrySummary extends Equatable {
  const VaultEntrySummary();
}

final class BankAccountSummary extends VaultEntrySummary {
  const BankAccountSummary({
    required this.nickname,
    required this.bankName,
    required this.accountHolderName,
    required this.ifscCode,
    required this.accountType,
  });

  final String nickname;
  final String bankName;
  final String accountHolderName;
  final String ifscCode;
  final String accountType;

  @override
  List<Object?> get props =>
      [nickname, bankName, accountHolderName, ifscCode, accountType];
}

final class PanCardSummary extends VaultEntrySummary {
  const PanCardSummary({
    required this.id,
    required this.nameOnCard,
    this.fathersName,
  });

  /// PAN cards have no nickname column — the row id is the canonical handle.
  final int id;
  final String nameOnCard;
  final String? fathersName;

  @override
  List<Object?> get props => [id, nameOnCard, fathersName];
}

final class CreditCardSummary extends VaultEntrySummary {
  const CreditCardSummary({
    required this.nickname,
    required this.cardNetwork,
    required this.last4,
    required this.expiryMonth,
    required this.expiryYear,
    required this.issuingBank,
  });

  final String nickname;
  final CardNetwork cardNetwork;
  final String last4;
  final int expiryMonth;
  final int expiryYear;
  final String issuingBank;

  @override
  List<Object?> get props =>
      [nickname, cardNetwork, last4, expiryMonth, expiryYear, issuingBank];
}

final class SecureDocumentSummary extends VaultEntrySummary {
  const SecureDocumentSummary({
    required this.nickname,
    required this.category,
    this.linkedAccountNickname,
    required this.hasAttachment,
  });

  final String nickname;
  final DocumentCategory category;
  final String? linkedAccountNickname;
  final bool hasAttachment;

  @override
  List<Object?> get props =>
      [nickname, category, linkedAccountNickname, hasAttachment];
}
```

Add to `packages/platform_coin_vault/lib/platform_coin_vault.dart` after the entity exports:

```dart
export 'src/domain/entities/vault_entry_summary.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/platform_coin_vault && flutter test test/domain/entities/vault_entry_summary_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add packages/platform_coin_vault
git commit -m "feat(platform_coin_vault): add VaultEntrySummary list projections [skip ci]"
```

---

### Task 2: BankAccountRepository — listAllSummaries, update, deleteByNickname

**Files:**
- Modify: `packages/platform_coin_vault/lib/src/data/bank_account_repository.dart`
- Test: `packages/platform_coin_vault/test/data/bank_account_crud_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:math';

import 'package:core_domain/core_domain.dart';
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

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    repository = BankAccountRepository(
      database: vaultDb,
      fieldCipher: FieldCipher(),
    );
    keyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  });

  tearDown(() => vaultDb.close());

  BankAccountRecord record(String nickname, {String accountNumber = '1234567890'}) =>
      BankAccountRecord(
        id: null,
        nickname: nickname,
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: accountNumber,
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );

  group('listAllSummaries', () {
    test('returns an empty list when the vault has no accounts', () async {
      final result = await repository.listAllSummaries();
      expect(result.isSuccess, isTrue);
      expect(result.value, isEmpty);
    });

    test('lists summaries ordered by nickname without needing keyBytes', () async {
      await repository.create(record('Zeta'), keyBytes);
      await repository.create(record('Alpha'), keyBytes);

      final result = await repository.listAllSummaries();

      expect(result.isSuccess, isTrue);
      expect(result.value.map((s) => s.nickname), ['Alpha', 'Zeta']);
      expect(result.value.first.bankName, 'HDFC Bank');
      expect(result.value.first.ifscCode, 'HDFC0001234');
    });
  });

  group('update', () {
    test('re-encrypts and persists changed fields', () async {
      await repository.create(record('HDFC Salary'), keyBytes);

      final updated = BankAccountRecord(
        id: null,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '9998887776',
        ifscCode: 'HDFC0001234',
        accountType: 'current',
        notes: 'updated note',
      );
      final updateResult = await repository.update(updated, keyBytes);

      expect(updateResult.isSuccess, isTrue);
      final fetched = await repository.getByNickname('HDFC Salary', keyBytes);
      expect(fetched.value?.accountNumber, '9998887776');
      expect(fetched.value?.accountType, 'current');
      expect(fetched.value?.notes, 'updated note');
    });

    test('fails with NotFoundFailure for an unknown nickname', () async {
      final result = await repository.update(record('Ghost'), keyBytes);

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NotFoundFailure>());
    });
  });

  group('deleteByNickname', () {
    test('removes the record', () async {
      await repository.create(record('HDFC Salary'), keyBytes);

      final deleteResult = await repository.deleteByNickname('HDFC Salary');

      expect(deleteResult.isSuccess, isTrue);
      final fetched = await repository.getByNickname('HDFC Salary', keyBytes);
      expect(fetched.value, isNull);
    });

    test('fails with NotFoundFailure for an unknown nickname', () async {
      final result = await repository.deleteByNickname('Ghost');

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NotFoundFailure>());
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/data/bank_account_crud_test.dart`
Expected: FAIL — `listAllSummaries`/`update`/`deleteByNickname` undefined.

- [ ] **Step 3: Implement** — append to `BankAccountRepository` (imports: add `../domain/entities/vault_entry_summary.dart`):

```dart
  /// Lists all accounts as key-free summaries (unencrypted columns only).
  Future<Result<List<BankAccountSummary>>> listAllSummaries() async {
    try {
      final rows = await _database.db.query(
        VaultTables.bankAccounts,
        columns: const [
          'nickname',
          'bank_name',
          'account_holder_name',
          'ifsc_code',
          'account_type',
        ],
        orderBy: 'nickname ASC',
      );
      return Success([
        for (final row in rows)
          BankAccountSummary(
            nickname: row['nickname'] as String,
            bankName: row['bank_name'] as String,
            accountHolderName: row['account_holder_name'] as String,
            ifscCode: row['ifsc_code'] as String,
            accountType: row['account_type'] as String,
          ),
      ]);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to list bank accounts', cause: e),
      );
    }
  }

  /// Re-encrypts sensitive fields and updates the row identified by
  /// [BankAccountRecord.nickname]. `created_at` is left untouched.
  Future<Result<void>> update(
    BankAccountRecord record,
    List<int> keyBytes,
  ) async {
    try {
      final accountNumberEnc = await _fieldCipher.encryptField(
        record.accountNumber,
        keyBytes,
      );
      final notesEnc = record.notes == null
          ? null
          : await _fieldCipher.encryptField(record.notes!, keyBytes);

      final count = await _database.db.update(
        VaultTables.bankAccounts,
        {
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
        },
        where: 'nickname = ?',
        whereArgs: [record.nickname],
      );
      if (count == 0) {
        return Failure(NotFoundFailure(
          message: 'No bank account with nickname "${record.nickname}"',
          resourceType: 'BankAccountRecord',
          resourceId: record.nickname,
        ));
      }
      return const Success(null);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to update bank account', cause: e),
      );
    }
  }

  Future<Result<void>> deleteByNickname(String nickname) async {
    try {
      final count = await _database.db.delete(
        VaultTables.bankAccounts,
        where: 'nickname = ?',
        whereArgs: [nickname],
      );
      if (count == 0) {
        return Failure(NotFoundFailure(
          message: 'No bank account with nickname "$nickname"',
          resourceType: 'BankAccountRecord',
          resourceId: nickname,
        ));
      }
      return const Success(null);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to delete bank account', cause: e),
      );
    }
  }
```

- [ ] **Step 4: Run tests**

Run: `cd packages/platform_coin_vault && flutter test test/data/bank_account_crud_test.dart test/data/bank_account_repository_test.dart`
Expected: PASS (new 6 + existing 4)

- [ ] **Step 5: Commit**

```bash
git add packages/platform_coin_vault
git commit -m "feat(platform_coin_vault): bank account list/update/delete [skip ci]"
```

---

### Task 3: PanCardRepository — listAllSummaries, update (by id), deleteById

**Files:**
- Modify: `packages/platform_coin_vault/lib/src/data/pan_card_repository.dart`
- Test: `packages/platform_coin_vault/test/data/pan_card_crud_test.dart`

Note: PAN rows are keyed by row `id` (no nickname column). `update` requires a non-null `record.id` and never touches `card_image_blob_enc`.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:math';

import 'package:core_domain/core_domain.dart';
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

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    repository = PanCardRepository(
      database: vaultDb,
      fieldCipher: FieldCipher(),
    );
    keyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  });

  tearDown(() => vaultDb.close());

  PanCardRecord record({int? id, String pan = 'ABCDE1234F', String name = 'JANE DOE'}) =>
      PanCardRecord(id: id, panNumber: pan, nameOnCard: name);

  group('listAllSummaries', () {
    test('returns summaries with row ids, no keyBytes needed', () async {
      await repository.create(record(name: 'ZULU KHAN'), keyBytes);
      await repository.create(record(name: 'AMIT SHAH', pan: 'FGHIJ5678K'), keyBytes);

      final result = await repository.listAllSummaries();

      expect(result.isSuccess, isTrue);
      expect(result.value.map((s) => s.nameOnCard), ['AMIT SHAH', 'ZULU KHAN']);
      expect(result.value.every((s) => s.id > 0), isTrue);
    });
  });

  group('update', () {
    test('re-encrypts PAN and updates plain fields by id', () async {
      final created = await repository.create(record(), keyBytes);
      final id = created.value;

      final updateResult = await repository.update(
        record(id: id, pan: 'PQRST9876U', name: 'JANE M DOE'),
        keyBytes,
      );

      expect(updateResult.isSuccess, isTrue);
      final fetched = await repository.getById(id, keyBytes);
      expect(fetched.value?.panNumber, 'PQRST9876U');
      expect(fetched.value?.nameOnCard, 'JANE M DOE');
    });

    test('fails with ValidationFailure when record id is null', () async {
      final result = await repository.update(record(), keyBytes);

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ValidationFailure>());
    });

    test('preserves the card image blob on update', () async {
      final withImage = PanCardRecord(
        id: null,
        panNumber: 'ABCDE1234F',
        nameOnCard: 'JANE DOE',
        cardImageBlob: List<int>.generate(16, (i) => i),
      );
      final id = (await repository.create(withImage, keyBytes)).value;

      await repository.update(record(id: id), keyBytes);

      final fetched = await repository.getById(id, keyBytes);
      expect(fetched.value?.cardImageBlob, isNotNull);
    });
  });

  group('deleteById', () {
    test('removes the record', () async {
      final id = (await repository.create(record(), keyBytes)).value;

      final deleteResult = await repository.deleteById(id);

      expect(deleteResult.isSuccess, isTrue);
      expect((await repository.getById(id, keyBytes)).value, isNull);
    });

    test('fails with NotFoundFailure for an unknown id', () async {
      final result = await repository.deleteById(424242);

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NotFoundFailure>());
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/data/pan_card_crud_test.dart`
Expected: FAIL — methods undefined.

- [ ] **Step 3: Implement** — append to `PanCardRepository` (imports: add `../domain/entities/vault_entry_summary.dart`):

```dart
  /// Lists all PAN cards as key-free summaries (unencrypted columns only).
  Future<Result<List<PanCardSummary>>> listAllSummaries() async {
    try {
      final rows = await _database.db.query(
        VaultTables.panCards,
        columns: const ['id', 'name_on_card', 'fathers_name'],
        orderBy: 'name_on_card ASC',
      );
      return Success([
        for (final row in rows)
          PanCardSummary(
            id: row['id'] as int,
            nameOnCard: row['name_on_card'] as String,
            fathersName: row['fathers_name'] as String?,
          ),
      ]);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to list PAN cards', cause: e),
      );
    }
  }

  /// Updates the row identified by [PanCardRecord.id]. `card_image_blob_enc`
  /// and `created_at` are left untouched.
  Future<Result<void>> update(PanCardRecord record, List<int> keyBytes) async {
    final id = record.id;
    if (id == null) {
      return const Failure(ValidationFailure(
        message: 'A stored PAN card record must have an id to update',
        field: 'id',
      ));
    }
    try {
      final panNumberEnc = await _fieldCipher.encryptField(
        record.panNumber,
        keyBytes,
      );
      final count = await _database.db.update(
        VaultTables.panCards,
        {
          'pan_number_enc': panNumberEnc,
          'name_on_card': record.nameOnCard,
          'fathers_name': record.fathersName,
          'date_of_birth': record.dateOfBirth?.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) {
        return Failure(NotFoundFailure(
          message: 'No PAN card with id $id',
          resourceType: 'PanCardRecord',
          resourceId: '$id',
        ));
      }
      return const Success(null);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to update PAN card', cause: e),
      );
    }
  }

  Future<Result<void>> deleteById(int id) async {
    try {
      final count = await _database.db.delete(
        VaultTables.panCards,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) {
        return Failure(NotFoundFailure(
          message: 'No PAN card with id $id',
          resourceType: 'PanCardRecord',
          resourceId: '$id',
        ));
      }
      return const Success(null);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to delete PAN card', cause: e),
      );
    }
  }
```

- [ ] **Step 4: Run tests**

Run: `cd packages/platform_coin_vault && flutter test test/data/pan_card_crud_test.dart test/data/pan_card_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add packages/platform_coin_vault
git commit -m "feat(platform_coin_vault): PAN card list/update/delete keyed by row id [skip ci]"
```

---

### Task 4: CreditCardRepository — listAllSummaries, update, deleteByNickname (no keyBytes)

**Files:**
- Modify: `packages/platform_coin_vault/lib/src/data/credit_card_repository.dart`
- Test: `packages/platform_coin_vault/test/data/credit_card_crud_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/data/credit_card_repository.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:platform_coin_vault/src/domain/entities/credit_card_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VaultDatabase vaultDb;
  late CreditCardRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    repository = CreditCardRepository(database: vaultDb);
  });

  tearDown(() => vaultDb.close());

  CreditCardRecord record(String nickname, {String last4 = '4321'}) =>
      CreditCardRecord(
        id: null,
        nickname: nickname,
        cardNetwork: CardNetwork.visa,
        last4: last4,
        expiryMonth: 8,
        expiryYear: 2029,
        issuingBank: 'ICICI Bank',
        createdAt: DateTime(2026, 7, 20),
      );

  group('listAllSummaries', () {
    test('lists masked-only summaries ordered by nickname', () async {
      await repository.create(record('Zeta Card'));
      await repository.create(record('Alpha Card', last4: '1111'));

      final result = await repository.listAllSummaries();

      expect(result.isSuccess, isTrue);
      expect(result.value.map((s) => s.nickname), ['Alpha Card', 'Zeta Card']);
      expect(result.value.first.last4, '1111');
      expect(result.value.first.cardNetwork, CardNetwork.visa);
    });
  });

  group('update', () {
    test('persists changed masked fields', () async {
      await repository.create(record('Main Card'));

      final updateResult = await repository.update(
        CreditCardRecord(
          id: null,
          nickname: 'Main Card',
          cardNetwork: CardNetwork.rupay,
          last4: '9876',
          expiryMonth: 1,
          expiryYear: 2030,
          issuingBank: 'SBI',
          createdAt: DateTime(2026, 7, 20),
        ),
      );

      expect(updateResult.isSuccess, isTrue);
      final fetched = await repository.getByNickname('Main Card');
      expect(fetched.value?.last4, '9876');
      expect(fetched.value?.cardNetwork, CardNetwork.rupay);
      expect(fetched.value?.issuingBank, 'SBI');
    });

    test('fails with NotFoundFailure for an unknown nickname', () async {
      final result = await repository.update(record('Ghost'));

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NotFoundFailure>());
    });
  });

  group('deleteByNickname', () {
    test('removes the record; unknown nickname fails', () async {
      await repository.create(record('Main Card'));

      expect((await repository.deleteByNickname('Main Card')).isSuccess, isTrue);
      expect((await repository.getByNickname('Main Card')).value, isNull);

      final missing = await repository.deleteByNickname('Main Card');
      expect(missing.isFailure, isTrue);
      expect(missing.failure, isA<NotFoundFailure>());
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/data/credit_card_crud_test.dart`
Expected: FAIL — methods undefined.

- [ ] **Step 3: Implement** — append to `CreditCardRepository` (imports: add `../domain/entities/vault_entry_summary.dart`):

```dart
  /// Lists all cards as masked-only summaries (nothing here is encrypted).
  Future<Result<List<CreditCardSummary>>> listAllSummaries() async {
    try {
      final rows = await _database.db.query(
        VaultTables.creditCards,
        orderBy: 'nickname ASC',
      );
      return Success([
        for (final row in rows)
          CreditCardSummary(
            nickname: row['nickname'] as String,
            cardNetwork: CardNetwork.values.byName(row['card_network'] as String),
            last4: row['last4'] as String,
            expiryMonth: row['expiry_month'] as int,
            expiryYear: row['expiry_year'] as int,
            issuingBank: row['issuing_bank'] as String,
          ),
      ]);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to list credit cards', cause: e),
      );
    }
  }

  /// Updates the row identified by [CreditCardRecord.nickname].
  /// `created_at` is left untouched.
  Future<Result<void>> update(CreditCardRecord record) async {
    try {
      final count = await _database.db.update(
        VaultTables.creditCards,
        {
          'card_network': record.cardNetwork.name,
          'last4': record.last4,
          'expiry_month': record.expiryMonth,
          'expiry_year': record.expiryYear,
          'issuing_bank': record.issuingBank,
        },
        where: 'nickname = ?',
        whereArgs: [record.nickname],
      );
      if (count == 0) {
        return Failure(NotFoundFailure(
          message: 'No credit card with nickname "${record.nickname}"',
          resourceType: 'CreditCardRecord',
          resourceId: record.nickname,
        ));
      }
      return const Success(null);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to update credit card', cause: e),
      );
    }
  }

  Future<Result<void>> deleteByNickname(String nickname) async {
    try {
      final count = await _database.db.delete(
        VaultTables.creditCards,
        where: 'nickname = ?',
        whereArgs: [nickname],
      );
      if (count == 0) {
        return Failure(NotFoundFailure(
          message: 'No credit card with nickname "$nickname"',
          resourceType: 'CreditCardRecord',
          resourceId: nickname,
        ));
      }
      return const Success(null);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to delete credit card', cause: e),
      );
    }
  }
```

- [ ] **Step 4: Run tests**

Run: `cd packages/platform_coin_vault && flutter test test/data/credit_card_crud_test.dart test/data/credit_card_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add packages/platform_coin_vault
git commit -m "feat(platform_coin_vault): credit card list/update/delete [skip ci]"
```

---

### Task 5: SecureDocumentRepository — listAllSummaries, update, deleteByNickname

**Files:**
- Modify: `packages/platform_coin_vault/lib/src/data/secure_document_repository.dart`
- Test: `packages/platform_coin_vault/test/data/secure_document_crud_test.dart`

Note: `update` touches `category`, `linked_account_nickname`, `custom_fields_enc`, `notes_enc` — it never touches `attachment_blob_enc` (attachments are deferred; an edit must not wipe one).

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:math';

import 'package:core_domain/core_domain.dart';
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

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    repository = SecureDocumentRepository(
      database: vaultDb,
      fieldCipher: FieldCipher(),
    );
    keyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  });

  tearDown(() => vaultDb.close());

  SecureDocumentRecord record(
    String nickname, {
    DocumentCategory category = DocumentCategory.incomeProof,
    String? linked,
    Map<String, String> customFields = const {'employer': 'Acme'},
    String? notes,
    List<int>? attachment,
  }) =>
      SecureDocumentRecord(
        id: null,
        nickname: nickname,
        category: category,
        createdAt: DateTime(2026, 7, 20),
        linkedAccountNickname: linked,
        customFields: customFields,
        attachmentBlob: attachment,
        notes: notes,
      );

  group('listAllSummaries', () {
    test('lists summaries with hasAttachment flag, no keyBytes needed', () async {
      await repository.create(record('Form 16', attachment: [1, 2, 3]), keyBytes);
      await repository.create(record('26AS', customFields: const {}), keyBytes);

      final result = await repository.listAllSummaries();

      expect(result.isSuccess, isTrue);
      expect(result.value.map((s) => s.nickname), ['26AS', 'Form 16']);
      expect(result.value[0].hasAttachment, isFalse);
      expect(result.value[1].hasAttachment, isTrue);
      expect(result.value[1].category, DocumentCategory.incomeProof);
    });
  });

  group('update', () {
    test('re-encrypts custom fields and notes, updates plain fields', () async {
      await repository.create(record('Form 16'), keyBytes);

      final updateResult = await repository.update(
        record(
          'Form 16',
          category: DocumentCategory.taxCredit,
          linked: 'HDFC Salary',
          customFields: const {'employer': 'NewCorp', 'fy': '2025-26'},
          notes: 'verified',
        ),
        keyBytes,
      );

      expect(updateResult.isSuccess, isTrue);
      final fetched = await repository.getByNickname('Form 16', keyBytes);
      expect(fetched.value?.category, DocumentCategory.taxCredit);
      expect(fetched.value?.linkedAccountNickname, 'HDFC Salary');
      expect(fetched.value?.customFields, {'employer': 'NewCorp', 'fy': '2025-26'});
      expect(fetched.value?.notes, 'verified');
    });

    test('preserves the attachment blob on update', () async {
      await repository.create(record('Form 16', attachment: [9, 8, 7]), keyBytes);

      await repository.update(record('Form 16', notes: 'n'), keyBytes);

      final fetched = await repository.getByNickname('Form 16', keyBytes);
      expect(fetched.value?.attachmentBlob, [9, 8, 7]);
    });

    test('fails with NotFoundFailure for an unknown nickname', () async {
      final result = await repository.update(record('Ghost'), keyBytes);

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NotFoundFailure>());
    });
  });

  group('deleteByNickname', () {
    test('removes the record; unknown nickname fails', () async {
      await repository.create(record('Form 16'), keyBytes);

      expect((await repository.deleteByNickname('Form 16')).isSuccess, isTrue);
      expect((await repository.getByNickname('Form 16', keyBytes)).value, isNull);

      final missing = await repository.deleteByNickname('Form 16');
      expect(missing.isFailure, isTrue);
      expect(missing.failure, isA<NotFoundFailure>());
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_coin_vault && flutter test test/data/secure_document_crud_test.dart`
Expected: FAIL — methods undefined.

- [ ] **Step 3: Implement** — append to `SecureDocumentRepository` (imports: add `../domain/entities/vault_entry_summary.dart`):

```dart
  /// Lists all documents as key-free summaries (unencrypted columns only).
  Future<Result<List<SecureDocumentSummary>>> listAllSummaries() async {
    try {
      final rows = await _database.db.query(
        VaultTables.secureDocuments,
        columns: const [
          'nickname',
          'category',
          'linked_account_nickname',
          'attachment_blob_enc',
        ],
        orderBy: 'nickname ASC',
      );
      return Success([
        for (final row in rows)
          SecureDocumentSummary(
            nickname: row['nickname'] as String,
            category:
                DocumentCategory.values.byName(row['category'] as String),
            linkedAccountNickname: row['linked_account_nickname'] as String?,
            hasAttachment: row['attachment_blob_enc'] != null,
          ),
      ]);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to list secure documents', cause: e),
      );
    }
  }

  /// Updates the row identified by [SecureDocumentRecord.nickname].
  /// `attachment_blob_enc` and `created_at` are left untouched — an edit
  /// must never wipe a stored attachment.
  Future<Result<void>> update(
    SecureDocumentRecord record,
    List<int> keyBytes,
  ) async {
    try {
      final customFieldsEnc = record.customFields.isEmpty
          ? null
          : await _fieldCipher.encryptField(
              jsonEncode(record.customFields),
              keyBytes,
            );
      final notesEnc = record.notes == null
          ? null
          : await _fieldCipher.encryptField(record.notes!, keyBytes);

      final count = await _database.db.update(
        VaultTables.secureDocuments,
        {
          'category': record.category.name,
          'linked_account_nickname': record.linkedAccountNickname,
          'custom_fields_enc': customFieldsEnc,
          'notes_enc': notesEnc,
        },
        where: 'nickname = ?',
        whereArgs: [record.nickname],
      );
      if (count == 0) {
        return Failure(NotFoundFailure(
          message: 'No document with nickname "${record.nickname}"',
          resourceType: 'SecureDocumentRecord',
          resourceId: record.nickname,
        ));
      }
      return const Success(null);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to update secure document', cause: e),
      );
    }
  }

  Future<Result<void>> deleteByNickname(String nickname) async {
    try {
      final count = await _database.db.delete(
        VaultTables.secureDocuments,
        where: 'nickname = ?',
        whereArgs: [nickname],
      );
      if (count == 0) {
        return Failure(NotFoundFailure(
          message: 'No document with nickname "$nickname"',
          resourceType: 'SecureDocumentRecord',
          resourceId: nickname,
        ));
      }
      return const Success(null);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to delete secure document', cause: e),
      );
    }
  }
```

- [ ] **Step 4: Run the full package suite + analyze**

Run: `cd packages/platform_coin_vault && flutter test && dart analyze`
Expected: all tests PASS (50 existing + new), no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add packages/platform_coin_vault
git commit -m "feat(platform_coin_vault): secure document list/update/delete [skip ci]"
```

- [ ] **Step 6: Open PR 1**

```bash
git push -u origin feature/feature-coin
gh pr create --title "feat(platform_coin_vault): vault list/update/delete + summary projections" --body "Slice 1 of #<issue>. Adds no-key VaultEntrySummary projections and update/delete to all four repos. Schema v1 unchanged. Local: flutter test (all pass), dart analyze clean."
```

(Slices 2–4 stack on this branch; if PR 1 is not merged when they are ready, push each as its own branch off the previous tip — see AGENTS.md integration-branch rule.)

---

## SLICE 2 — rename airomoney → feature_coin + session core (PR 2)

### Task 6: Rename and gut the package

**Files:**
- Rename: `packages/airomoney/` → `packages/feature_coin/`
- Rewrite: `packages/feature_coin/pubspec.yaml`, `packages/feature_coin/lib/feature_coin.dart`, `packages/feature_coin/module.yaml`, `packages/feature_coin/README.md`

- [ ] **Step 1: Rename with history, delete mock internals**

```bash
git mv packages/airomoney packages/feature_coin
git rm -q packages/feature_coin/airomoney.iml
git rm -rq packages/feature_coin/lib/src packages/feature_coin/test
git mv packages/feature_coin/lib/airomoney.dart packages/feature_coin/lib/feature_coin.dart
```

- [ ] **Step 2: Rewrite `packages/feature_coin/pubspec.yaml`**

```yaml
name: feature_coin
description: "Airo Coin vault presentation layer — biometric-gated secure record vault (bank accounts, PAN, cards, documents)."
version: 0.0.1
publish_to: none

environment:
  sdk: ">=3.12.2 <4.0.0"
  flutter: ">=3.44.4"

dependencies:
  flutter:
    sdk: flutter
  core_domain:
    path: ../core_domain
  core_ui:
    path: ../core_ui
  platform_coin_vault:
    path: ../platform_coin_vault
  equatable: ^2.0.8
  flutter_riverpod: 3.3.2
  go_router: ^17.3.0
  local_auth: ^2.3.0
  path: 1.9.1
  path_provider: ^2.1.6
  screen_protector: ^1.4.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: 6.0.0
  mocktail: ^1.0.5
  sqflite_common_ffi: ^2.3.6

flutter:
  uses-material-design: true
```

- [ ] **Step 3: Rewrite `packages/feature_coin/module.yaml`**

```yaml
name: feature_coin
owner: Coins / Finance Agent
reviewers:
  - Chief Architect
  - Chief Security Officer
  - Chief QA Officer
allowed_dependencies:
  - core_domain
  - core_ui
  - platform_coin_vault
forbidden_dependencies:
  - app
quality_gates: {}
```

- [ ] **Step 4: Rewrite `packages/feature_coin/lib/feature_coin.dart`** (barrel — exports are added per later task)

```dart
/// Airo Coin vault presentation layer — biometric-gated secure record vault.
///
/// Built on `platform_coin_vault` (crypto/storage). Design spec:
/// docs/superpowers/specs/2026-07-20-feature-coin-design.md
library;
```

- [ ] **Step 5: Rewrite `packages/feature_coin/README.md`**

```markdown
# feature_coin

Airo Coin vault presentation layer: biometric-gated lock screen, masked
list/detail UI, and add/edit forms for bank accounts, PAN cards, credit
cards (masked-only), and ITR-categorized secure documents.

Crypto/storage lives in `platform_coin_vault`. This package owns the DEK
session (auto-lock), clipboard auto-clear, and screen security.
```

- [ ] **Step 6: Validate the renamed package resolves**

Run: `cd packages/feature_coin && flutter pub get && dart analyze`
Expected: pub get resolves; analyze reports no issues (barrel-only package).

Note: do NOT run `flutter pub get` in `app/` yet — it still references
`packages/airomoney` until Task 16.

- [ ] **Step 7: Commit**

```bash
git add packages/feature_coin
git commit -m "refactor: rename airomoney to feature_coin, gut mock wallet UI [skip ci]"
```

---

### Task 7: VaultConfig + infrastructure providers

**Files:**
- Create: `packages/feature_coin/lib/src/application/vault_config.dart`
- Create: `packages/feature_coin/lib/src/application/vault_providers.dart`
- Modify: `packages/feature_coin/lib/feature_coin.dart`

- [ ] **Step 1: Create `vault_config.dart`**

```dart
/// Timing and storage constants for the Airo Coin vault. Centralized so a
/// future settings screen can make them configurable without hunting
/// through the session/clipboard code.
abstract final class VaultConfig {
  /// Idle time after which the vault auto-locks and the DEK is zeroed.
  static const autoLockDuration = Duration(seconds: 60);

  /// Delay before a copied value is auto-cleared from the clipboard.
  static const clipboardClearDuration = Duration(seconds: 30);

  /// sqflite file name inside the app documents directory.
  static const databaseFileName = 'airo_coin_vault.db';
}
```

- [ ] **Step 2: Create `vault_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import 'vault_config.dart';

/// Opens (and on dispose, closes) the vault sqflite database. Tests override
/// this with an in-memory `sqflite_common_ffi` database.
final vaultDatabaseProvider = FutureProvider<VaultDatabase>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  final database = VaultDatabase();
  await database.open(path: p.join(dir.path, VaultConfig.databaseFileName));
  ref.onDispose(database.close);
  return database;
});

/// Aggregate handle for the four vault repositories.
final class VaultRepositories {
  const VaultRepositories({
    required this.bankAccounts,
    required this.panCards,
    required this.creditCards,
    required this.secureDocuments,
  });

  final BankAccountRepository bankAccounts;
  final PanCardRepository panCards;
  final CreditCardRepository creditCards;
  final SecureDocumentRepository secureDocuments;
}

final vaultRepositoriesProvider = FutureProvider<VaultRepositories>((ref) async {
  final database = await ref.watch(vaultDatabaseProvider.future);
  final cipher = FieldCipher();
  return VaultRepositories(
    bankAccounts: BankAccountRepository(database: database, fieldCipher: cipher),
    panCards: PanCardRepository(database: database, fieldCipher: cipher),
    creditCards: CreditCardRepository(database: database),
    secureDocuments: SecureDocumentRepository(database: database, fieldCipher: cipher),
  );
});

/// Biometric-gated DEK manager. Tests override with
/// `VaultKeyManager.forTesting`.
final vaultKeyManagerProvider = Provider<VaultKeyManager>((ref) {
  return VaultKeyManager(
    localAuth: LocalAuthentication(),
    secureStorage: VaultSecureStorage(),
  );
});

/// Raw `local_auth` handle for destructive-action re-prompts (delete).
final localAuthenticationProvider =
    Provider<LocalAuthentication>((ref) => LocalAuthentication());
```

- [ ] **Step 3: Add exports to the barrel**

Append to `lib/feature_coin.dart`:

```dart
export 'src/application/vault_config.dart';
export 'src/application/vault_providers.dart';
```

- [ ] **Step 4: Validate**

Run: `cd packages/feature_coin && flutter pub get && dart analyze`
Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_coin
git commit -m "feat(feature_coin): vault config + infrastructure providers [skip ci]"
```

---

### Task 8: VaultSession — DEK lifecycle notifier

**Files:**
- Create: `packages/feature_coin/lib/src/application/vault_session.dart`
- Modify: `packages/feature_coin/lib/feature_coin.dart`
- Test: `packages/feature_coin/test/application/vault_session_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:core_domain/core_domain.dart';
import 'package:fake_async/fake_async.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

class InMemoryVaultKeyStore implements VaultKeyStore {
  final Map<String, String> _values = {};

  @override
  Future<Result<String?>> read(String key) async => Success(_values[key]);
  @override
  Future<Result<void>> write(String key, String value) async {
    _values[key] = value;
    return const Success(null);
  }

  @override
  Future<Result<void>> delete(String key) async {
    _values.remove(key);
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteAll() async {
    _values.clear();
    return const Success(null);
  }

  @override
  Future<Result<bool>> containsKey(String key) async =>
      Success(_values.containsKey(key));
  @override
  Future<Result<List<String>>> getAllKeys() async =>
      Success(_values.keys.toList());
}

void main() {
  VaultKeyManager keyManager({
    bool authenticate = true,
    bool available = true,
  }) =>
      VaultKeyManager.forTesting(
        secureStorage: InMemoryVaultKeyStore(),
        authenticate: () async => authenticate,
        isAvailable: () async => available,
      );

  ProviderContainer containerFor(VaultKeyManager km) {
    final container = ProviderContainer(overrides: [
      vaultKeyManagerProvider.overrideWithValue(km),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  group('VaultSessionNotifier', () {
    test('starts locked', () {
      final container = containerFor(keyManager());
      expect(container.read(vaultSessionProvider), isA<VaultLocked>());
    });

    test('unlock success transitions to unlocked', () async {
      final container = containerFor(keyManager());

      await container.read(vaultSessionProvider.notifier).unlock();

      expect(container.read(vaultSessionProvider), isA<VaultUnlocked>());
    });

    test('unlock with no biometrics enrolled transitions to unavailable '
        'and never prompts', () async {
      var prompted = false;
      final km = VaultKeyManager.forTesting(
        secureStorage: InMemoryVaultKeyStore(),
        authenticate: () async {
          prompted = true;
          return true;
        },
        isAvailable: () async => false,
      );
      final container = containerFor(km);

      await container.read(vaultSessionProvider.notifier).unlock();

      expect(container.read(vaultSessionProvider), isA<VaultUnavailable>());
      expect(prompted, isFalse);
    });

    test('failed biometric prompt transitions to authError', () async {
      final container = containerFor(keyManager(authenticate: false));

      await container.read(vaultSessionProvider.notifier).unlock();

      final state = container.read(vaultSessionProvider);
      expect(state, isA<VaultAuthError>());
      expect((state as VaultAuthError).failure, isA<AuthFailure>());
    });

    test('withKey runs the operation while unlocked and null when locked',
        () async {
      final container = containerFor(keyManager());
      final notifier = container.read(vaultSessionProvider.notifier);

      expect(await notifier.withKey((key) async => key.length), isNull);

      await notifier.unlock();
      expect(await notifier.withKey((key) async => key.length), 32);

      notifier.lock();
      expect(await notifier.withKey((key) async => key.length), isNull);
    });

    test('lock zeroes the DEK bytes in place', () async {
      final container = containerFor(keyManager());
      final notifier = container.read(vaultSessionProvider.notifier);
      await notifier.unlock();

      List<int>? captured;
      await notifier.withKey((key) async => captured = key);
      expect(captured!.any((b) => b != 0), isTrue);

      notifier.lock();

      expect(captured!.every((b) => b == 0), isTrue);
      expect(container.read(vaultSessionProvider), isA<VaultLocked>());
    });

    test('auto-locks after the idle timeout', () {
      fakeAsync((async) {
        final container = containerFor(keyManager());
        final notifier = container.read(vaultSessionProvider.notifier);

        notifier.unlock();
        async.flushMicrotasks();
        expect(container.read(vaultSessionProvider), isA<VaultUnlocked>());

        async.elapse(VaultConfig.autoLockDuration);

        expect(container.read(vaultSessionProvider), isA<VaultLocked>());
      });
    });

    test('withKey interaction resets the idle timer', () {
      fakeAsync((async) {
        final container = containerFor(keyManager());
        final notifier = container.read(vaultSessionProvider.notifier);

        notifier.unlock();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 45));
        notifier.withKey((key) async => 1);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 45));
        expect(container.read(vaultSessionProvider), isA<VaultUnlocked>());

        async.elapse(VaultConfig.autoLockDuration);
        expect(container.read(vaultSessionProvider), isA<VaultLocked>());
      });
    });

    test('onAppBackground locks an unlocked session', () async {
      final container = containerFor(keyManager());
      final notifier = container.read(vaultSessionProvider.notifier);
      await notifier.unlock();

      notifier.onAppBackground();

      expect(container.read(vaultSessionProvider), isA<VaultLocked>());
    });

    test('dispose zeroes the DEK', () {
      fakeAsync((async) {
        final km = keyManager();
        List<int>? captured;
        final container = ProviderContainer(overrides: [
          vaultKeyManagerProvider.overrideWithValue(km),
        ]);
        final notifier = container.read(vaultSessionProvider.notifier);
        notifier.unlock();
        async.flushMicrotasks();
        notifier.withKey((key) async => captured = key);
        async.flushMicrotasks();

        container.dispose();

        expect(captured!.every((b) => b == 0), isTrue);
      });
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_coin && flutter test test/application/vault_session_test.dart`
Expected: FAIL — `vault_session.dart` does not exist.

- [ ] **Step 3: Implement `vault_session.dart`**

```dart
import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import 'vault_config.dart';
import 'vault_providers.dart';

/// Lifecycle state of the vault session.
sealed class VaultSessionState {
  const VaultSessionState();
}

final class VaultLocked extends VaultSessionState {
  const VaultLocked();
}

final class VaultUnlocking extends VaultSessionState {
  const VaultUnlocking();
}

final class VaultUnlocked extends VaultSessionState {
  const VaultUnlocked();
}

/// Device cannot do biometric/device-credential auth — vault creation must
/// not be offered (ADR 0009 fail-closed contract).
final class VaultUnavailable extends VaultSessionState {
  const VaultUnavailable();
}

final class VaultAuthError extends VaultSessionState {
  const VaultAuthError(this.failure);

  final BaseFailure failure;
}

/// Owns the vault DEK for the duration of an unlocked session.
///
/// The DEK is held privately and never exposed through state — consumers run
/// sensitive operations through [withKey]. The DEK is zeroed in place on
/// lock, idle timeout, app background, or disposal. Key rotation is
/// deliberately not exposed here (`VaultKeyManager.rotateKey` is destructive
/// until a re-encryption migration exists).
class VaultSessionNotifier extends Notifier<VaultSessionState> {
  Timer? _idleTimer;
  List<int>? _dek;

  @override
  VaultSessionState build() {
    ref.onDispose(() {
      _idleTimer?.cancel();
      _zeroDek();
    });
    return const VaultLocked();
  }

  /// Prompts for biometrics (with OS device-credential fallback) and, on
  /// success, caches the DEK. Fail-closed: devices without biometric
  /// capability get [VaultUnavailable]; auth errors get [VaultAuthError].
  Future<void> unlock() async {
    if (state is VaultUnlocking || state is VaultUnlocked) return;

    final keyManager = ref.read(vaultKeyManagerProvider);
    if (!await keyManager.isEncryptionAvailable()) {
      state = const VaultUnavailable();
      return;
    }

    state = const VaultUnlocking();
    final result = await keyManager.getDatabaseKey();
    switch (result) {
      case Success<List<int>>(:final value):
        _dek = value;
        state = const VaultUnlocked();
        _resetIdleTimer();
      case Failure<List<int>>(:final failure):
        state = VaultAuthError(failure);
    }
  }

  /// Runs [operation] with the DEK if unlocked; returns null otherwise.
  /// Counts as user activity and resets the idle timer.
  Future<T?> withKey<T>(Future<T> Function(List<int> keyBytes) operation) async {
    final dek = _dek;
    if (dek == null || state is! VaultUnlocked) return null;
    _resetIdleTimer();
    return operation(dek);
  }

  /// Immediately locks the vault and zeroes the DEK.
  void lock() {
    _idleTimer?.cancel();
    _zeroDek();
    state = const VaultLocked();
  }

  /// Called by the lifecycle observer when the app goes to background.
  void onAppBackground() {
    if (state is VaultUnlocked) lock();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(VaultConfig.autoLockDuration, lock);
  }

  void _zeroDek() {
    final dek = _dek;
    if (dek != null) {
      for (var i = 0; i < dek.length; i++) {
        dek[i] = 0;
      }
    }
    _dek = null;
  }
}

final vaultSessionProvider =
    NotifierProvider<VaultSessionNotifier, VaultSessionState>(
  VaultSessionNotifier.new,
);
```

- [ ] **Step 4: Add exports to the barrel**

Append to `lib/feature_coin.dart`:

```dart
export 'src/application/vault_session.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/feature_coin && flutter test test/application/vault_session_test.dart`
Expected: PASS (10 tests)

- [ ] **Step 6: Commit**

```bash
git add packages/feature_coin
git commit -m "feat(feature_coin): VaultSession DEK lifecycle with auto-lock [skip ci]"
```

---

### Task 9: VaultLifecycleObserver — background → lock

**Files:**
- Create: `packages/feature_coin/lib/src/presentation/widgets/vault_lifecycle_observer.dart`
- Modify: `packages/feature_coin/lib/feature_coin.dart`
- Test: `packages/feature_coin/test/presentation/widgets/vault_lifecycle_observer_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import '../../application/vault_session_test.dart'
    show InMemoryVaultKeyStore;

void main() {
  testWidgets('going to background locks an unlocked vault', (tester) async {
    final keyManager = VaultKeyManager.forTesting(
      secureStorage: InMemoryVaultKeyStore(),
      authenticate: () async => true,
      isAvailable: () async => true,
    );
    final container = ProviderContainer(overrides: [
      vaultKeyManagerProvider.overrideWithValue(keyManager),
    ]);
    addTearDown(container.dispose);
    await container.read(vaultSessionProvider.notifier).unlock();
    expect(container.read(vaultSessionProvider), isA<VaultUnlocked>());

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: VaultLifecycleObserver(child: Scaffold()),
      ),
    ));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(container.read(vaultSessionProvider), isA<VaultLocked>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_coin && flutter test test/presentation/widgets/vault_lifecycle_observer_test.dart`
Expected: FAIL — `VaultLifecycleObserver` undefined.

- [ ] **Step 3: Implement `vault_lifecycle_observer.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/vault_session.dart';

/// Locks the vault whenever the app goes to background while [child] (the
/// vault route subtree) is mounted. Mounted once by `VaultGateScreen`.
class VaultLifecycleObserver extends ConsumerStatefulWidget {
  const VaultLifecycleObserver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VaultLifecycleObserver> createState() =>
      _VaultLifecycleObserverState();
}

class _VaultLifecycleObserverState extends ConsumerState<VaultLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ref.read(vaultSessionProvider.notifier).onAppBackground();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
```

- [ ] **Step 4: Add exports to the barrel**

Append to `lib/feature_coin.dart`:

```dart
export 'src/presentation/widgets/vault_lifecycle_observer.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/feature_coin && flutter test test/presentation/widgets/vault_lifecycle_observer_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add packages/feature_coin
git commit -m "feat(feature_coin): lock vault on app background [skip ci]"
```

---

### Task 10: ClipboardService — copy with compare-and-clear

**Files:**
- Create: `packages/feature_coin/lib/src/application/clipboard_service.dart`
- Modify: `packages/feature_coin/lib/feature_coin.dart`
- Test: `packages/feature_coin/test/application/clipboard_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClipboardService', () {
    test('clears the clipboard after the timeout when content is unchanged',
        () {
      fakeAsync((async) {
        String? clipboard;
        final service = ClipboardService(
          setData: (data) async => clipboard = data.text,
          getData: () async => ClipboardData(text: clipboard),
        );

        service.copyWithAutoClear('secret-account-number');
        async.flushMicrotasks();
        expect(clipboard, 'secret-account-number');

        async.elapse(VaultConfig.clipboardClearDuration);
        async.flushMicrotasks();

        expect(clipboard, '');
      });
    });

    test('does not clear when the user copied something else meanwhile', () {
      fakeAsync((async) {
        String? clipboard;
        final service = ClipboardService(
          setData: (data) async => clipboard = data.text,
          getData: () async => ClipboardData(text: clipboard),
        );

        service.copyWithAutoClear('secret-account-number');
        async.flushMicrotasks();
        clipboard = 'user copied something else';

        async.elapse(VaultConfig.clipboardClearDuration);
        async.flushMicrotasks();

        expect(clipboard, 'user copied something else');
      });
    });

    test('a second copy cancels the first clear timer', () {
      fakeAsync((async) {
        String? clipboard;
        final service = ClipboardService(
          setData: (data) async => clipboard = data.text,
          getData: () async => ClipboardData(text: clipboard),
        );

        service.copyWithAutoClear('first');
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 20));
        service.copyWithAutoClear('second');
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 20));
        async.flushMicrotasks();
        expect(clipboard, 'second');

        async.elapse(VaultConfig.clipboardClearDuration);
        async.flushMicrotasks();
        expect(clipboard, '');
      });
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_coin && flutter test test/application/clipboard_service_test.dart`
Expected: FAIL — `clipboard_service.dart` does not exist.

- [ ] **Step 3: Implement `clipboard_service.dart`**

```dart
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vault_config.dart';

/// Clipboard access for vault secrets. Every copy schedules a
/// compare-and-clear: after [VaultConfig.clipboardClearDuration] the
/// clipboard is wiped only if it still holds the value we put there, so a
/// newer user copy is never destroyed.
class ClipboardService {
  ClipboardService({
    Future<void> Function(ClipboardData data)? setData,
    Future<ClipboardData?> Function()? getData,
  })  : _setData = setData ?? Clipboard.setData,
        _getData = getData ?? (() => Clipboard.getData(Clipboard.kTextPlain));

  final Future<void> Function(ClipboardData data) _setData;
  final Future<ClipboardData?> Function() _getData;
  Timer? _clearTimer;

  Future<void> copyWithAutoClear(String text, {Duration? clearAfter}) async {
    _clearTimer?.cancel();
    await _setData(ClipboardData(text: text));
    _clearTimer = Timer(
      clearAfter ?? VaultConfig.clipboardClearDuration,
      () => _clearIfUnchanged(text),
    );
  }

  Future<void> _clearIfUnchanged(String copiedText) async {
    final current = await _getData();
    if (current?.text == copiedText) {
      await _setData(const ClipboardData(text: ''));
    }
  }

  void dispose() => _clearTimer?.cancel();
}

final clipboardServiceProvider = Provider<ClipboardService>((ref) {
  final service = ClipboardService();
  ref.onDispose(service.dispose);
  return service;
});
```

- [ ] **Step 4: Add exports to the barrel**

Append to `lib/feature_coin.dart`:

```dart
export 'src/application/clipboard_service.dart';
```

- [ ] **Step 5: Run tests + analyze**

Run: `cd packages/feature_coin && flutter test && dart analyze`
Expected: all PASS, no issues.

- [ ] **Step 6: Commit + open PR 2**

```bash
git add packages/feature_coin
git commit -m "feat(feature_coin): clipboard copy-with-auto-clear [skip ci]"
git push
gh pr create --title "feat(feature_coin): rename airomoney + vault session core" --body "Slice 2 of #<issue>. git mv preserves history; mock wallet UI gutted. Adds VaultSession (DEK lifecycle, 60s auto-lock, background lock, DEK zeroing), lifecycle observer, clipboard compare-and-clear. Local: flutter test + dart analyze clean."
```

---

## SLICE 3 — vault UI (PR 3)

### Task 11: VaultRecordType + lock/unavailable/auth-error views

**Files:**
- Create: `packages/feature_coin/lib/src/domain/vault_record_type.dart`
- Create: `packages/feature_coin/lib/src/presentation/screens/vault_lock_screen.dart`
- Modify: `packages/feature_coin/lib/feature_coin.dart`
- Test: `packages/feature_coin/test/presentation/screens/vault_lock_screen_test.dart`

- [ ] **Step 1: Create `vault_record_type.dart`**

```dart
/// The four vault record kinds, in add-picker order. Enum names are used as
/// route path parameters (`/money/vault/add/<name>`), so do not rename
/// values without migrating routes.
enum VaultRecordType { bankAccount, panCard, creditCard, secureDocument }
```

- [ ] **Step 2: Write the failing widget test**

```dart
import 'package:core_domain/core_domain.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import '../../application/vault_session_test.dart' show InMemoryVaultKeyStore;

void main() {
  VaultKeyManager keyManager({bool authenticate = true, bool available = true}) =>
      VaultKeyManager.forTesting(
        secureStorage: InMemoryVaultKeyStore(),
        authenticate: () async => authenticate,
        isAvailable: () async => available,
      );

  Widget harness(Widget child, VaultKeyManager km) => ProviderScope(
        overrides: [vaultKeyManagerProvider.overrideWithValue(km)],
        child: MaterialApp(home: child),
      );

  testWidgets('lock screen offers a biometric unlock button', (tester) async {
    await tester.pumpWidget(harness(const VaultLockScreen(), keyManager()));

    expect(find.text('Vault locked'), findsOneWidget);
    expect(find.text('Unlock with biometrics'), findsOneWidget);

    await tester.tap(find.text('Unlock with biometrics'));
    await tester.pumpAndSettle();
  });

  testWidgets('failed unlock from the lock screen lands on auth error',
      (tester) async {
    final km = keyManager(authenticate: false);
    final container = ProviderContainer(overrides: [
      vaultKeyManagerProvider.overrideWithValue(km),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: VaultLockScreen()),
    ));
    await tester.tap(find.text('Unlock with biometrics'));
    await tester.pumpAndSettle();

    expect(container.read(vaultSessionProvider), isA<VaultAuthError>());
  });

  testWidgets('unavailable view explains biometrics are required',
      (tester) async {
    await tester.pumpWidget(
      harness(const VaultUnavailableView(), keyManager()),
    );

    expect(find.text('Biometrics required'), findsOneWidget);
    expect(find.textContaining('system settings'), findsOneWidget);
    expect(find.text('Unlock with biometrics'), findsNothing);
  });

  testWidgets('auth error view shows the failure and retries', (tester) async {
    final km = keyManager(available: false);
    final container = ProviderContainer(overrides: [
      vaultKeyManagerProvider.overrideWithValue(km),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: VaultAuthErrorView(
          failure: AuthFailure(message: 'Biometric authentication failed'),
        ),
      ),
    ));

    expect(find.text('Biometric authentication failed'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(container.read(vaultSessionProvider), isA<VaultUnavailable>());
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd packages/feature_coin && flutter test test/presentation/screens/vault_lock_screen_test.dart`
Expected: FAIL — screens undefined.

- [ ] **Step 4: Implement `vault_lock_screen.dart`**

```dart
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/vault_session.dart';

/// Shown whenever the vault is locked. The gate triggers one biometric
/// prompt automatically on entry; this screen is the manual retry surface.
class VaultLockScreen extends ConsumerWidget {
  const VaultLockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 16),
            Text(
              'Vault locked',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock with biometrics'),
              onPressed: () =>
                  ref.read(vaultSessionProvider.notifier).unlock(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Device has no biometric/device-credential capability. Fail-closed per
/// ADR 0009: vault creation is never offered here.
class VaultUnavailableView extends StatelessWidget {
  const VaultUnavailableView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: EmptyStateWidget(
        icon: Icons.no_encryption_outlined,
        title: 'Biometrics required',
        message:
            'The Airo Coin vault needs a device lock (fingerprint, face, or '
            'screen lock). Set one up in system settings, then return here.',
      ),
    );
  }
}

/// Hard-stop auth failure surface — never a silent retry loop.
class VaultAuthErrorView extends ConsumerWidget {
  const VaultAuthErrorView({super.key, required this.failure});

  final BaseFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ErrorView(
        icon: Icons.error_outline,
        title: 'Could not unlock the vault',
        message: failure.message,
        retryLabel: 'Try again',
        onRetry: () => ref.read(vaultSessionProvider.notifier).unlock(),
      ),
    );
  }
}
```

- [ ] **Step 5: Add exports to the barrel**

Append to `lib/feature_coin.dart`:

```dart
export 'src/domain/vault_record_type.dart';
export 'src/presentation/screens/vault_lock_screen.dart';
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd packages/feature_coin && flutter test test/presentation/screens/vault_lock_screen_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 7: Commit**

```bash
git add packages/feature_coin
git commit -m "feat(feature_coin): lock, unavailable, and auth-error views [skip ci]"
```

---

### Task 12: Summaries provider + MaskedVaultField + RecordDetailSheet

**Files:**
- Create: `packages/feature_coin/lib/src/application/vault_summaries_provider.dart`
- Create: `packages/feature_coin/lib/src/presentation/widgets/masked_vault_field.dart`
- Create: `packages/feature_coin/lib/src/presentation/widgets/record_detail_sheet.dart`
- Modify: `packages/feature_coin/lib/feature_coin.dart`
- Test: `packages/feature_coin/test/presentation/widgets/record_detail_sheet_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../application/vault_session_test.dart'
    show InMemoryVaultKeyStore;

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  late VaultDatabase vaultDb;
  late VaultRepositories repos;
  late ProviderContainer container;
  var clipboard = '';

  const summary = BankAccountSummary(
    nickname: 'HDFC Salary',
    bankName: 'HDFC Bank',
    accountHolderName: 'Jane Doe',
    ifscCode: 'HDFC0001234',
    accountType: 'savings',
  );

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    final cipher = FieldCipher();
    repos = VaultRepositories(
      bankAccounts: BankAccountRepository(database: vaultDb, fieldCipher: cipher),
      panCards: PanCardRepository(database: vaultDb, fieldCipher: cipher),
      creditCards: CreditCardRepository(database: vaultDb),
      secureDocuments: SecureDocumentRepository(database: vaultDb, fieldCipher: cipher),
    );
    final keyManager = VaultKeyManager.forTesting(
      secureStorage: InMemoryVaultKeyStore(),
      authenticate: () async => true,
      isAvailable: () async => true,
    );
    final localAuth = MockLocalAuthentication();
    when(() => localAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
        )).thenAnswer((_) async => true);
    clipboard = '';
    container = ProviderContainer(overrides: [
      vaultRepositoriesProvider.overrideWith((ref) async => repos),
      vaultKeyManagerProvider.overrideWithValue(keyManager),
      localAuthenticationProvider.overrideWithValue(localAuth),
      clipboardServiceProvider.overrideWithValue(ClipboardService(
        setData: (data) async => clipboard = data.text ?? '',
        getData: () async => ClipboardData(text: clipboard),
      )),
    ]);
    addTearDown(() async {
      container.dispose();
      await vaultDb.close();
    });

    // Unlock first so seed data is encrypted under the session's real DEK —
    // encrypting under any other key would make every reveal fail.
    await container.read(vaultSessionProvider.notifier).unlock();
    final dek = await container
        .read(vaultSessionProvider.notifier)
        .withKey((k) async => k);
    await repos.bankAccounts.create(
      BankAccountRecord(
        id: null,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1234567890',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
        notes: 'salary credit',
      ),
      dek!,
    );
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await container.read(vaultSessionProvider.notifier).unlock();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: RecordDetailSheet(
            recordType: VaultRecordType.bankAccount,
            recordKey: 'HDFC Salary',
            summary: summary,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('sensitive fields are masked by default', (tester) async {
    await pumpSheet(tester);

    expect(find.text('•••• •••• ••••'), findsOneWidget);
    expect(find.text('1234567890'), findsNothing);
    expect(find.text('HDFC Bank'), findsOneWidget); // plain field visible
  });

  testWidgets('tap-to-reveal decrypts and shows the account number',
      (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.byIcon(Icons.visibility).first);
    await tester.pumpAndSettle();

    expect(find.text('1234567890'), findsOneWidget);
  });

  testWidgets('copy stores the decrypted value via the clipboard service',
      (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.byIcon(Icons.copy).at(2)); // account number row
    await tester.pumpAndSettle();

    expect(clipboard, '1234567890');
  });

  testWidgets('delete confirms, re-authenticates, and removes the record',
      (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    final key = await container
        .read(vaultSessionProvider.notifier)
        .withKey((k) async => k);
    final fetched =
        await repos.bankAccounts.getByNickname('HDFC Salary', key!);
    expect(fetched.value, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_coin && flutter test test/presentation/widgets/record_detail_sheet_test.dart`
Expected: FAIL — files undefined.

- [ ] **Step 3: Implement `vault_summaries_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import 'vault_providers.dart';

/// Aggregated, key-free summaries for the vault home list. Loading this
/// provider performs no decryption — summaries are built from unencrypted
/// columns only.
final class VaultSummaries {
  const VaultSummaries({
    required this.bankAccounts,
    required this.panCards,
    required this.creditCards,
    required this.secureDocuments,
  });

  final List<BankAccountSummary> bankAccounts;
  final List<PanCardSummary> panCards;
  final List<CreditCardSummary> creditCards;
  final List<SecureDocumentSummary> secureDocuments;

  bool get isEmpty =>
      bankAccounts.isEmpty &&
      panCards.isEmpty &&
      creditCards.isEmpty &&
      secureDocuments.isEmpty;
}

final vaultSummariesProvider = FutureProvider<VaultSummaries>((ref) async {
  final repos = await ref.watch(vaultRepositoriesProvider.future);

  final bankAccounts = await repos.bankAccounts.listAllSummaries();
  final panCards = await repos.panCards.listAllSummaries();
  final creditCards = await repos.creditCards.listAllSummaries();
  final secureDocuments = await repos.secureDocuments.listAllSummaries();

  final errorMessage = bankAccounts.isFailure
      ? bankAccounts.failure.message
      : panCards.isFailure
          ? panCards.failure.message
          : creditCards.isFailure
              ? creditCards.failure.message
              : secureDocuments.isFailure
                  ? secureDocuments.failure.message
                  : null;
  if (errorMessage != null) {
    throw Exception(errorMessage);
  }

  return VaultSummaries(
    bankAccounts: bankAccounts.value,
    panCards: panCards.value,
    creditCards: creditCards.value,
    secureDocuments: secureDocuments.value,
  );
});
```

- [ ] **Step 4: Implement `masked_vault_field.dart`**

```dart
import 'package:flutter/material.dart';

/// One row in the record detail sheet. Plain fields pass [value] and no
/// [onReveal]; sensitive fields pass a masked placeholder as [value], the
/// decrypted text as [revealedValue], and an [onReveal] toggle.
class MaskedVaultField extends StatelessWidget {
  const MaskedVaultField({
    super.key,
    required this.label,
    required this.value,
    this.isRevealed = false,
    this.revealedValue,
    this.onReveal,
    this.onCopy,
  });

  final String label;
  final String value;
  final bool isRevealed;
  final String? revealedValue;
  final VoidCallback? onReveal;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final display = isRevealed ? (revealedValue ?? value) : value;
    return ListTile(
      dense: true,
      title: Text(label, style: Theme.of(context).textTheme.labelSmall),
      subtitle: Text(display, style: Theme.of(context).textTheme.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onReveal != null)
            IconButton(
              icon: Icon(
                isRevealed ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: onReveal,
            ),
          if (onCopy != null)
            IconButton(icon: const Icon(Icons.copy), onPressed: onCopy),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Implement `record_detail_sheet.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import '../../application/clipboard_service.dart';
import '../../application/vault_providers.dart';
import '../../application/vault_session.dart';
import '../../application/vault_summaries_provider.dart';
import '../../domain/vault_record_type.dart';
import 'masked_vault_field.dart';

/// Bottom sheet showing one vault record. Plain fields render from the
/// key-free [summary]; sensitive fields stay masked until the user reveals
/// them, which fetches and decrypts the full record once via
/// `VaultSession.withKey`.
class RecordDetailSheet extends ConsumerStatefulWidget {
  const RecordDetailSheet({
    super.key,
    required this.recordType,
    required this.recordKey,
    required this.summary,
  });

  final VaultRecordType recordType;

  /// Nickname for bank/card/document records; decimal row id for PAN cards.
  final String recordKey;

  /// Key-free projection used for plain (unencrypted) fields.
  final VaultEntrySummary summary;

  @override
  ConsumerState<RecordDetailSheet> createState() => _RecordDetailSheetState();
}

class _RecordDetailSheetState extends ConsumerState<RecordDetailSheet> {
  Object? _record;
  bool _loadingRecord = false;
  final Set<String> _revealedFields = {};

  Future<void> _ensureRecord() async {
    if (_record != null || _loadingRecord) return;
    setState(() => _loadingRecord = true);
    try {
      _record = await _fetchRecord();
    } finally {
      if (mounted) setState(() => _loadingRecord = false);
    }
  }

  Future<Object?> _fetchRecord() async {
    final repos = await ref.read(vaultRepositoriesProvider.future);
    final session = ref.read(vaultSessionProvider.notifier);
    switch (widget.recordType) {
      case VaultRecordType.bankAccount:
        return session.withKey((key) async =>
            (await repos.bankAccounts.getByNickname(widget.recordKey, key))
                .valueOrNull);
      case VaultRecordType.panCard:
        return session.withKey((key) async =>
            (await repos.panCards.getById(int.parse(widget.recordKey), key))
                .valueOrNull);
      case VaultRecordType.creditCard:
        return (await repos.creditCards.getByNickname(widget.recordKey))
            .valueOrNull;
      case VaultRecordType.secureDocument:
        return session.withKey((key) async =>
            (await repos.secureDocuments
                    .getByNickname(widget.recordKey, key))
                .valueOrNull);
    }
  }

  Future<void> _toggleReveal(String field) async {
    if (_revealedFields.contains(field)) {
      setState(() => _revealedFields.remove(field));
      return;
    }
    await _ensureRecord();
    if (_record != null && mounted) {
      setState(() => _revealedFields.add(field));
    }
  }

  Future<void> _copySensitive(
    String field,
    String? Function(Object record) extract,
  ) async {
    await _ensureRecord();
    final record = _record;
    if (record == null) return;
    await ref
        .read(clipboardServiceProvider)
        .copyWithAutoClear(extract(record) ?? '');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied — clipboard clears in 30 seconds'),
        ),
      );
    }
  }

  Future<void> _copyPlain(String value) async {
    await ref.read(clipboardServiceProvider).copyWithAutoClear(value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied — clipboard clears in 30 seconds'),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this record?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final authenticated = await ref
        .read(localAuthenticationProvider)
        .authenticate(
          localizedReason: 'Confirm deletion of this vault record',
        );
    if (!authenticated || !mounted) return;

    final repos = await ref.read(vaultRepositoriesProvider.future);
    final result = switch (widget.recordType) {
      VaultRecordType.bankAccount =>
        await repos.bankAccounts.deleteByNickname(widget.recordKey),
      VaultRecordType.panCard =>
        await repos.panCards.deleteById(int.parse(widget.recordKey)),
      VaultRecordType.creditCard =>
        await repos.creditCards.deleteByNickname(widget.recordKey),
      VaultRecordType.secureDocument =>
        await repos.secureDocuments.deleteByNickname(widget.recordKey),
    };
    if (!mounted) return;
    if (result.isFailure) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.failure.message)));
      return;
    }
    ref.invalidate(vaultSummariesProvider);
    Navigator.of(context).pop();
  }

  void _edit() {
    Navigator.of(context).pop();
    context.push(
      '/money/vault/edit/${widget.recordType.name}'
      '/${Uri.encodeComponent(widget.recordKey)}',
    );
  }

  String get _title => switch (widget.summary) {
        BankAccountSummary(:final nickname) => nickname,
        PanCardSummary(:final nameOnCard) => nameOnCard,
        CreditCardSummary(:final nickname) => nickname,
        SecureDocumentSummary(:final nickname) => nickname,
      };

  String get _typeLabel => switch (widget.recordType) {
        VaultRecordType.bankAccount => 'Bank account',
        VaultRecordType.panCard => 'PAN card',
        VaultRecordType.creditCard => 'Card (masked)',
        VaultRecordType.secureDocument => 'Secure document',
      };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(_title),
            subtitle: Text(_typeLabel),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _edit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _loadingRecord ? null : _delete,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(shrinkWrap: true, children: _rows),
          ),
        ],
      ),
    );
  }

  List<Widget> get _rows => switch (widget.recordType) {
        VaultRecordType.bankAccount =>
          _bankRows(widget.summary as BankAccountSummary),
        VaultRecordType.panCard => _panRows(widget.summary as PanCardSummary),
        VaultRecordType.creditCard =>
          _cardRows(widget.summary as CreditCardSummary),
        VaultRecordType.secureDocument =>
          _docRows(widget.summary as SecureDocumentSummary),
      };

  List<Widget> _bankRows(BankAccountSummary s) {
    final record = _record is BankAccountRecord
        ? _record as BankAccountRecord
        : null;
    return [
      MaskedVaultField(
        label: 'Bank',
        value: s.bankName,
        onCopy: () => _copyPlain(s.bankName),
      ),
      MaskedVaultField(label: 'Account holder', value: s.accountHolderName),
      MaskedVaultField(
        label: 'IFSC',
        value: s.ifscCode,
        onCopy: () => _copyPlain(s.ifscCode),
      ),
      MaskedVaultField(label: 'Account type', value: s.accountType),
      MaskedVaultField(
        label: 'Account number',
        value: '•••• •••• ••••',
        isRevealed: _revealedFields.contains('accountNumber'),
        revealedValue: record?.accountNumber,
        onReveal: () => _toggleReveal('accountNumber'),
        onCopy: () => _copySensitive(
          'accountNumber',
          (r) => (r as BankAccountRecord).accountNumber,
        ),
      ),
      MaskedVaultField(
        label: 'Notes',
        value: '••••',
        isRevealed: _revealedFields.contains('notes'),
        revealedValue: record?.notes ?? '—',
        onReveal: () => _toggleReveal('notes'),
      ),
    ];
  }

  List<Widget> _panRows(PanCardSummary s) {
    final record = _record is PanCardRecord ? _record as PanCardRecord : null;
    return [
      MaskedVaultField(label: 'Name on card', value: s.nameOnCard),
      if (s.fathersName != null)
        MaskedVaultField(label: "Father's name", value: s.fathersName!),
      MaskedVaultField(
        label: 'PAN',
        value: '••••••••••',
        isRevealed: _revealedFields.contains('panNumber'),
        revealedValue: record?.panNumber,
        onReveal: () => _toggleReveal('panNumber'),
        onCopy: () =>
            _copySensitive('panNumber', (r) => (r as PanCardRecord).panNumber),
      ),
    ];
  }

  List<Widget> _cardRows(CreditCardSummary s) {
    return [
      MaskedVaultField(label: 'Network', value: s.cardNetwork.name),
      MaskedVaultField(
        label: 'Card number',
        value: '•••• •••• •••• ${s.last4}',
        onCopy: () => _copyPlain(s.last4),
      ),
      MaskedVaultField(
        label: 'Expiry',
        value: '${s.expiryMonth.toString().padLeft(2, '0')}/${s.expiryYear}',
      ),
      MaskedVaultField(label: 'Issuing bank', value: s.issuingBank),
    ];
  }

  List<Widget> _docRows(SecureDocumentSummary s) {
    final record =
        _record is SecureDocumentRecord ? _record as SecureDocumentRecord : null;
    return [
      MaskedVaultField(label: 'Category', value: s.category.name),
      if (s.linkedAccountNickname != null)
        MaskedVaultField(
          label: 'Linked account',
          value: s.linkedAccountNickname!,
        ),
      MaskedVaultField(
        label: 'Custom fields',
        value: '••••',
        isRevealed: _revealedFields.contains('customFields'),
        revealedValue: record == null || record.customFields.isEmpty
            ? '—'
            : record.customFields.entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n'),
        onReveal: () => _toggleReveal('customFields'),
      ),
      MaskedVaultField(
        label: 'Notes',
        value: '••••',
        isRevealed: _revealedFields.contains('notes'),
        revealedValue: record?.notes ?? '—',
        onReveal: () => _toggleReveal('notes'),
      ),
    ];
  }
}
```

- [ ] **Step 6: Add exports to the barrel**

Append to `lib/feature_coin.dart`:

```dart
export 'src/application/vault_summaries_provider.dart';
export 'src/presentation/widgets/masked_vault_field.dart';
export 'src/presentation/widgets/record_detail_sheet.dart';
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd packages/feature_coin && flutter test test/presentation/widgets/record_detail_sheet_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 8: Commit**

```bash
git add packages/feature_coin
git commit -m "feat(feature_coin): summaries provider + reveal-on-demand detail sheet [skip ci]"
```

---

### Task 13: ScreenSecurity + VaultHomeScreen + VaultGateScreen

**Files:**
- Create: `packages/feature_coin/lib/src/application/screen_security.dart`
- Create: `packages/feature_coin/lib/src/presentation/screens/vault_home_screen.dart`
- Create: `packages/feature_coin/lib/src/presentation/screens/vault_gate_screen.dart`
- Modify: `packages/feature_coin/lib/feature_coin.dart`
- Test: `packages/feature_coin/test/presentation/screens/vault_gate_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../application/vault_session_test.dart' show InMemoryVaultKeyStore;

void main() {
  late VaultDatabase vaultDb;
  late VaultRepositories repos;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    final cipher = FieldCipher();
    repos = VaultRepositories(
      bankAccounts: BankAccountRepository(database: vaultDb, fieldCipher: cipher),
      panCards: PanCardRepository(database: vaultDb, fieldCipher: cipher),
      creditCards: CreditCardRepository(database: vaultDb),
      secureDocuments: SecureDocumentRepository(database: vaultDb, fieldCipher: cipher),
    );
  });

  tearDown(() => vaultDb.close());

  ProviderContainer containerFor(VaultKeyManager km) {
    final container = ProviderContainer(overrides: [
      vaultKeyManagerProvider.overrideWithValue(km),
      vaultRepositoriesProvider.overrideWith((ref) async => repos),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('gate auto-prompts and lands on the vault home when unlocked',
      (tester) async {
    final container = containerFor(VaultKeyManager.forTesting(
      secureStorage: InMemoryVaultKeyStore(),
      authenticate: () async => true,
      isAvailable: () async => true,
    ));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: VaultGateScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Secure Vault'), findsOneWidget);
    expect(find.text('Vault is empty'), findsOneWidget);
  });

  testWidgets('gate shows unavailable view on devices without biometrics',
      (tester) async {
    final container = containerFor(VaultKeyManager.forTesting(
      secureStorage: InMemoryVaultKeyStore(),
      authenticate: () async => true,
      isAvailable: () async => false,
    ));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: VaultGateScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Biometrics required'), findsOneWidget);
  });

  testWidgets('manual lock returns the gate to the lock screen',
      (tester) async {
    final container = containerFor(VaultKeyManager.forTesting(
      secureStorage: InMemoryVaultKeyStore(),
      authenticate: () async => true,
      isAvailable: () async => true,
    ));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: VaultGateScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Lock vault'));
    await tester.pumpAndSettle();

    expect(find.text('Vault locked'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_coin && flutter test test/presentation/screens/vault_gate_screen_test.dart`
Expected: FAIL — screens undefined.

- [ ] **Step 3: Implement `screen_security.dart`**

```dart
import 'package:screen_protector/screen_protector.dart';

/// Prevents screenshots and recents thumbnails while vault routes are
/// visible (FLAG_SECURE on Android, screen shield on iOS). Best-effort by
/// design: plugin failure must never block vault usage.
abstract final class ScreenSecurity {
  static Future<void> protect() async {
    try {
      await ScreenProtector.protectDataLeakageOn();
    } catch (_) {
      // Plugin unavailable (e.g. tests, unsupported platform) — ignore.
    }
  }

  static Future<void> unprotect() async {
    try {
      await ScreenProtector.protectDataLeakageOff();
    } catch (_) {
      // See protect().
    }
  }
}
```

- [ ] **Step 4: Implement `vault_home_screen.dart`**

```dart
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import '../../application/vault_session.dart';
import '../../application/vault_summaries_provider.dart';
import '../../domain/vault_record_type.dart';
import '../widgets/record_detail_sheet.dart';

/// Grouped, key-free list of everything in the vault. No decryption happens
/// on this screen — rows render from summaries only.
class VaultHomeScreen extends ConsumerWidget {
  const VaultHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(vaultSummariesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Lock vault',
            onPressed: () => ref.read(vaultSessionProvider.notifier).lock(),
          ),
        ],
      ),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(vaultSummariesProvider),
        ),
        data: (data) => data.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.lock_open_outlined,
                title: 'Vault is empty',
                message: 'Add your first record with the + button.',
              )
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(vaultSummariesProvider),
                child: ListView(
                  children: [
                    _SummarySection(
                      title: 'Bank accounts',
                      tiles: [
                        for (final s in data.bankAccounts)
                          _tile(
                            context,
                            icon: Icons.account_balance_outlined,
                            title: s.nickname,
                            subtitle: '${s.bankName} · ${s.ifscCode}',
                            type: VaultRecordType.bankAccount,
                            recordKey: s.nickname,
                            summary: s,
                          ),
                      ],
                    ),
                    _SummarySection(
                      title: 'PAN cards',
                      tiles: [
                        for (final s in data.panCards)
                          _tile(
                            context,
                            icon: Icons.badge_outlined,
                            title: s.nameOnCard,
                            subtitle: 'PAN card',
                            type: VaultRecordType.panCard,
                            recordKey: '${s.id}',
                            summary: s,
                          ),
                      ],
                    ),
                    _SummarySection(
                      title: 'Cards',
                      tiles: [
                        for (final s in data.creditCards)
                          _tile(
                            context,
                            icon: Icons.credit_card_outlined,
                            title: s.nickname,
                            subtitle:
                                '${s.cardNetwork.name} · •••• ${s.last4}',
                            type: VaultRecordType.creditCard,
                            recordKey: s.nickname,
                            summary: s,
                          ),
                      ],
                    ),
                    _SummarySection(
                      title: 'Documents',
                      tiles: [
                        for (final s in data.secureDocuments)
                          _tile(
                            context,
                            icon: Icons.folder_shared_outlined,
                            title: s.nickname,
                            subtitle: s.category.name,
                            type: VaultRecordType.secureDocument,
                            recordKey: s.nickname,
                            summary: s,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add record',
        onPressed: () => _showAddPicker(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VaultRecordType type,
    required String recordKey,
    required VaultEntrySummary summary,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => RecordDetailSheet(
          recordType: type,
          recordKey: recordKey,
          summary: summary,
        ),
      ),
    );
  }

  void _showAddPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (type, label, icon) in [
              (VaultRecordType.bankAccount, 'Bank account',
                  Icons.account_balance_outlined),
              (VaultRecordType.panCard, 'PAN card', Icons.badge_outlined),
              (VaultRecordType.creditCard, 'Card (masked)',
                  Icons.credit_card_outlined),
              (VaultRecordType.secureDocument, 'Secure document',
                  Icons.folder_shared_outlined),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/money/vault/add/${type.name}');
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.title, required this.tiles});

  final String title;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        ...tiles,
      ],
    );
  }
}
```

- [ ] **Step 5: Implement `vault_gate_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/screen_security.dart';
import '../../application/vault_session.dart';
import '../widgets/vault_lifecycle_observer.dart';
import 'vault_home_screen.dart';
import 'vault_lock_screen.dart';

/// Entry point for every `/money/vault*` route: switches on the session
/// state, prompts for biometrics on entry, keeps the lifecycle observer
/// mounted, and holds FLAG_SECURE for as long as the vault is visible.
class VaultGateScreen extends ConsumerStatefulWidget {
  const VaultGateScreen({super.key});

  @override
  ConsumerState<VaultGateScreen> createState() => _VaultGateScreenState();
}

class _VaultGateScreenState extends ConsumerState<VaultGateScreen> {
  @override
  void initState() {
    super.initState();
    ScreenSecurity.protect();
    Future.microtask(
      () => ref.read(vaultSessionProvider.notifier).unlock(),
    );
  }

  @override
  void dispose() {
    ScreenSecurity.unprotect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(vaultSessionProvider);
    final body = switch (session) {
      VaultUnlocked() => const VaultHomeScreen(),
      VaultUnavailable() => const VaultUnavailableView(),
      VaultAuthError(:final failure) =>
        VaultAuthErrorView(failure: failure),
      _ => const VaultLockScreen(),
    };
    return VaultLifecycleObserver(child: body);
  }
}
```

- [ ] **Step 6: Add exports to the barrel**

Append to `lib/feature_coin.dart`:

```dart
export 'src/application/screen_security.dart';
export 'src/presentation/screens/vault_gate_screen.dart';
export 'src/presentation/screens/vault_home_screen.dart';
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd packages/feature_coin && flutter test test/presentation/screens/vault_gate_screen_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 8: Commit**

```bash
git add packages/feature_coin
git commit -m "feat(feature_coin): gate + home screens with screen security [skip ci]"
```

---

### Task 14: Form dispatcher + BankAccountForm + PanCardForm

**Files:**
- Create: `packages/feature_coin/lib/src/presentation/screens/vault_record_form_screen.dart`
- Create: `packages/feature_coin/lib/src/presentation/widgets/forms/bank_account_form.dart`
- Create: `packages/feature_coin/lib/src/presentation/widgets/forms/pan_card_form.dart`
- Modify: `packages/feature_coin/lib/feature_coin.dart`
- Test: `packages/feature_coin/test/presentation/widgets/forms/bank_account_form_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../application/vault_session_test.dart'
    show InMemoryVaultKeyStore;

void main() {
  late VaultDatabase vaultDb;
  late VaultRepositories repos;
  late ProviderContainer container;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    final cipher = FieldCipher();
    repos = VaultRepositories(
      bankAccounts: BankAccountRepository(database: vaultDb, fieldCipher: cipher),
      panCards: PanCardRepository(database: vaultDb, fieldCipher: cipher),
      creditCards: CreditCardRepository(database: vaultDb),
      secureDocuments: SecureDocumentRepository(database: vaultDb, fieldCipher: cipher),
    );
    container = ProviderContainer(overrides: [
      vaultRepositoriesProvider.overrideWith((ref) async => repos),
      vaultKeyManagerProvider.overrideWithValue(VaultKeyManager.forTesting(
        secureStorage: InMemoryVaultKeyStore(),
        authenticate: () async => true,
        isAvailable: () async => true,
      )),
    ]);
    addTearDown(() async {
      container.dispose();
      await vaultDb.close();
    });
    await container.read(vaultSessionProvider.notifier).unlock();
  });

  Future<void> pumpBankForm(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: BankAccountForm())),
    ));
  }

  Future<void> fillValidBankForm(WidgetTester tester) async {
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nickname *'), 'HDFC Salary');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Bank name *'), 'HDFC Bank');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Account holder name *'),
        'Jane Doe');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Account number *'),
        '1234567890');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'IFSC *'), 'HDFC0001234');
  }

  testWidgets('invalid IFSC shows an inline error and saves nothing',
      (tester) async {
    await pumpBankForm(tester);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nickname *'), 'HDFC Salary');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Bank name *'), 'HDFC Bank');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Account holder name *'),
        'Jane Doe');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Account number *'),
        '1234567890');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'IFSC *'), 'NOT-AN-IFSC');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Invalid IFSC'), findsOneWidget);
    final summaries = await repos.bankAccounts.listAllSummaries();
    expect(summaries.value, isEmpty);
  });

  testWidgets('valid form creates the record', (tester) async {
    await pumpBankForm(tester);
    await fillValidBankForm(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final summaries = await repos.bankAccounts.listAllSummaries();
    expect(summaries.value.single.nickname, 'HDFC Salary');
  });

  testWidgets('duplicate nickname surfaces an inline nickname error',
      (tester) async {
    await pumpBankForm(tester);
    await fillValidBankForm(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Second add with the same nickname.
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: BankAccountForm())),
    ));
    await fillValidBankForm(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('already exists'), findsOneWidget);
  });
}
```

Note: `Save` pop calls `Navigator.pop` on success — the test harness has no
route below, which is fine (the assertion runs after `pumpAndSettle`; the pop
is a no-op against the root route).

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_coin && flutter test test/presentation/widgets/forms/bank_account_form_test.dart`
Expected: FAIL — `BankAccountForm` undefined.

- [ ] **Step 3: Implement `vault_record_form_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/vault_record_type.dart';
import '../widgets/forms/bank_account_form.dart';
import '../widgets/forms/credit_card_form.dart';
import '../widgets/forms/pan_card_form.dart';
import '../widgets/forms/secure_document_form.dart';

/// Add/edit host routed at `/money/vault/add/:type` and
/// `/money/vault/edit/:type/:key`. Dispatches to the per-type form.
class VaultRecordFormScreen extends ConsumerWidget {
  const VaultRecordFormScreen({
    super.key,
    required this.recordType,
    this.recordKey,
  });

  final VaultRecordType recordType;

  /// Nickname (or PAN row id as decimal string); null = add mode.
  final String? recordKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeLabel = switch (recordType) {
      VaultRecordType.bankAccount => 'Bank account',
      VaultRecordType.panCard => 'PAN card',
      VaultRecordType.creditCard => 'Card (masked)',
      VaultRecordType.secureDocument => 'Secure document',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text('${recordKey == null ? 'Add' : 'Edit'} $typeLabel'),
      ),
      body: switch (recordType) {
        VaultRecordType.bankAccount =>
          BankAccountForm(nickname: recordKey),
        VaultRecordType.panCard => PanCardForm(
            recordId: recordKey == null ? null : int.parse(recordKey!),
          ),
        VaultRecordType.creditCard =>
          CreditCardForm(nickname: recordKey),
        VaultRecordType.secureDocument =>
          SecureDocumentForm(nickname: recordKey),
      },
    );
  }
}
```

- [ ] **Step 4: Implement `bank_account_form.dart`**

```dart
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import '../../../application/vault_providers.dart';
import '../../../application/vault_session.dart';
import '../../../application/vault_summaries_provider.dart';

/// Add/edit form for [BankAccountRecord]. Edit mode is keyed by nickname
/// (immutable — it is the canonical cross-record handle). IFSC is validated
/// inline by the platform validator; the record constructor's ArgumentError
/// is the last-resort guard.
class BankAccountForm extends ConsumerStatefulWidget {
  const BankAccountForm({super.key, this.nickname});

  final String? nickname;

  @override
  ConsumerState<BankAccountForm> createState() => _BankAccountFormState();
}

class _BankAccountFormState extends ConsumerState<BankAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  final _bankName = TextEditingController();
  final _holder = TextEditingController();
  final _accountNumber = TextEditingController();
  final _ifsc = TextEditingController();
  final _branch = TextEditingController();
  final _notes = TextEditingController();
  String _accountType = 'savings';
  String? _nicknameError;
  bool _saving = false;
  bool _loaded = false;

  bool get _isEdit => widget.nickname != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _prefill();
  }

  Future<void> _prefill() async {
    final record =
        await ref.read(vaultSessionProvider.notifier).withKey((key) async {
      final repos = await ref.read(vaultRepositoriesProvider.future);
      return (await repos.bankAccounts.getByNickname(widget.nickname!, key))
          .valueOrNull;
    });
    if (record == null || !mounted) return;
    setState(() {
      _nickname.text = record.nickname;
      _bankName.text = record.bankName;
      _holder.text = record.accountHolderName;
      _accountNumber.text = record.accountNumber;
      _ifsc.text = record.ifscCode;
      _accountType = record.accountType;
      _branch.text = record.branchName ?? '';
      _notes.text = record.notes ?? '';
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _nickname.dispose();
    _bankName.dispose();
    _holder.dispose();
    _accountNumber.dispose();
    _ifsc.dispose();
    _branch.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;

  Future<void> _save() async {
    setState(() => _nicknameError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final record = BankAccountRecord(
        id: null,
        nickname: _nickname.text.trim(),
        bankName: _bankName.text.trim(),
        accountHolderName: _holder.text.trim(),
        accountNumber: _accountNumber.text.trim(),
        ifscCode: _ifsc.text.trim().toUpperCase(),
        accountType: _accountType,
        branchName: _branch.text.trim().isEmpty ? null : _branch.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      final repos = await ref.read(vaultRepositoriesProvider.future);
      final result =
          await ref.read(vaultSessionProvider.notifier).withKey((key) async {
        if (_isEdit) return repos.bankAccounts.update(record, key);
        final created = await repos.bankAccounts.create(record, key);
        return created.isSuccess
            ? const Success(null)
            : Failure(created.failure);
      });
      if (!mounted) return;
      if (result == null) {
        _showSnack('Vault is locked — unlock and try again');
      } else if (result.isFailure) {
        final failure = result.failure;
        if (failure is ValidationFailure && failure.field == 'nickname') {
          setState(() => _nicknameError = failure.message);
        } else {
          _showSnack(failure.message);
        }
      } else {
        ref.invalidate(vaultSummariesProvider);
        Navigator.of(context).pop();
      }
    } on ArgumentError {
      _showSnack('Invalid IFSC code');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && !_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nickname,
            enabled: !_isEdit,
            decoration: InputDecoration(
              labelText: 'Nickname *',
              errorText: _nicknameError,
            ),
            validator: _required,
          ),
          TextFormField(
            controller: _bankName,
            decoration: const InputDecoration(labelText: 'Bank name *'),
            validator: _required,
          ),
          TextFormField(
            controller: _holder,
            decoration:
                const InputDecoration(labelText: 'Account holder name *'),
            validator: _required,
          ),
          TextFormField(
            controller: _accountNumber,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration:
                const InputDecoration(labelText: 'Account number *'),
            validator: _required,
          ),
          TextFormField(
            controller: _ifsc,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'IFSC *'),
            validator: (value) =>
                value == null || !isValidIfsc(value.trim().toUpperCase())
                    ? 'Invalid IFSC (e.g. HDFC0001234)'
                    : null,
          ),
          DropdownButtonFormField<String>(
            initialValue: _accountType,
            decoration: const InputDecoration(labelText: 'Account type *'),
            items: const [
              DropdownMenuItem(value: 'savings', child: Text('Savings')),
              DropdownMenuItem(value: 'current', child: Text('Current')),
            ],
            onChanged: (value) =>
                setState(() => _accountType = value ?? 'savings'),
          ),
          TextFormField(
            controller: _branch,
            decoration: const InputDecoration(labelText: 'Branch'),
          ),
          TextFormField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
```

If `dart analyze` flags `initialValue` as undefined on
`DropdownButtonFormField`, the repo Flutter predates the rename — swap to
`value:` (same semantics, older name).

- [ ] **Step 5: Implement `pan_card_form.dart`**

```dart
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import '../../../application/vault_providers.dart';
import '../../../application/vault_session.dart';
import '../../../application/vault_summaries_provider.dart';

/// Add/edit form for [PanCardRecord]. Edit mode is keyed by row id (PAN
/// rows have no nickname). Card images are out of v1 scope.
class PanCardForm extends ConsumerStatefulWidget {
  const PanCardForm({super.key, this.recordId});

  final int? recordId;

  @override
  ConsumerState<PanCardForm> createState() => _PanCardFormState();
}

class _PanCardFormState extends ConsumerState<PanCardForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameOnCard = TextEditingController();
  final _panNumber = TextEditingController();
  final _fathersName = TextEditingController();
  DateTime? _dob;
  bool _saving = false;
  bool _loaded = false;

  bool get _isEdit => widget.recordId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _prefill();
  }

  Future<void> _prefill() async {
    final record =
        await ref.read(vaultSessionProvider.notifier).withKey((key) async {
      final repos = await ref.read(vaultRepositoriesProvider.future);
      return (await repos.panCards.getById(widget.recordId!, key))
          .valueOrNull;
    });
    if (record == null || !mounted) return;
    setState(() {
      _nameOnCard.text = record.nameOnCard;
      _panNumber.text = record.panNumber;
      _fathersName.text = record.fathersName ?? '';
      _dob = record.dateOfBirth;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _nameOnCard.dispose();
    _panNumber.dispose();
    _fathersName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final record = PanCardRecord(
        id: widget.recordId,
        panNumber: _panNumber.text.trim().toUpperCase(),
        nameOnCard: _nameOnCard.text.trim(),
        fathersName: _fathersName.text.trim().isEmpty
            ? null
            : _fathersName.text.trim(),
        dateOfBirth: _dob,
      );
      final repos = await ref.read(vaultRepositoriesProvider.future);
      final result =
          await ref.read(vaultSessionProvider.notifier).withKey((key) async {
        if (_isEdit) return repos.panCards.update(record, key);
        final created = await repos.panCards.create(record, key);
        return created.isSuccess
            ? const Success(null)
            : Failure(created.failure);
      });
      if (!mounted) return;
      if (result == null) {
        _showSnack('Vault is locked — unlock and try again');
      } else if (result.isFailure) {
        _showSnack(result.failure.message);
      } else {
        ref.invalidate(vaultSummariesProvider);
        Navigator.of(context).pop();
      }
    } on ArgumentError {
      _showSnack('Invalid PAN number');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && !_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nameOnCard,
            decoration: const InputDecoration(labelText: 'Name on card *'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          TextFormField(
            controller: _panNumber,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'PAN *'),
            validator: (value) =>
                value == null || !isValidPan(value.trim().toUpperCase())
                    ? 'Invalid PAN (e.g. ABCDE1234F)'
                    : null,
          ),
          TextFormField(
            controller: _fathersName,
            decoration: const InputDecoration(labelText: "Father's name"),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_dob == null
                ? 'Date of birth (optional)'
                : 'DOB: ${_dob!.toLocal()}'.split(' ').first),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(1990),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _dob = picked);
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Create compile stubs for the remaining two forms, then add barrel exports**

`vault_record_form_screen.dart` imports `credit_card_form.dart` and
`secure_document_form.dart`, which get their real implementations in
Task 15. Create both as minimal stubs now so the package compiles:

`lib/src/presentation/widgets/forms/credit_card_form.dart`:

```dart
import 'package:flutter/material.dart';

/// Stub — real implementation lands in Task 15.
class CreditCardForm extends StatelessWidget {
  const CreditCardForm({super.key, this.nickname});

  final String? nickname;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

`lib/src/presentation/widgets/forms/secure_document_form.dart`:

```dart
import 'package:flutter/material.dart';

/// Stub — real implementation lands in Task 15.
class SecureDocumentForm extends StatelessWidget {
  const SecureDocumentForm({super.key, this.nickname});

  final String? nickname;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

Append to `lib/feature_coin.dart`:

```dart
export 'src/presentation/screens/vault_record_form_screen.dart';
export 'src/presentation/widgets/forms/bank_account_form.dart';
export 'src/presentation/widgets/forms/pan_card_form.dart';
```

- [ ] **Step 7: Run tests**

Run: `cd packages/feature_coin && flutter test test/presentation/widgets/forms/bank_account_form_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 8: Commit**

```bash
git add packages/feature_coin
git commit -m "feat(feature_coin): form dispatcher + bank/PAN forms with validation [skip ci]"
```

---

### Task 15: CreditCardForm + SecureDocumentForm

**Files:**
- Create (replace Task 14 stubs): `packages/feature_coin/lib/src/presentation/widgets/forms/credit_card_form.dart`
- Create (replace Task 14 stubs): `packages/feature_coin/lib/src/presentation/widgets/forms/secure_document_form.dart`
- Modify: `packages/feature_coin/lib/feature_coin.dart`
- Test: `packages/feature_coin/test/presentation/widgets/forms/credit_card_form_test.dart`
- Test: `packages/feature_coin/test/presentation/widgets/forms/secure_document_form_test.dart`

- [ ] **Step 1: Write the failing tests**

`credit_card_form_test.dart`:

```dart
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../application/vault_session_test.dart'
    show InMemoryVaultKeyStore;

void main() {
  late VaultDatabase vaultDb;
  late VaultRepositories repos;
  late ProviderContainer container;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    final cipher = FieldCipher();
    repos = VaultRepositories(
      bankAccounts: BankAccountRepository(database: vaultDb, fieldCipher: cipher),
      panCards: PanCardRepository(database: vaultDb, fieldCipher: cipher),
      creditCards: CreditCardRepository(database: vaultDb),
      secureDocuments: SecureDocumentRepository(database: vaultDb, fieldCipher: cipher),
    );
    container = ProviderContainer(overrides: [
      vaultRepositoriesProvider.overrideWith((ref) async => repos),
      vaultKeyManagerProvider.overrideWithValue(VaultKeyManager.forTesting(
        secureStorage: InMemoryVaultKeyStore(),
        authenticate: () async => true,
        isAvailable: () async => true,
      )),
    ]);
    addTearDown(() async {
      container.dispose();
      await vaultDb.close();
    });
    await container.read(vaultSessionProvider.notifier).unlock();
  });

  testWidgets('rejects a non-4-digit last4', (tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: CreditCardForm())),
    ));

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nickname *'), 'Main Card');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Last 4 digits *'), '123');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Expiry month *'), '8');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Expiry year *'), '2029');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Issuing bank *'), 'ICICI Bank');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Exactly 4 digits'), findsOneWidget);
    expect((await repos.creditCards.listAllSummaries()).value, isEmpty);
  });

  testWidgets('valid masked card saves without any full-PAN field',
      (tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: CreditCardForm())),
    ));

    expect(find.widgetWithText(TextFormField, 'Card number'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'CVV'), findsNothing);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nickname *'), 'Main Card');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Last 4 digits *'), '4321');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Expiry month *'), '8');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Expiry year *'), '2029');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Issuing bank *'), 'ICICI Bank');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final summaries = (await repos.creditCards.listAllSummaries()).value;
    expect(summaries.single.nickname, 'Main Card');
    expect(summaries.single.last4, '4321');
  });
}
```

`secure_document_form_test.dart`:

```dart
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../application/vault_session_test.dart'
    show InMemoryVaultKeyStore;

void main() {
  late VaultDatabase vaultDb;
  late VaultRepositories repos;
  late ProviderContainer container;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    final cipher = FieldCipher();
    repos = VaultRepositories(
      bankAccounts: BankAccountRepository(database: vaultDb, fieldCipher: cipher),
      panCards: PanCardRepository(database: vaultDb, fieldCipher: cipher),
      creditCards: CreditCardRepository(database: vaultDb),
      secureDocuments: SecureDocumentRepository(database: vaultDb, fieldCipher: cipher),
    );
    container = ProviderContainer(overrides: [
      vaultRepositoriesProvider.overrideWith((ref) async => repos),
      vaultKeyManagerProvider.overrideWithValue(VaultKeyManager.forTesting(
        secureStorage: InMemoryVaultKeyStore(),
        authenticate: () async => true,
        isAvailable: () async => true,
      )),
    ]);
    addTearDown(() async {
      container.dispose();
      await vaultDb.close();
    });
    await container.read(vaultSessionProvider.notifier).unlock();
  });

  testWidgets('saves a document with category and custom fields',
      (tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: SecureDocumentForm())),
    ));

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nickname *'), 'Form 16 FY25');

    await tester.tap(find.text('Add field'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Field name').first, 'employer');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Value').first, 'Acme');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final summaries =
        (await repos.secureDocuments.listAllSummaries()).value;
    expect(summaries.single.nickname, 'Form 16 FY25');
    expect(summaries.single.category, DocumentCategory.incomeProof);

    final key = await container
        .read(vaultSessionProvider.notifier)
        .withKey((k) async => k);
    final record =
        (await repos.secureDocuments.getByNickname('Form 16 FY25', key!))
            .value;
    expect(record?.customFields, {'employer': 'Acme'});
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/feature_coin && flutter test test/presentation/widgets/forms/`
Expected: FAIL — stub forms render nothing.

- [ ] **Step 3: Implement `credit_card_form.dart`** (masked-only — no full PAN/CVV/PIN fields by design)

```dart
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import '../../../application/vault_providers.dart';
import '../../../application/vault_summaries_provider.dart';

/// Add/edit form for [CreditCardRecord]. Stores masked-only references:
/// network, last4, expiry, issuing bank. Full card number, CVV, and PIN
/// fields must never be added here (ADR 0009).
class CreditCardForm extends ConsumerStatefulWidget {
  const CreditCardForm({super.key, this.nickname});

  final String? nickname;

  @override
  ConsumerState<CreditCardForm> createState() => _CreditCardFormState();
}

class _CreditCardFormState extends ConsumerState<CreditCardForm> {
  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  final _last4 = TextEditingController();
  final _expiryMonth = TextEditingController();
  final _expiryYear = TextEditingController();
  final _issuingBank = TextEditingController();
  CardNetwork _network = CardNetwork.visa;
  String? _nicknameError;
  bool _saving = false;
  bool _loaded = false;

  bool get _isEdit => widget.nickname != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _prefill();
  }

  Future<void> _prefill() async {
    final repos = await ref.read(vaultRepositoriesProvider.future);
    final record =
        (await repos.creditCards.getByNickname(widget.nickname!)).valueOrNull;
    if (record == null || !mounted) return;
    setState(() {
      _nickname.text = record.nickname;
      _last4.text = record.last4;
      _expiryMonth.text = '${record.expiryMonth}';
      _expiryYear.text = '${record.expiryYear}';
      _issuingBank.text = record.issuingBank;
      _network = record.cardNetwork;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _nickname.dispose();
    _last4.dispose();
    _expiryMonth.dispose();
    _expiryYear.dispose();
    _issuingBank.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _nicknameError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final record = CreditCardRecord(
        id: null,
        nickname: _nickname.text.trim(),
        cardNetwork: _network,
        last4: _last4.text.trim(),
        expiryMonth: int.parse(_expiryMonth.text.trim()),
        expiryYear: int.parse(_expiryYear.text.trim()),
        issuingBank: _issuingBank.text.trim(),
        createdAt: DateTime.now(),
      );
      final repos = await ref.read(vaultRepositoriesProvider.future);
      final result = _isEdit
          ? await repos.creditCards.update(record)
          : await repos.creditCards.create(record);
      if (!mounted) return;
      if (result.isFailure) {
        final failure = result.failure;
        if (failure is ValidationFailure && failure.field == 'nickname') {
          setState(() => _nicknameError = failure.message);
        } else {
          _showSnack(failure.message);
        }
      } else {
        ref.invalidate(vaultSummariesProvider);
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && !_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nickname,
            enabled: !_isEdit,
            decoration: InputDecoration(
              labelText: 'Nickname *',
              errorText: _nicknameError,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          DropdownButtonFormField<CardNetwork>(
            initialValue: _network,
            decoration: const InputDecoration(labelText: 'Network *'),
            items: [
              for (final network in CardNetwork.values)
                DropdownMenuItem(
                  value: network,
                  child: Text(network.name),
                ),
            ],
            onChanged: (value) =>
                setState(() => _network = value ?? CardNetwork.visa),
          ),
          TextFormField(
            controller: _last4,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'Last 4 digits *'),
            validator: (value) =>
                value == null || !RegExp(r'^\d{4}$').hasMatch(value.trim())
                    ? 'Exactly 4 digits'
                    : null,
          ),
          TextFormField(
            controller: _expiryMonth,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Expiry month *'),
            validator: (value) {
              final month = int.tryParse(value?.trim() ?? '');
              return (month == null || month < 1 || month > 12)
                  ? 'Month 1–12'
                  : null;
            },
          ),
          TextFormField(
            controller: _expiryYear,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Expiry year *'),
            validator: (value) {
              final year = int.tryParse(value?.trim() ?? '');
              final now = DateTime.now().year;
              return (year == null || year < now || year > now + 30)
                  ? 'Year $now–${now + 30}'
                  : null;
            },
          ),
          TextFormField(
            controller: _issuingBank,
            decoration: const InputDecoration(labelText: 'Issuing bank *'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement `secure_document_form.dart`**

```dart
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import '../../../application/vault_providers.dart';
import '../../../application/vault_session.dart';
import '../../../application/vault_summaries_provider.dart';

/// User-facing labels for the ITR-driven document taxonomy.
const Map<DocumentCategory, String> documentCategoryLabels = {
  DocumentCategory.personalId: 'Personal ID (Aadhaar etc.)',
  DocumentCategory.incomeProof: 'Income proof (Form 16/16A)',
  DocumentCategory.taxCredit: 'Tax credit (26AS/AIS/TIS)',
  DocumentCategory.investmentProof: 'Investment proof (80C/80D)',
  DocumentCategory.hra: 'HRA / rent receipts',
  DocumentCategory.capitalGains: 'Capital gains',
  DocumentCategory.homeLoan: 'Home loan',
  DocumentCategory.other: 'Other',
};

/// Add/edit form for [SecureDocumentRecord]: category, optional linked bank
/// account, key-value custom fields, notes. Attachments are out of v1 scope.
class SecureDocumentForm extends ConsumerStatefulWidget {
  const SecureDocumentForm({super.key, this.nickname});

  final String? nickname;

  @override
  ConsumerState<SecureDocumentForm> createState() =>
      _SecureDocumentFormState();
}

class _SecureDocumentFormState extends ConsumerState<SecureDocumentForm> {
  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  final _notes = TextEditingController();
  final List<({TextEditingController key, TextEditingController value})>
      _customFields = [];
  DocumentCategory _category = DocumentCategory.incomeProof;
  String _linkedAccount = '';
  List<String> _accountNicknames = [];
  String? _nicknameError;
  bool _saving = false;
  bool _loaded = false;

  bool get _isEdit => widget.nickname != null;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    if (_isEdit) {
      _prefill();
    } else {
      _loaded = true;
    }
  }

  Future<void> _loadAccounts() async {
    final repos = await ref.read(vaultRepositoriesProvider.future);
    final result = await repos.bankAccounts.listAllSummaries();
    if (result.isSuccess && mounted) {
      setState(() => _accountNicknames =
          result.value.map((s) => s.nickname).toList());
    }
  }

  Future<void> _prefill() async {
    final record =
        await ref.read(vaultSessionProvider.notifier).withKey((key) async {
      final repos = await ref.read(vaultRepositoriesProvider.future);
      return (await repos.secureDocuments
              .getByNickname(widget.nickname!, key))
          .valueOrNull;
    });
    if (record == null || !mounted) return;
    setState(() {
      _nickname.text = record.nickname;
      _category = record.category;
      _linkedAccount = record.linkedAccountNickname ?? '';
      _notes.text = record.notes ?? '';
      for (final entry in record.customFields.entries) {
        _customFields.add((
          key: TextEditingController(text: entry.key),
          value: TextEditingController(text: entry.value),
        ));
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _nickname.dispose();
    _notes.dispose();
    for (final field in _customFields) {
      field.key.dispose();
      field.value.dispose();
    }
    super.dispose();
  }

  void _addCustomField() {
    setState(() => _customFields.add((
          key: TextEditingController(),
          value: TextEditingController(),
        )));
  }

  void _removeCustomField(int index) {
    setState(() {
      final field = _customFields.removeAt(index);
      field.key.dispose();
      field.value.dispose();
    });
  }

  Map<String, String> _customFieldsMap() {
    final map = <String, String>{};
    for (final field in _customFields) {
      final key = field.key.text.trim();
      if (key.isNotEmpty) map[key] = field.value.text.trim();
    }
    return map;
  }

  Future<void> _save() async {
    setState(() => _nicknameError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final record = SecureDocumentRecord(
        id: null,
        nickname: _nickname.text.trim(),
        category: _category,
        createdAt: DateTime.now(),
        linkedAccountNickname:
            _linkedAccount.isEmpty ? null : _linkedAccount,
        customFields: _customFieldsMap(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      final repos = await ref.read(vaultRepositoriesProvider.future);
      final result =
          await ref.read(vaultSessionProvider.notifier).withKey((key) async {
        if (_isEdit) return repos.secureDocuments.update(record, key);
        final created = await repos.secureDocuments.create(record, key);
        return created.isSuccess
            ? const Success(null)
            : Failure(created.failure);
      });
      if (!mounted) return;
      if (result == null) {
        _showSnack('Vault is locked — unlock and try again');
      } else if (result.isFailure) {
        final failure = result.failure;
        if (failure is ValidationFailure && failure.field == 'nickname') {
          setState(() => _nicknameError = failure.message);
        } else {
          _showSnack(failure.message);
        }
      } else {
        ref.invalidate(vaultSummariesProvider);
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nickname,
            enabled: !_isEdit,
            decoration: InputDecoration(
              labelText: 'Nickname *',
              errorText: _nicknameError,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          DropdownButtonFormField<DocumentCategory>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category *'),
            items: [
              for (final category in DocumentCategory.values)
                DropdownMenuItem(
                  value: category,
                  child: Text(documentCategoryLabels[category]!),
                ),
            ],
            onChanged: (value) => setState(() =>
                _category = value ?? DocumentCategory.incomeProof),
          ),
          DropdownButtonFormField<String>(
            initialValue: _linkedAccount,
            decoration:
                const InputDecoration(labelText: 'Linked bank account'),
            items: [
              const DropdownMenuItem(value: '', child: Text('None')),
              for (final nickname in _accountNicknames)
                DropdownMenuItem(value: nickname, child: Text(nickname)),
            ],
            onChanged: (value) =>
                setState(() => _linkedAccount = value ?? ''),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Custom fields',
                  style: Theme.of(context).textTheme.titleSmall),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add field'),
                onPressed: _addCustomField,
              ),
            ],
          ),
          for (var i = 0; i < _customFields.length; i++)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _customFields[i].key,
                    decoration:
                        const InputDecoration(labelText: 'Field name'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _customFields[i].value,
                    decoration: const InputDecoration(labelText: 'Value'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _removeCustomField(i),
                ),
              ],
            ),
          TextFormField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Add exports to the barrel**

Append to `lib/feature_coin.dart`:

```dart
export 'src/presentation/widgets/forms/credit_card_form.dart';
export 'src/presentation/widgets/forms/secure_document_form.dart';
```

- [ ] **Step 6: Run the full package suite + analyze**

Run: `cd packages/feature_coin && flutter test && dart analyze`
Expected: all PASS, no issues.

- [ ] **Step 7: Commit + open PR 3**

```bash
git add packages/feature_coin
git commit -m "feat(feature_coin): card + secure document forms [skip ci]"
git push
gh pr create --title "feat(feature_coin): vault UI — lock, list, detail, forms" --body "Slice 3 of #<issue>. Gate/lock screens, summary-driven home list (no decryption), reveal-on-demand detail sheet with copy-with-auto-clear and biometric-confirmed delete, add/edit forms for all 4 record types with IFSC/PAN validation. Local: flutter test + dart analyze clean."
```

---

## SLICE 4 — shell wiring (PR 4)

### Task 16: Routes + RouteNames + app pubspec swap

**Files:**
- Modify: `app/lib/core/routing/route_names.dart`
- Modify: `app/lib/core/routing/app_router.dart`
- Modify: `app/pubspec.yaml`
- Modify: `app/pubspec_ios_spm.yaml`

- [ ] **Step 1: Add route names** — in `route_names.dart`, after the Coins section:

```dart
  // Coin Vault (feature_coin)
  static const String coinVault = 'coin_vault';
  static const String coinVaultAdd = 'coin_vault_add';
  static const String coinVaultEdit = 'coin_vault_edit';
  static const String coinVaultPath = '/money/vault';
```

Also delete the dead constant (the route was never registered):

```dart
  static const String airomoney = '/airomoney';
```

- [ ] **Step 2: Register vault routes** — in `app_router.dart`:

Add the import (with the other feature imports at the top):

```dart
import 'package:feature_coin/feature_coin.dart';
```

Inside the Money branch's `/money` GoRoute `routes:` list, directly after the `path: 'split'` GoRoute:

```dart
                  // Coin Vault (feature_coin)
                  GoRoute(
                    path: 'vault',
                    name: RouteNames.coinVault,
                    builder: (context, state) => const VaultGateScreen(),
                    routes: [
                      GoRoute(
                        path: 'add/:type',
                        name: RouteNames.coinVaultAdd,
                        builder: (context, state) => VaultRecordFormScreen(
                          recordType: VaultRecordType.values
                              .byName(state.pathParameters['type']!),
                        ),
                      ),
                      GoRoute(
                        path: 'edit/:type/:key',
                        name: RouteNames.coinVaultEdit,
                        builder: (context, state) => VaultRecordFormScreen(
                          recordType: VaultRecordType.values
                              .byName(state.pathParameters['type']!),
                          recordKey: state.pathParameters['key'],
                        ),
                      ),
                    ],
                  ),
```

- [ ] **Step 3: Swap the package dependency** — in `app/pubspec.yaml`, replace:

```yaml
  airomoney:
    path: ../packages/airomoney
```

with:

```yaml
  feature_coin:
    path: ../packages/feature_coin
```

Make the identical replacement in `app/pubspec_ios_spm.yaml`. Do NOT touch
`app/pubspec_tv.yaml` (finance/vault stays off TV per spec).

- [ ] **Step 4: Validate**

Run: `cd app && flutter pub get && dart analyze lib/core/routing`
Expected: pub get resolves (airomoney path gone); no analyzer issues in routing.

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/routing app/pubspec.yaml app/pubspec_ios_spm.yaml
git commit -m "feat(app): register /money/vault routes, swap airomoney for feature_coin [skip ci]"
```

---

### Task 17: Coins dashboard entry card + home screen fix + final validation

**Files:**
- Modify: `app/lib/features/coins/presentation/screens/coins_dashboard_screen.dart`
- Modify: `app/lib/features/home/screens/home_screen.dart`

- [ ] **Step 1: Add the Secure Vault entry card** — in `coins_dashboard_screen.dart`:

Add the import at the top (the file currently has no go_router import):

```dart
import 'package:go_router/go_router.dart';
```

In the dashboard body `ListView`/`Column` children, directly after the
`const _QuickAddExpenseCard(),` entry, insert:

```dart
                  // Secure Vault entry (feature_coin)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Secure Vault'),
                      subtitle: const Text(
                        'Bank accounts, PAN, cards & documents',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(RouteNames.coinVaultPath),
                    ),
                  ),
```

Add `import '../../../../core/routing/route_names.dart';` if not already
present in that file's import block.

- [ ] **Step 2: Repoint the dead AiroMoney home card** — in `home_screen.dart`, replace:

```dart
                  AppCard(
                    title: 'AiroMoney',
                    description: 'Financial management',
                    icon: Icons.account_balance_wallet,
                    color: Colors.green,
                    onTap: () => context.go(RouteNames.airomoney),
                  ),
```

with:

```dart
                  AppCard(
                    title: 'Coins',
                    description: 'Expenses, budgets & secure vault',
                    icon: Icons.account_balance_wallet,
                    color: Colors.green,
                    onTap: () => context.go('/money'),
                  ),
```

- [ ] **Step 3: Full local validation** (per AGENTS.md — focused, local, no remote CI)

```bash
cd packages/feature_coin && flutter test && dart analyze && cd ../..
cd packages/platform_coin_vault && flutter test && dart analyze && cd ../..
cd app && flutter pub get && dart analyze lib/core lib/features/home lib/features/coins
git diff --check
```

Expected: all tests pass, analyzer clean, no whitespace errors.

- [ ] **Step 4: Commit + open PR 4**

```bash
git add app/lib/features/coins app/lib/features/home
git commit -m "feat(app): Secure Vault entry card; repoint dead AiroMoney card to /money [skip ci]"
git push
gh pr create --title "feat(app): wire feature_coin vault into Coins tab" --body "Slice 4 of #<issue>. Closes #<issue> if it's the final slice. /money/vault routes under the Coins branch, Secure Vault entry card, dead AiroMoney 404 card repointed. Manual dogfood remaining: biometric prompt + FLAG_SECURE on a physical Android device."
```

- [ ] **Step 5: Manual dogfood checklist** (record evidence on the issue, then close it per AGENTS.md)

- Biometric prompt appears on vault entry; wrong biometrics → hard-stop error view.
- Screenshot/recents blocked while in vault (FLAG_SECURE), restored on exit.
- App to background → vault locked on return.
- Add/reveal/copy/edit/delete round-trip for each of the 4 record types on device.
- Clipboard is empty ~30s after a copy.

---

## Self-Review Notes (resolved while writing)

- **PAN asymmetry:** keyed by row id everywhere (list, update, delete, edit route key) — spec coverage confirmed with repo tests in Task 3 and UC-9.
- **Type consistency:** `VaultRecordType` lives in `lib/src/domain/vault_record_type.dart` and is used identically by the sheet, forms, and router. `withKey` returns `Future<T?>`; forms normalise `Result<int>` (create) to `Result<void>` via a success/failure map so edit and add share one path.
- **Barrel order:** Tasks 14–15 create two form stubs before the real forms so `vault_record_form_screen.dart` always compiles; stubs are replaced in Task 15.
- **No placeholders:** every code step contains complete, runnable code. The only runtime-dependent check left to a human is the Step-5 dogfood checklist (biometrics/FLAG_SECURE cannot run in CI).
- **Golden tests deferred (deviation from spec):** the spec mentions alchemist goldens for LockScreen/VaultHomeScreen/RecordDetailSheet. The plan relies on state-level widget tests instead — goldens during active UI iteration produce churn without catching behavior regressions. Add goldens as a follow-up once the vault UI stabilizes; `alchemist` is already in the app's dev deps to mirror.
