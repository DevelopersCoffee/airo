/// Airo Coin vault presentation layer — biometric-gated secure record vault.
///
/// Built on `platform_coin_vault` (crypto/storage). Design spec:
/// docs/superpowers/specs/2026-07-20-feature-coin-design.md
library;

export 'src/application/vault_config.dart';
export 'src/application/clipboard_service.dart';
export 'src/application/vault_providers.dart';
export 'src/application/vault_session.dart';
export 'src/domain/vault_record_type.dart';
export 'src/presentation/screens/vault_lock_screen.dart';
export 'src/presentation/widgets/vault_lifecycle_observer.dart';
