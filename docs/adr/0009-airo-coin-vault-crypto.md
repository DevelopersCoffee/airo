# ADR-0009: Airo Coin vault crypto design and threat model

## Status

Accepted

## Date

2026-07-20

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
- **KEK boundary**: `flutter_secure_storage`, backed by Android Keystore /
  iOS Keychain, configured for biometric binding —
  `AndroidOptions.biometric(enforceBiometrics: true)` (KeyStore key generated
  with `setUserAuthenticationRequired(true)`) and
  `IOSOptions(accessControlFlags: [AccessControlFlag.biometryCurrentSet])`
  (Secure Enclave key gated by `kSecAccessControlBiometryCurrentSet`). The
  DEK is generated once and persisted through this boundary — we do not
  implement a separate explicit key-wrap step.
- **App-layer biometric gate**: `local_auth`, with OS-provided
  device-credential fallback (PIN/pattern/Face ID/fingerprint) — never a
  custom in-app PIN screen storing its own secret.
  `VaultKeyManager.getDatabaseKey()` and `.rotateKey()` both fail closed
  (`AuthFailure`) when authentication fails or is unavailable; there is no
  silent no-op path. This is defense-in-depth on top of the KeyStore-level
  biometric binding above — either layer failing blocks key access.

## Consequences

### Positive

- A compromised app process still needs the DEK (guarded by both the
  KeyStore/Keychain biometric binding and the app-layer `local_auth` gate) to
  read plaintext; a malicious app or rooted-device tool reading the raw
  sqlite file sees ciphertext only.
- Lost/stolen device is defended by the biometric gate plus hardware-backed
  KEK storage — the DEK is unreachable without a successful biometric (or OS
  device-credential fallback) authentication on the physical device.
- No second native sqlite runtime introduced — `sqflite` only, sidestepping
  the PR #925 dual-runtime bug class.

### Negative

- Field-level encryption means every sensitive column read/write pays an
  AES-GCM roundtrip, versus a single decrypt-on-open cost with full-database
  encryption (e.g. SQLCipher). Acceptable for a low-frequency personal
  finance vault, not for high-throughput tables.
- Any future addition of a new sensitive field must go through `FieldCipher`,
  not be added as a plaintext column — this is a review-time check for
  Chief Security Officer sign-off on future PRs touching
  `platform_coin_vault`.

### Risks

- `feature_coin` (the presentation layer, designed separately) inherits the
  fail-closed contract: it must call `isEncryptionAvailable()` before
  offering vault creation and must surface `AuthFailure` as a hard stop, not
  a retry-silently path. If a future contributor bypasses this, sensitive
  data could be created without a working biometric gate.
- **Out of scope, accepted**: hardware/chip-off attacks against the Secure
  Enclave/StrongBox themselves; nation-state-level adversaries; cloud
  sync/backup compromise (no cloud sync exists in v1 — no attack surface to
  defend yet). Shoulder-surfing is mitigated at the `feature_coin` UI layer
  (masking), not in this package — this package's encryption is the
  precondition that makes masking meaningful rather than cosmetic.

## Alternatives Considered

### Alternative 1: SQLCipher / full-database encryption

Would encrypt the entire database file with one key, decrypted on open.
Rejected because `platform_playlist` already ships `drift` +
`sqlite3_flutter_libs` as a second native sqlite runtime; adding SQLCipher
here would be a third, worsening the exact dual-runtime bug class fixed in
PR #925. Field-level encryption over plain `sqflite` avoids this entirely.

### Alternative 2: Custom in-app PIN/passphrase instead of OS biometrics

Would let the vault work on devices without biometric hardware. Rejected:
storing or verifying a custom PIN requires either a weaker, app-managed
secret or re-deriving the same OS Keystore/Keychain trust boundary we
already get for free via `local_auth` + `flutter_secure_storage`'s biometric
options. No security benefit, meaningfully more code to audit.

## Related Decisions

- None yet — first ADR for `platform_coin_vault`.

## References

- Tracking issue: #927 (DevelopersCoffee/airo)
- PR #925 — dual sqlite runtime bug fix (precedent for the "no second native
  DB runtime" constraint)
- `packages/platform_coin_vault/lib/src/crypto/field_cipher.dart`
- `packages/platform_coin_vault/lib/src/crypto/vault_key_manager.dart`
- `packages/platform_coin_vault/lib/src/crypto/vault_secure_storage.dart`
