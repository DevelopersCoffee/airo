# Airo Coin parity check

Date: 2026-07-22

## Outcome

Airo Coin is now documented as package-first. Active vault code belongs in
`packages/feature_coin` and `packages/platform_coin_vault`; the super-app only
embeds it through route and dashboard wiring.

## Current homes

| Area | Current home | Status |
| --- | --- | --- |
| Vault storage, crypto, validators, repositories | `packages/platform_coin_vault` | Pass |
| Vault UI, session, forms, lock/unavailable/auth-error screens | `packages/feature_coin` | Pass |
| Super-app route and card embedding | `app/lib/core/routing`, `app/lib/features/coins/presentation/screens/coins_dashboard_screen.dart`, `app/lib/features/home/presentation/screens/home_screen.dart` | Pass: shell wiring only |
| iOS SPM profile dependency resolution | `app/pubspec_ios_spm.yaml` | Fixed: `go_router` now matches `feature_coin`'s range |
| Airo Pro coin contract | `packages/core_entitlements` | Fixed: reserved `coin_encrypted_backup_restore` |
| Retired package residue | `packages/airomoney` | Fixed: tracked lockfile removed |
| Legacy super-app finance implementation | `app/lib/features/coins` | Not moved in this patch; treat as extraction source only |

## Do not add new code here

`app/lib/features/coins` contains old super-app finance entities, repositories,
services, and screens. It is not the focused Airo Coin module. New Airo Coin
work must go to `packages/feature_coin`, `packages/platform_coin_*`, coin
plugin packages, or the `airo-pro` coin overlay.

## Remaining migration work

- Add a standalone Airo Coin entrypoint once product packaging is ready.
- Decide which old super-app finance workflows are still product-relevant.
- Extract reusable kept workflows from `app/lib/features/coins` into package
  homes, then delete the app-layer originals.
- Implement the private `airo-pro` coin backup/restore overlay against
  `ProFeature.coinEncryptedBackupRestore`.
