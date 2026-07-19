// packages/platform_coin_vault/lib/platform_coin_vault.dart
// Barrel export for platform_coin_vault. Populated as domain/crypto/data
// layers land in later tasks.

export 'src/domain/validators/ifsc_validator.dart';
export 'src/domain/validators/pan_validator.dart';
export 'src/domain/entities/bank_account_record.dart';
export 'src/domain/entities/pan_card_record.dart';
export 'src/domain/entities/credit_card_record.dart';
export 'src/domain/entities/secure_document_record.dart';
export 'src/crypto/field_cipher.dart';
export 'src/crypto/vault_secure_storage.dart';
export 'src/crypto/vault_key_manager.dart';
export 'src/data/vault_database.dart';
export 'src/data/bank_account_repository.dart';
export 'src/data/pan_card_repository.dart';
export 'src/data/credit_card_repository.dart';
export 'src/data/secure_document_repository.dart';
