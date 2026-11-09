# feature_coin

Airo Coin vault presentation layer: biometric-gated lock screen, masked
list/detail UI, and add/edit forms for bank accounts, PAN cards, credit
cards (masked-only), and ITR-categorized secure documents.

Crypto/storage lives in `platform_coin_vault`. This package owns the DEK
session (auto-lock), clipboard auto-clear, and screen security.

The standalone Airo Coin shell (`app/lib/main_coins.dart`) mounts this package for
`/money/vault` only. Shared expenses (groups, splits, settle-up) remain in the app
composition layer until package-first migration — see ADR-0010 and
`app/lib/core/coins/coins_standalone_home.dart` ([#2091](https://github.com/DevelopersCoffee/airo/pull/2091)).
