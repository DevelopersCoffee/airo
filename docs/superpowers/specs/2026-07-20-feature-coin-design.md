# feature_coin — Airo Coin Vault Presentation Layer

**Date:** 2026-07-20
**Status:** Approved (brainstorming)
**Builds on:** `2026-07-19-airo-coin-vault-design.md` (crypto/storage spec), `docs/adr/0009-airo-coin-vault-crypto.md` (Accepted)
**Modules:** `packages/platform_coin_vault` (extension), `packages/airomoney` → `packages/feature_coin` (rename-refactor), `app/` shell wiring

## Background

`platform_coin_vault` (PRs #944/#946/#947) shipped biometric-gated AES-256-GCM field
encryption over sqflite with four record types: `BankAccountRecord`, `PanCardRecord`,
`CreditCardRecord` (masked-only), `SecureDocumentRecord` (ITR category taxonomy).
Everything in the original spec's "Deferred to feature_coin" section is built here:
lock screen, list/add/edit UI, masking/reveal/copy, FLAG_SECURE, auto-lock, shell
wiring, and the `airomoney` rename.

### Confirmed gaps in the platform layer (verified 2026-07-20)

- Repositories expose only `create()` + `getByNickname()` — **no list, update, or delete**.
- **No session/`lock()` hook exists** (the vault spec promised one; it was never built).
  The DEK is returned as a raw `List<int>` per call.
- `VaultKeyManager.rotateKey()` is destructive (no re-encryption migration). **It must
  not be wired to any UI action** until that migration exists.
- `packages/airomoney` is ~2,130 lines of dead mock ₹-wallet UI with zero imports in
  `app/lib`; the home-screen "AiroMoney" card navigates to an unregistered route (404).

## Decisions (locked during brainstorming)

1. **Extend `platform_coin_vault` first** with list/update/delete rather than having
   feature_coin query the DB directly. Framework-owned change → council review.
2. **feature_coin owns the DEK session** (`VaultSession` Riverpod notifier): cache after
   biometric unlock, zero on 60 s idle timer / app background / manual lock.
3. **Rename-refactor, don't delete**: `git mv packages/airomoney → packages/feature_coin`
   (history preserved); mock internals gutted; reusable pieces kept only if consumed.
4. **Vault lives inside the existing Coins tab** as a "Secure Vault" entry — no new
   top-level nav destination. Existing coins import/review-queue features untouched.
5. **Attachments deferred**: `SecureDocumentRecord.attachmentBlob` is not exposed in the
   v1 UI (blob round-trip in the repo layer is fragile for binary; isolate policy
   implications). Platform field remains for a later iteration.
6. **Package name: `feature_coin`** (repo `feature_*` convention).
7. **Summary-first, reveal-on-demand**: list screens render from unencrypted columns
   only; sensitive fields decrypt individually on explicit reveal/edit and are dropped
   when dismissed. No full-record decrypt on unlock.

## Architecture

### Slice 1 — `platform_coin_vault` extension (framework)

New domain projections, built only from **unencrypted columns** (no `keyBytes` needed):

```dart
sealed class VaultEntrySummary { String get nickname; }
class BankAccountSummary   // nickname, bankName, ifsc, accountHolderName
class PanCardSummary       // nickname, holderName
class CreditCardSummary    // nickname, last4, network, issuingBank, expiry
class SecureDocumentSummary// nickname, title, category, linkedAccountNickname?
```

New repository methods on all four repos:

```dart
Future<Result<List<BankAccountSummary>>> listAllSummaries();
Future<Result<void>> update(BankAccountRecord record, List<int> keyBytes);
Future<Result<void>> deleteByNickname(String nickname);
```

(`CreditCardRepository` variants take no `keyBytes` — nothing encrypted.)

`update` re-encrypts sensitive fields under the existing DEK (no key rotation).
`deleteByNickname` is a plain row delete. Schema version stays 1 — no migration.

### Slice 2 — rename + session core

- `git mv packages/airomoney packages/feature_coin`; update `pubspec.yaml` name,
  barrel file, `module.yaml` (from `template_feature`; allowed deps:
  `platform_coin_vault`, `core_ui`, `core_domain`, `flutter_riverpod`, `local_auth`,
  `flutter_windowmanager`, `screen_protector`).
- Gut mock screens/models. INR formatting helpers survive only if consumed by the
  vault or existing `app/lib/features/money` code; otherwise removed (recoverable
  from git history).

**`VaultSession` (Riverpod `Notifier`)** — states:
`locked / unlocking / unlocked / unavailable / authError`.

- `unlock()`: `isEncryptionAvailable()` gate first (ADR fail-closed contract) →
  `getDatabaseKey()` → DEK held **privately** in the notifier.
- The DEK never enters widget/provider state. All sensitive access goes through:

```dart
Future<T> withKey<T>(Future<T> Function(List<int> keyBytes) op);
```

- `lock()`: zeroes the DEK list in place, cancels the idle timer, state → `locked`.
- Lock triggers: 60 s idle timer (reset on any vault interaction — reveal, copy,
  form input, in-vault navigation), `AppLifecycleListener` background/inactive,
  manual lock button in the vault app bar.
- Constants (`autoLockSeconds = 60`, `clipboardClearSeconds = 30`) live in one config
  file for later configurability.

**`ClipboardService`** — copy-with-auto-clear: schedules a 30 s compare-and-clear
(only wipes the clipboard if the content is unchanged, so newer user copies survive).

### Slice 3 — vault UI

- **LockScreen**: auto-triggers the OS biometric prompt on entry (device-credential
  fallback per platform layer; never a custom in-app PIN). Tap-to-retry. `AuthFailure`
  is a hard-stop message, never a silent retry. `unavailable` state (no biometrics
  enrolled) shows guidance to enroll in system settings — no vault creation offered.
- **VaultHomeScreen**: grouped list (Bank Accounts / PAN Cards / Cards / Documents)
  rendered from `listAllSummaries()`; per-group empty states; FAB → add-type picker.
  No decryption occurs on this screen.
- **RecordDetailSheet**: every sensitive field masked by default (`••••`, last4 where
  the record model supports it); per-field eye-icon reveal via `withKey`; per-field
  copy via `ClipboardService`; Edit action; Delete behind a confirmation dialog **plus
  a fresh OS biometric prompt** (`local_auth` directly).
- **RecordFormScreens** (add/edit, one per record type):
  - IFSC/PAN validated by the platform validators — constructor `ArgumentError` is
    caught and mapped to an inline field error.
  - Credit-card form offers only masked-only fields (network, last4, expiry, issuing
    bank). No full PAN/CVV/PIN fields anywhere.
  - Document form: ITR-category dropdown (fixed enum), optional linked-account picker
    (from bank-account summaries), key-value custom-fields editor. No attachment picker.
- Theme/widgets from `core_ui`; `core_ui` goldens conventions apply.

### Slice 4 — shell wiring

- Vault routes register under the existing Money/Coins `StatefulShellBranch`:
  `/money/vault`, `/money/vault/add/:type`, `/money/vault/:nickname`.
- Coins home (`app/lib/features/coins`) gains a "Secure Vault" entry card.
- Dead "AiroMoney" card on the app home screen (`home_screen.dart:124`) repointed to
  `/money`; `RouteNames.airomoney` removed.
- `feature_coin` replaces `airomoney` in `app/pubspec.yaml` and
  `app/pubspec_ios_spm.yaml`; `app/pubspec_tv.yaml` untouched (vault stays off TV per
  the vault spec's phone/iPad-only decision).
- **FLAG_SECURE** on Android (`flutter_windowmanager`) and iOS app-switcher snapshot
  shield (`screen_protector`) enabled while any `/money/vault*` route is visible,
  disabled on exit.

## Error handling

- All repo/session calls are `Result`-typed via `core_domain`.
- `AuthFailure` → hard-stop screen (ADR risk contract: no silent retries).
- `ValidationFailure` (duplicate nickname) → inline form error on the nickname field.
- Decrypt failure (`SecretBoxAuthenticationError`, e.g. biometric enrollment changed
  and the KeyStore invalidated the DEK) → "vault data unreadable" error view with an
  explicit, user-confirmed reset path. Never auto-wipes; `rotateKey` is not involved.

## Security behaviors (summary)

| Behavior | Value |
|---|---|
| Masking | Default; per-field reveal only |
| Clipboard | 30 s compare-and-clear |
| Auto-lock | 60 s idle; also on app background + manual |
| Screenshots/recents | FLAG_SECURE (Android), snapshot shield (iOS) while in vault |
| Delete | Confirmation dialog + fresh biometric prompt |
| Biometrics | OS prompt with device-credential fallback; never custom PIN |
| `rotateKey()` | Not exposed in UI (destructive until re-encryption migration exists) |

## Testing

- **Slice 1**: `listAll/update/delete` round-trip tests via `sqflite_ffi` in-memory
  (existing `platform_coin_vault` pattern); summary projections contain no sensitive
  field values (regression guard).
- **Slice 2**: `VaultSession` notifier tests using the `VaultKeyManager.forTesting`
  seam + `fakeAsync` for the idle timer; lifecycle-triggered lock; DEK zeroed on lock;
  `ClipboardService` compare-and-clear with mocked `Clipboard`.
- **Slice 3**: widget tests for lock-screen states, masked-by-default rendering,
  reveal-on-tap, form validation errors; `ProviderContainer` overrides; alchemist
  goldens for LockScreen/VaultHomeScreen/RecordDetailSheet.
- **Slice 4**: route registration smoke test; pubspec dep checks.
- Isolate policy: no payloads >50 KB in v1 (attachments deferred) — `runOffMain()`
  not required; noted for the attachment iteration.

## Process / governance

- GitHub issue with deterministic use cases + automation flows before implementation
  (AGENTS.md agent lifecycle). Owner: application agent for feature_coin, framework
  agent + council review for the platform_coin_vault extension; CSO review for
  module.yaml/security surface.
- Worktree: `.worktrees/feature-coin`, branch `feature/feature-coin` from
  `origin/main` @ e25a0a78.
- `[skip ci]` on iterative commits; focused local validation (format, analyze,
  targeted tests, `git diff --check`) before any push; four slices land as separate
  PRs.
- Parallel-work check performed 2026-07-20: no open PRs overlap; related branches
  (#944/#946/#947, coins import toggles) all merged.

## Out of scope (v1)

- Cloud sync/backup, bank aggregation (AA), transactions, balances (unchanged from
  vault spec).
- Secure-document attachments (deferred; blob round-trip + isolate handling first).
- Key rotation UI (blocked on re-encryption migration in the platform layer).
- TV/desktop targets; search/filter; configurable auto-lock/clipboard durations
  (constants in place for later).
