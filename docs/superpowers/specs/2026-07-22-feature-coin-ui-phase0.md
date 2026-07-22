# Spec: feature_coin UI Phase 0

## Assumptions

1. This slice builds the standalone `feature_coin` UI package first, then wires the tested gate into the app Money branch at `/money/vault`.
2. The merged `platform_coin_vault` API is the source of truth for records, summaries, validation, encryption, and CRUD.
3. PAN cards use row `id` as their UI handle because the platform table has no nickname column.
4. Attachments, vault reset, key rotation UI, cloud sync, transactions, balances, and TV surfaces remain out of scope.

## Objective

Build the first usable Airo Coin secure-vault UI: biometric lock gate, grouped vault list, add/edit forms for bank accounts, PAN cards, credit cards, and secure documents, masked detail/reveal/copy interactions, screen security, and auto-lock integration through the existing `VaultSessionNotifier`.

Success means a phone user can unlock the vault, see summaries without decrypting records, add a record, inspect sensitive fields only after reveal, copy values with auto-clear, and return to a locked state on timeout/background/manual lock.

## Tech Stack

- Flutter package: `packages/feature_coin`
- State: Riverpod 3.3.2 `Notifier` and `FutureProvider`
- Storage/crypto API: `platform_coin_vault`
- Shared UI: `core_ui`
- Native privacy: `screen_protector`
- Biometric prompt: `local_auth` via `VaultKeyManager`; destructive delete re-prompt deferred unless `local_auth` can be tested cleanly in this slice

## Commands

- Package dependencies: `cd packages/feature_coin && flutter pub get`
- Package tests: `cd packages/feature_coin && flutter test`
- Package analyze: `cd packages/feature_coin && dart analyze`
- Platform cleanup test: `cd packages/platform_coin_vault && flutter test test/crypto/vault_key_manager_test.dart`
- Diff hygiene: `git diff --check`

## Project Structure

- `packages/feature_coin/lib/src/application/` -> providers, aggregation, screen-security wrapper, save/load operations
- `packages/feature_coin/lib/src/presentation/screens/` -> lock gate, home list, form screens
- `packages/feature_coin/lib/src/presentation/widgets/` -> masked field/detail/list/form widgets
- `packages/feature_coin/test/` -> widget and application tests with provider overrides
- `app/lib/core/routing/` and `app/lib/features/coins/` -> `/money/vault` shell wiring
- `packages/platform_coin_vault/lib/src/crypto/vault_key_manager.dart` -> stale doc-comment cleanup only

## Code Style

Use small, typed UI models and keep the DEK out of widget state.

```dart
final record = await ref.read(vaultSessionProvider.notifier).withKey(
  (keyBytes) => repositories.bankAccounts.getByNickname(nickname, keyBytes),
);
```

Forms should catch platform `ArgumentError` validation and show inline field errors. List screens must consume summary projections only and must not call `withKey`.

## Testing Strategy

- Widget tests cover lock states, grouped empty/list rendering, masked-by-default fields, reveal/copy behavior, and form validation.
- Application tests cover summary aggregation and screen-security controller behavior with test doubles.
- Existing session and clipboard tests remain authoritative for auto-lock and clipboard timer internals.
- Physical Android verification is required later for real `FLAG_SECURE`, screenshots, and biometric prompt behavior; this slice provides a testable wrapper.

## Boundaries

- Always: mask sensitive values by default, use `withKey` for decrypting records, refresh summaries after mutations, keep PAN keyed by id.
- Ask first: new dependencies, database/schema changes, attachment handling, app-wide navigation redesign, custom PIN fallback, vault reset/delete-all flow.
- Never: expose full card numbers/CVV/PIN, call destructive `rotateKey()`, decrypt full records for the home list, log vault field values, write sensitive values to provider state.

## Success Criteria

- `VaultGateScreen` switches locked/unlocking/unavailable/error/unlocked states deterministically.
- `VaultHomeScreen` renders grouped summaries from all four repositories without requiring key bytes.
- Add/edit forms persist valid records and show inline errors for invalid PAN/IFSC or duplicate nicknames.
- Detail UI masks sensitive fields by default, reveals through `VaultSessionNotifier.withKey`, and copies via `ClipboardService`.
- Screen security is enabled while the gate is mounted and disabled on dispose through an injectable controller.
- Stale `generateCandidateKey()` documentation references `persistRotatedKeyUnauthenticated`.
- Focused package tests and analyzer pass, or gaps are documented.

## Open Questions

- Deeper app navigation for direct add/edit URLs remains a follow-up after the package UI is exercised.
- Real device verification is still needed for native screenshot blocking and biometric prompt UX.
