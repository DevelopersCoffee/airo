# Airo Coin — Vault Crypto & Storage Layer (`platform_coin_vault`) — Design

**Date:** 2026-07-19
**Status:** Approved (brainstorm) → pending implementation plan
**Owner package:** `platform_coin_vault` (new)
**Depends on:** `core_data` (secure storage / encryption interfaces), `core_domain`
**Source issue:** [#927](https://github.com/DevelopersCoffee/airo/issues/927) — Airo Coin secure financial vault
**Related package:** `airomoney` (existing stub — wallet/transaction placeholders,
out of scope for this cycle; superseded by this design and renamed to `airo_coin`
in a later phase covering the `feature_coin` presentation layer)

## Problem

Airo (the super app, phone/iPad only, no shared/TV devices) needs a second
module alongside Airo TV: a personal financial vault storing PAN card, bank
account, and credit card references, plus generic tax/financial documents —
locally, encrypted at rest, unlockable only via biometrics. #927 specifies the
full v1 scope (crypto + storage + UI + tests) as a single P1 issue; this design
covers only the first half — the crypto and storage layer, with zero UI — so
it can be spec'd, planned, and reviewed as one coherent unit. The presentation
layer (`feature_coin`: lock screen, list/add/edit UI, masking, auto-lock UX)
is a separate design, built once this layer exists.

A stub package, `packages/airomoney`, already exists in the repo (wallet_screen,
transaction_screen, money_card widgets) but models a different concept
(wallet/transactions) than #927 (vault/records). It will be gutted and renamed
to `airo_coin` when the `feature_coin` presentation design lands; it is not
touched by this design.

`core_data` already defines the interfaces this problem needs —
`SecureStorage`, `EncryptionKeyManager`, `EncryptedDatabase`
(`packages/core_data/lib/src/secure/secure_storage.dart`) — but has no
biometric-gated implementation. `platform_coin_vault` implements them rather
than inventing a parallel abstraction.

## Goals

- Store four record types, encrypted at rest, field-level: `BankAccountRecord`,
  `PanCardRecord`, `CreditCardRecord` (masked only), `SecureDocumentRecord`
  (generic, category-tagged, covers Indian ITR filing documents).
- Biometric-gated key access: no fingerprint/Face ID (or device-credential
  fallback via the OS, never a custom PIN screen), no decryption — cryptographically,
  not just at the UI layer.
- Zero new native database runtime: reuse `core_data`'s existing `sqflite`
  dependency. Do not introduce SQLCipher or a second sqlite engine (see
  `platform_playlist`'s drift/sqlite3_flutter_libs stack — a different,
  pre-existing runtime this design does not touch or duplicate).
- Nothing sensitive ever in plaintext: not the DB, not logs, not crash reports.
- Full unit test coverage of the crypto roundtrip and validators before any UI
  is built on top.

## Non-Goals (deferred, explicitly out of scope for this slice)

- Any UI: lock screen, list/add/edit forms, masking widgets, `FLAG_SECURE`,
  auto-lock timers, clipboard auto-clear. All of this is `feature_coin`,
  designed separately once this layer ships.
- Cloud sync/backup, bank account aggregation (AA framework), transactions,
  balances — out of scope for Airo Coin v1 entirely per #927.
- Full credit card number, CVV, or PIN storage. `CreditCardRecord` is
  masked-only (network, last4, expiry, issuing bank) — same treatment as
  debit cards in #927.
- TV/desktop surfaces. Airo Coin is phone + iPad only, no shared devices.
- Gutting/renaming the `airomoney` stub package — deferred to the
  `feature_coin` design.

## Data Model

```
domain/
  BankAccountRecord
    - nickname            (unique within vault — canonical account-source key,
                            referenced by other Coin records via
                            linkedAccountNickname)
    - bankName, accountHolderName, accountNumber (masked), ifscCode
      (validated ^[A-Z]{4}0[A-Z0-9]{6}$), accountType, branchName?, micrCode?,
      swiftIban?, customerId?, upiIds?, linkedMobile?, linkedEmail?,
      nomineeName?, debitCardLast4?, debitCardExpiry?, notes? (encrypted)

  PanCardRecord
    - panNumber (validated ^[A-Z]{5}[0-9]{4}[A-Z]$, masked), nameOnCard,
      fathersName?, dateOfBirth?, cardImageBlob? (encrypted)

  CreditCardRecord
    - nickname, cardNetwork (Visa/Mastercard/RuPay/Amex), last4,
      expiryMonth, expiryYear, issuingBank
    - No full card number, no CVV, no PIN — matches debit-card rule above.

  SecureDocumentRecord
    - nickname
    - category: personalId | incomeProof | taxCredit | investmentProof |
      hra | capitalGains | homeLoan | other
      (taxonomy driven by Indian ITR filing document checklist: personalId
      covers Aadhaar-type refs, incomeProof covers Form 16/16A/16B/16C,
      taxCredit covers Form 26AS/AIS/TIS, investmentProof covers 80C/80D/80E/80G
      receipts, hra covers rent receipts/agreements, capitalGains covers
      brokerage/sale-deed statements, homeLoan covers interest certs/property
      tax receipts)
    - linkedAccountNickname? (optional string ref → BankAccountRecord.nickname,
      e.g. an FD interest statement linked to the account it came from)
    - custom key/value fields (free-form, extensible — new document types are
      new category values or `other` + custom fields, no schema migration)
    - attachmentBlob? (encrypted scanned doc/PDF/image)
    - notes? (encrypted)
```

All four record types share a `nickname` convention as their public-facing
handle within the module; `BankAccountRecord.nickname` is additionally the
canonical reference other Coin features and records point to (enforced unique
at the repository layer).

## Crypto Architecture

- **KEK (key-encryption key):** stored via `core_data`'s existing
  `FlutterSecureStore` (`flutter_secure_storage`, already Keystore/Keychain-backed).
  `platform_coin_vault` implements `EncryptionKeyManager` on top of it, adding
  biometric gating via `local_auth` (new dependency — flags dependency
  governance review) before every unlock.
- **DEK (data-encryption key):** AES-256 key generated once, wrapped by the
  KEK, decrypted into memory only after a successful biometric prompt. Never
  persisted unwrapped. Cleared from memory on app background or after the
  auto-lock timeout expires (auto-lock itself is a `feature_coin` concern;
  this layer just exposes a `lock()`/session-expiry hook).
- **Field-level encryption:** every sensitive column (account number, PAN,
  card refs, notes, attachment blobs) is individually AES-256-GCM encrypted
  with the DEK before insert, decrypted only within an unlocked session.
  Non-sensitive metadata (record type, nickname, category, created_at) stays
  plaintext for querying/sorting/filtering.
- **Database:** plain `sqflite` (already a `core_data` dependency) — no
  SQLCipher, no second sqlite native runtime. The DB file holds ciphertext in
  sensitive columns; the "encryption at rest" guarantee comes from field-level
  AES-GCM, not full-disk DB encryption.
- **Biometric enrollment change:** invalidates the KEK (key aliasing), forcing
  re-authentication; `isEncryptionAvailable()` returns false and vault
  creation is blocked when no biometrics are enrolled on the device at all.

## Package Structure

```
platform_coin_vault/
  lib/src/
    crypto/     # EncryptionKeyManager impl, biometric gate, AES-256-GCM field cipher
    domain/     # BankAccountRecord, PanCardRecord, CreditCardRecord,
                # SecureDocumentRecord, validators (IFSC, PAN regex)
    data/       # sqflite tables, repository implementations
  module.yaml
```

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
```

## Threat Model (ADR companion)

A short ADR, `docs/adr/00XX-airo-coin-vault-crypto.md`, will accompany
implementation, covering:

- **In scope:** lost/stolen device (biometric gate + Keystore/Keychain
  hardware backing defends this), rooted/jailbroken device malware short of
  hardware key extraction, shoulder-surfing (masked-by-default fields).
- **Explicitly out of scope:** hardware/chip-off attacks, nation-state-level
  adversaries, cloud sync/backup compromise (no cloud sync exists in v1).

## Testing

- Unit: crypto roundtrip (encrypt → decrypt) for every field type, KEK
  wrap/unwrap, IFSC/PAN validators, category enum coverage for
  `SecureDocumentRecord`.
- Repository tests against an in-memory/test sqflite DB for all four record
  types, including the `linkedAccountNickname` reference and nickname
  uniqueness constraint on `BankAccountRecord`.
- No-biometrics-enrolled path: vault creation must be blocked with a clear
  error, not silently no-op.

## Deliverables

- [ ] ADR: vault crypto design + threat model (chief-security-officer review)
- [ ] `platform_coin_vault` package skeleton per `module.yaml` governance
- [ ] `EncryptionKeyManager` impl: KEK/DEK, `FlutterSecureStore` + `local_auth`
      biometric gate
- [ ] `EncryptedDatabase`/repository impl for all four record types
      (field-level AES-256-GCM)
- [ ] Validators: IFSC, PAN regex
- [ ] Unit tests: crypto roundtrip, validators, repositories, no-biometrics path

## Deferred to `feature_coin` (separate design)

- Lock screen, list/add/edit UI, masking, tap-to-reveal, copy-with-auto-clear
- `FLAG_SECURE`, auto-lock timer, clipboard auto-clear
- `airomoney` → `airo_coin` package rename/gut
- Super-app shell wiring (new nav destination alongside Airo TV)
