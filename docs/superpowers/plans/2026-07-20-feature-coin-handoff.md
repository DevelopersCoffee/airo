# feature_coin — Session Handoff (2026-07-20)

**Status:** Design spec written, committed (`0e52f694`), and **approved by user**.
Do NOT re-brainstorm. Next step: implementation plan via `superpowers:writing-plans`,
then execution.

## Locations

- Worktree: `.worktrees/feature-coin`, branch `feature/feature-coin` (from `origin/main` @ e25a0a78)
- Approved spec: `docs/superpowers/specs/2026-07-20-feature-coin-design.md`
- Plan (to write): `docs/superpowers/plans/2026-07-20-feature-coin.md`
- Upstream: `docs/superpowers/specs/2026-07-19-airo-coin-vault-design.md`, `docs/adr/0009-airo-coin-vault-crypto.md`

## Locked decisions

1. **Slice 1 (framework, `platform_coin_vault`):** add `listAllSummaries()` (no-key
   summary projections from unencrypted columns only — new sealed `VaultEntrySummary`
   types), `update()`, `deleteByNickname()` to all 4 repos. **PAN cards are keyed by
   row id** (no nickname column) → `deleteById`, update via `record.id`. Schema stays
   v1, no migration. `rotateKey()` stays unwired (destructive — no re-encryption
   migration exists).
2. **Slice 2:** `git mv packages/airomoney → packages/feature_coin` (preserve history;
   gut mock UI — zero imports, dead code). feature_coin-owned `VaultSession` Riverpod
   `Notifier`: states locked/unlocking/unlocked/unavailable/authError; private DEK;
   `withKey()` accessor; zero DEK on lock; 60s idle timer + AppLifecycle background +
   manual lock. `ClipboardService` with 30s compare-and-clear.
3. **Slice 3 (UI):** VaultGate/LockScreen (auto biometric prompt, fail-closed,
   no-biometrics empty state), VaultHomeScreen grouped list (no decryption),
   RecordDetailSheet (masked default, reveal-on-demand via `withKey`,
   copy-with-auto-clear, delete = confirm dialog + fresh biometric), add/edit forms
   for 4 types (IFSC/PAN validators, credit card masked-only fields, doc ITR-category
   dropdown + linked-account picker + custom-fields editor). **No attachments in v1.**
4. **Slice 4 (shell):** vault routes under existing Money/Coins branch
   (`/money/vault…`), "Secure Vault" entry card in `CoinsDashboardScreen`, repoint
   dead "AiroMoney" card in `home_screen.dart` (currently 404s) to `/money`, remove
   `RouteNames.airomoney`, swap `airomoney` → `feature_coin` in `app/pubspec.yaml` +
   `app/pubspec_ios_spm.yaml` (NOT `pubspec_tv.yaml`), FLAG_SECURE via
   `screen_protector` while vault routes visible.
5. **Reveal-on-demand:** list never touches the DEK; sensitive fields decrypt
   individually on reveal/edit, dropped when dismissed.

## Verified repo facts (for the plan)

- Repos: `{required VaultDatabase database, required FieldCipher fieldCipher}`
  (credit card: no cipher); `FieldCipher()` no-arg ctor.
- `Result<T>` (core_domain): `Success(value)` / `Failure(failure)`; failures:
  `ValidationFailure(field:)`, `AuthFailure`, `DatabaseFailure`, `CacheFailure`,
  `NotFoundFailure(resourceType:, resourceId:)`.
- Test pattern: `sqfliteFfiInit()` + `VaultDatabase(databaseFactory: databaseFactoryFfi)`
  + `inMemoryDatabasePath` (see `packages/platform_coin_vault/test/data/bank_account_repository_test.dart`);
  `VaultKeyManager.forTesting(secureStorage:, authenticate:, isAvailable:)` seam.
- Riverpod 3.3.2 (`NotifierProvider`/`Notifier`); `core_ui` exports
  `EmptyStateWidget(message:, title:, icon:, action:)` and
  `ErrorView(message:, title:, icon:, onRetry:, retryLabel:)`; alchemist for goldens;
  mocktail available.
- Dep versions: `local_auth: ^2.3.0`, `path_provider: ^2.1.6`, `path: 1.9.1`,
  `sqflite_common_ffi: ^2.3.6` (dev), `flutter_riverpod: 3.3.2`, `equatable: ^2.0.8`,
  `flutter_lints: 6.0.0` / `mocktail: ^1.0.5` (dev).
- module.yaml template: `packages/template_feature/module.yaml`; feature_coin allowed
  deps: core_domain, core_ui, platform_coin_vault.
- Record quirks: `pan_cards` table has NO nickname (id-keyed);
  `SecureDocumentRecord.createdAt` is required (no default); `CreditCardRecord.createdAt`
  required; `BankAccountRecord`/`PanCardRecord` constructors throw `ArgumentError` on
  invalid IFSC/PAN (form-layer try/catch).

## Process (AGENTS.md)

- Task 0: GitHub issue with deterministic use cases + automation flows before
  implementation.
- `[skip ci]` on iterative commits; focused local validation only (format, analyze,
  targeted tests, `git diff --check`).
- 4 slices land as separate PRs (stack slice branches if earlier slice not yet merged).
- Isolate policy: no >50KB payloads in v1 → no `runOffMain()` needed yet.
- Baseline verified 2026-07-20: 50/50 `platform_coin_vault` tests pass; no open PRs
  overlap (parallel-work check done).
