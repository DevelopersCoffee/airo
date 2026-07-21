import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import 'vault_providers.dart';
import 'vault_session.dart';

abstract interface class VaultRecordReader {
  Future<String?> revealBankAccountNumber(String nickname);
  Future<String?> revealBankNotes(String nickname);
  Future<String?> revealPanNumber(int id);
  Future<String?> revealDocumentNotes(String nickname);
}

final class RepositoryVaultRecordReader implements VaultRecordReader {
  const RepositoryVaultRecordReader({
    required this.readRepositories,
    required this.session,
  });

  final Future<VaultRepositories> Function() readRepositories;
  final VaultSessionNotifier session;

  @override
  Future<String?> revealBankAccountNumber(String nickname) {
    return _loadBank(nickname, (record) => record.accountNumber);
  }

  @override
  Future<String?> revealBankNotes(String nickname) {
    return _loadBank(nickname, (record) => record.notes);
  }

  @override
  Future<String?> revealPanNumber(int id) async {
    final repositories = await readRepositories();
    final result = await session.withKey(
      (keyBytes) => repositories.panCards.getById(id, keyBytes),
    );
    return _selectedValue(result, (record) => record.panNumber);
  }

  @override
  Future<String?> revealDocumentNotes(String nickname) async {
    final repositories = await readRepositories();
    final result = await session.withKey(
      (keyBytes) =>
          repositories.secureDocuments.getByNickname(nickname, keyBytes),
    );
    return _selectedValue(result, (record) => record.notes);
  }

  Future<String?> _loadBank(
    String nickname,
    String? Function(BankAccountRecord record) select,
  ) async {
    final repositories = await readRepositories();
    final result = await session.withKey(
      (keyBytes) => repositories.bankAccounts.getByNickname(nickname, keyBytes),
    );
    return _selectedValue(result, select);
  }

  String? _selectedValue<T>(
    Result<T?>? result,
    String? Function(T record) select,
  ) {
    if (result == null || result.isFailure) return null;
    final record = result.valueOrNull;
    if (record == null) return null;
    final value = select(record);
    return value == null || value.isEmpty ? 'Not set' : value;
  }
}

final vaultRecordReaderProvider = Provider<VaultRecordReader>((ref) {
  return RepositoryVaultRecordReader(
    readRepositories: () => ref.read(vaultRepositoriesProvider.future),
    session: ref.read(vaultSessionProvider.notifier),
  );
});
