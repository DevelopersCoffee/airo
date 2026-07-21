import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import 'vault_config.dart';

/// Opens (and on dispose, closes) the vault sqflite database. Tests override
/// this with an in-memory `sqflite_common_ffi` database.
final vaultDatabaseProvider = FutureProvider<VaultDatabase>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  final database = VaultDatabase();
  await database.open(path: p.join(dir.path, VaultConfig.databaseFileName));
  ref.onDispose(database.close);
  return database;
});

/// Aggregate handle for the four vault repositories.
final class VaultRepositories {
  const VaultRepositories({
    required this.bankAccounts,
    required this.panCards,
    required this.creditCards,
    required this.secureDocuments,
  });

  final BankAccountRepository bankAccounts;
  final PanCardRepository panCards;
  final CreditCardRepository creditCards;
  final SecureDocumentRepository secureDocuments;
}

final vaultRepositoriesProvider = FutureProvider<VaultRepositories>((
  ref,
) async {
  final database = await ref.watch(vaultDatabaseProvider.future);
  final cipher = FieldCipher();
  return VaultRepositories(
    bankAccounts: BankAccountRepository(
      database: database,
      fieldCipher: cipher,
    ),
    panCards: PanCardRepository(database: database, fieldCipher: cipher),
    creditCards: CreditCardRepository(database: database),
    secureDocuments: SecureDocumentRepository(
      database: database,
      fieldCipher: cipher,
    ),
  );
});

/// Biometric-gated DEK manager. Tests override with
/// `VaultKeyManager.forTesting`.
final vaultKeyManagerProvider = Provider<VaultKeyManager>((ref) {
  return VaultKeyManager(
    localAuth: LocalAuthentication(),
    secureStorage: VaultSecureStorage(),
  );
});

/// Raw `local_auth` handle for destructive-action re-prompts (delete).
final localAuthenticationProvider = Provider<LocalAuthentication>(
  (ref) => LocalAuthentication(),
);
