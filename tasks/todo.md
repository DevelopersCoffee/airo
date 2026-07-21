# feature_coin UI Phase 0 Tasks

- [x] Task 1: Add typed UI refs, summary aggregation, and screen-security service.
  - Acceptance: Home data can be loaded from all four summary repositories without a DEK.
  - Verify: `cd packages/feature_coin && flutter test test/application`
  - Files: `packages/feature_coin/lib/src/application/*`

- [x] Task 2: Add lock gate and grouped home list widgets.
  - Acceptance: Locked, unavailable, auth-error, and unlocked states render deterministically.
  - Verify: `cd packages/feature_coin && flutter test test/presentation`
  - Files: `packages/feature_coin/lib/src/presentation/screens/*`

- [x] Task 3: Add masked detail sheet with reveal/copy.
  - Acceptance: Sensitive fields are masked by default and reveal only through `withKey`.
  - Verify: widget test for detail reveal and copy delegation.
  - Files: `packages/feature_coin/lib/src/presentation/widgets/*`

- [x] Task 4: Add add/edit forms.
  - Acceptance: Valid records persist; invalid PAN/IFSC and duplicate nickname failures show inline errors.
  - Verify: widget tests for form validation and save paths.
  - Files: `packages/feature_coin/lib/src/presentation/screens/*`, `packages/feature_coin/lib/src/presentation/widgets/forms/*`

- [x] Task 5: Export UI and clean stale key-manager docs.
  - Acceptance: Public `feature_coin.dart` exports the Phase 0 UI surface and `generateCandidateKey()` docs name `persistRotatedKeyUnauthenticated`.
  - Verify: `cd packages/platform_coin_vault && flutter test test/crypto/vault_key_manager_test.dart`
  - Files: `packages/feature_coin/lib/feature_coin.dart`, `packages/platform_coin_vault/lib/src/crypto/vault_key_manager.dart`

- [x] Task 6: Shell wiring and focused validation.
  - Acceptance: `/money/vault` opens the vault gate, the app depends on `feature_coin` instead of stale `airomoney`, and focused checks complete.
  - Verify: `cd packages/feature_coin && flutter test`; `cd packages/feature_coin && dart analyze`; focused app analyze/test; `git diff --check`
