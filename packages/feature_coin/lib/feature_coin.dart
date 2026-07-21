/// Airo Coin vault presentation layer — biometric-gated secure record vault.
///
/// Built on `platform_coin_vault` (crypto/storage). Design spec:
/// docs/superpowers/specs/2026-07-20-feature-coin-design.md
library;

export 'src/application/vault_config.dart';
export 'src/application/clipboard_service.dart';
export 'src/application/screen_security.dart';
export 'src/application/vault_providers.dart';
export 'src/application/vault_record_reader.dart';
export 'src/application/vault_record_ref.dart';
export 'src/application/vault_session.dart';
export 'src/application/vault_summaries_provider.dart';
export 'src/presentation/screens/vault_gate_screen.dart';
export 'src/presentation/screens/vault_home_screen.dart';
export 'src/presentation/screens/vault_record_form_screen.dart';
export 'src/presentation/widgets/masked_vault_field.dart';
export 'src/presentation/widgets/record_detail_sheet.dart';
export 'src/presentation/widgets/vault_lifecycle_observer.dart';
