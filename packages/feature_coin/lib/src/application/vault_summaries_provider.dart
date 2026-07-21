import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import 'vault_providers.dart';

/// Aggregated, key-free summaries for the vault home list. Loading this
/// provider performs no decryption; summaries are built from unencrypted
/// columns only.
final class VaultSummaries {
  const VaultSummaries({
    required this.bankAccounts,
    required this.panCards,
    required this.creditCards,
    required this.secureDocuments,
  });

  final List<BankAccountSummary> bankAccounts;
  final List<PanCardSummary> panCards;
  final List<CreditCardSummary> creditCards;
  final List<SecureDocumentSummary> secureDocuments;

  bool get isEmpty =>
      bankAccounts.isEmpty &&
      panCards.isEmpty &&
      creditCards.isEmpty &&
      secureDocuments.isEmpty;
}

final vaultSummariesProvider = FutureProvider<VaultSummaries>((ref) async {
  final repos = await ref.watch(vaultRepositoriesProvider.future);

  final bankAccounts = await repos.bankAccounts.listAllSummaries();
  final panCards = await repos.panCards.listAllSummaries();
  final creditCards = await repos.creditCards.listAllSummaries();
  final secureDocuments = await repos.secureDocuments.listAllSummaries();

  final errorMessage = bankAccounts.isFailure
      ? bankAccounts.failure.message
      : panCards.isFailure
      ? panCards.failure.message
      : creditCards.isFailure
      ? creditCards.failure.message
      : secureDocuments.isFailure
      ? secureDocuments.failure.message
      : null;
  if (errorMessage != null) {
    throw Exception(errorMessage);
  }

  return VaultSummaries(
    bankAccounts: bankAccounts.value,
    panCards: panCards.value,
    creditCards: creditCards.value,
    secureDocuments: secureDocuments.value,
  );
});
