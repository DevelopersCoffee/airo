# feature_coin

Airo Coin vault presentation layer: biometric-gated lock screen, masked
list/detail UI, and add/edit forms for bank accounts, PAN cards, credit
cards (masked-only), and ITR-categorized secure documents.

Crypto/storage lives in `platform_coin_vault`. This package owns the DEK
session (auto-lock), clipboard auto-clear, and screen security.

The standalone Airo Coin shell (`app/lib/main_coins.dart`) mounts this package for
`/money/vault` only. Shared expenses: hub and groups list live in
`app/lib/core/coins/`; group detail and settle-up route to legacy
`app/lib/features/coins/presentation/screens/group_detail_screen.dart` via
`/groups/:groupId` in `main_coins.dart` — see ADR-0010 ([#2091](https://github.com/DevelopersCoffee/airo/pull/2091)).
