// ignore_for_file: avoid_unused_constructor_parameters

/// Stub for CoinsLocalDatasourceImpl on web platform.
/// Coins feature is not supported on web (throws UnimplementedError).
library;

import 'coins_local_datasource.dart';

/// Stub implementation - throws on all operations.
/// On web, the provider throws UnimplementedError before this is used.
class CoinsLocalDatasourceImpl implements CoinsLocalDatasource {
  CoinsLocalDatasourceImpl(dynamic db);

  Never _unsupported() =>
      throw UnimplementedError('Coins not supported on web');

  @override
  Future<TransactionEntity?> getTransactionById(String id) => _unsupported();

  @override
  Future<List<TransactionEntity>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) => _unsupported();

  @override
  Future<List<TransactionEntity>> getTransactionsByAccount(String accountId) =>
      _unsupported();

  @override
  Future<List<TransactionEntity>> getTransactionsByCategory(
    String categoryId,
  ) => _unsupported();

  @override
  Future<void> insertTransaction(TransactionEntity entity) => _unsupported();

  @override
  Future<void> updateTransaction(TransactionEntity entity) => _unsupported();

  @override
  Future<void> softDeleteTransaction(String id) => _unsupported();

  @override
  Future<void> hardDeleteTransaction(String id) => _unsupported();

  @override
  Future<void> restoreTransaction(String id) => _unsupported();

  @override
  Stream<List<TransactionEntity>> watchAllTransactions() =>
      Stream.error(_unsupported());

  @override
  Stream<List<TransactionEntity>> watchTransactionsByCategory(
    String categoryId,
  ) => Stream.error(_unsupported());

  @override
  Stream<List<TransactionEntity>> watchTransactionsByDate(DateTime date) =>
      Stream.error(_unsupported());

  @override
  Future<int> getTotalSpent(DateTime start, DateTime end) => _unsupported();

  @override
  Future<Map<String, int>> getSpentByCategory(DateTime start, DateTime end) =>
      _unsupported();

  @override
  Future<List<TransactionEntity>> searchTransactions(String query) =>
      _unsupported();

  @override
  Future<BudgetEntity?> getBudgetById(String id) => _unsupported();

  @override
  Future<BudgetEntity?> getBudgetByCategory(String categoryId) =>
      _unsupported();

  @override
  Future<List<BudgetEntity>> getActiveBudgets() => _unsupported();

  @override
  Future<List<BudgetEntity>> getAllBudgets() => _unsupported();

  @override
  Future<void> insertBudget(BudgetEntity entity) => _unsupported();

  @override
  Future<void> updateBudget(BudgetEntity entity) => _unsupported();

  @override
  Future<void> deactivateBudget(String id) => _unsupported();

  @override
  Future<void> deleteBudget(String id) => _unsupported();

  @override
  Stream<List<BudgetEntity>> watchActiveBudgets() =>
      Stream.error(_unsupported());

  @override
  Stream<BudgetEntity?> watchBudgetById(String id) =>
      Stream.error(_unsupported());

  @override
  Future<AccountEntity?> getAccountById(String id) => _unsupported();

  @override
  Future<List<AccountEntity>> getActiveAccounts() => _unsupported();

  @override
  Future<List<AccountEntity>> getAllAccounts() => _unsupported();

  @override
  Future<AccountEntity?> getDefaultAccount() => _unsupported();

  @override
  Future<void> insertAccount(AccountEntity entity) => _unsupported();

  @override
  Future<void> updateAccount(AccountEntity entity) => _unsupported();

  @override
  Future<void> updateAccountBalance(String id, int balanceCents) =>
      _unsupported();

  @override
  Future<void> setDefaultAccount(String id) => _unsupported();

  @override
  Future<void> archiveAccount(String id) => _unsupported();

  @override
  Future<void> restoreAccount(String id) => _unsupported();

  @override
  Future<void> deleteAccount(String id) => _unsupported();

  @override
  Stream<List<AccountEntity>> watchActiveAccounts() =>
      Stream.error(_unsupported());

  @override
  Stream<int> watchTotalBalance() => Stream.error(_unsupported());

  @override
  Future<int> getTotalBalance() => _unsupported();

  @override
  Future<GroupEntity?> getGroupById(String id) => _unsupported();

  @override
  Future<GroupEntity?> getGroupByInviteCode(String code) => _unsupported();

  @override
  Future<List<GroupEntity>> getAllGroups() => _unsupported();

  @override
  Future<List<GroupEntity>> getActiveGroups() => _unsupported();

  @override
  Future<void> insertGroup(GroupEntity entity) => _unsupported();

  @override
  Future<void> updateGroup(GroupEntity entity) => _unsupported();

  @override
  Future<void> archiveGroup(String id) => _unsupported();

  @override
  Future<void> deleteGroup(String id) => _unsupported();

  @override
  Future<String> generateGroupInviteCode(String groupId) => _unsupported();

  @override
  Stream<List<GroupEntity>> watchAllGroups() => Stream.error(_unsupported());

  @override
  Stream<GroupEntity?> watchGroupById(String id) =>
      Stream.error(_unsupported());

  // Group Member Operations
  @override
  Future<List<GroupMemberEntity>> getGroupMembers(String groupId) =>
      _unsupported();

  @override
  Future<void> insertGroupMember(GroupMemberEntity entity) => _unsupported();

  @override
  Future<void> updateGroupMember(GroupMemberEntity entity) => _unsupported();

  @override
  Future<void> removeGroupMember(String groupId, String userId) =>
      _unsupported();

  @override
  Stream<List<GroupMemberEntity>> watchGroupMembers(String groupId) =>
      Stream.error(_unsupported());

  // Settlement Operations
  @override
  Future<SettlementEntity?> getSettlementById(String id) => _unsupported();

  @override
  Future<List<SettlementEntity>> getSettlementsByGroup(String groupId) =>
      _unsupported();

  @override
  Future<List<SettlementEntity>> getSettlementsBetweenUsers(
    String groupId,
    String userId1,
    String userId2,
  ) => _unsupported();

  @override
  Future<List<SettlementEntity>> getSettlementsByStatus(
    String groupId,
    String status,
  ) => _unsupported();

  @override
  Future<List<SettlementEntity>> getPendingSettlementsForUser(String userId) =>
      _unsupported();

  @override
  Future<void> insertSettlement(SettlementEntity entity) => _unsupported();

  @override
  Future<void> updateSettlement(SettlementEntity entity) => _unsupported();

  @override
  Future<void> completeSettlement(String id) => _unsupported();

  @override
  Future<void> cancelSettlement(String id) => _unsupported();

  @override
  Future<void> deleteSettlement(String id) => _unsupported();

  @override
  Stream<List<SettlementEntity>> watchSettlementsByGroup(String groupId) =>
      Stream.error(_unsupported());

  @override
  Stream<List<SettlementEntity>> watchPendingSettlementsForUser(
    String userId,
  ) => Stream.error(_unsupported());

  @override
  Future<int> getTotalSettled(String groupId) => _unsupported();

  @override
  Future<List<SettlementEntity>> getSettlementHistory(
    String userId1,
    String userId2,
    int limit,
  ) => _unsupported();

  @override
  Future<List<TransactionEntity>> getRecentTransactions(int limit) =>
      _unsupported();
}
