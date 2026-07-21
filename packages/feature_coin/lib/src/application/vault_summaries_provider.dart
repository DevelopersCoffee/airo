import 'package:core_domain/core_domain.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import 'vault_providers.dart';

final class VaultSummaries extends Equatable {
  const VaultSummaries({
    this.bankAccounts = const [],
    this.panCards = const [],
    this.creditCards = const [],
    this.secureDocuments = const [],
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

  int get count =>
      bankAccounts.length +
      panCards.length +
      creditCards.length +
      secureDocuments.length;

  @override
  List<Object?> get props => [
    bankAccounts,
    panCards,
    creditCards,
    secureDocuments,
  ];
}

final vaultSummariesProvider = FutureProvider<VaultSummaries>((ref) async {
  final repositories = await ref.watch(vaultRepositoriesProvider.future);
  return VaultSummaries(
    bankAccounts: _valueOrThrow(
      await repositories.bankAccounts.listAllSummaries(),
    ),
    panCards: _valueOrThrow(await repositories.panCards.listAllSummaries()),
    creditCards: _valueOrThrow(
      await repositories.creditCards.listAllSummaries(),
    ),
    secureDocuments: _valueOrThrow(
      await repositories.secureDocuments.listAllSummaries(),
    ),
  );
});

T _valueOrThrow<T>(Result<T> result) {
  if (result case Success<T>(:final value)) {
    return value;
  }
  throw result.failure;
}
