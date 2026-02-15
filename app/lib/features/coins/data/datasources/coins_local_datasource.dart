/// Local datasource interface for Coins feature
///
/// Defines all database operations for the Coins feature.
/// Implemented using Drift for SQLite access.
///
/// Phase: 1 & 2
/// See: docs/features/coins/PROJECT_STRUCTURE.md
abstract class CoinsLocalDatasource {
  // ==================== Transaction Operations ====================

  Future<TransactionEntity?> getTransactionById(String id);
  Future<List<TransactionEntity>> getTransactionsByDateRange(DateTime start, DateTime end);
  Future<List<TransactionEntity>> getTransactionsByCategory(String categoryId);
  Future<List<TransactionEntity>> getTransactionsByAccount(String accountId);
  Future<List<TransactionEntity>> getRecentTransactions(int limit);
  Future<void> insertTransaction(TransactionEntity entity);
  Future<void> updateTransaction(TransactionEntity entity);
  Future<void> softDeleteTransaction(String id);
  Future<void> hardDeleteTransaction(String id);
  Future<void> restoreTransaction(String id);
  Stream<List<TransactionEntity>> watchAllTransactions();
  Stream<List<TransactionEntity>> watchTransactionsByCategory(String categoryId);
  Stream<List<TransactionEntity>> watchTransactionsByDate(DateTime date);
  Future<int> getTotalSpent(DateTime start, DateTime end);
  Future<Map<String, int>> getSpentByCategory(DateTime start, DateTime end);
  Future<List<TransactionEntity>> searchTransactions(String query);

  // ==================== Budget Operations ====================

  Future<BudgetEntity?> getBudgetById(String id);
  Future<BudgetEntity?> getBudgetByCategory(String categoryId);
  Future<List<BudgetEntity>> getActiveBudgets();
  Future<List<BudgetEntity>> getAllBudgets();
  Future<void> insertBudget(BudgetEntity entity);
  Future<void> updateBudget(BudgetEntity entity);
  Future<void> deactivateBudget(String id);
  Future<void> deleteBudget(String id);
  Stream<List<BudgetEntity>> watchActiveBudgets();
  Stream<BudgetEntity?> watchBudgetById(String id);

  // ==================== Account Operations ====================

  Future<AccountEntity?> getAccountById(String id);
  Future<List<AccountEntity>> getActiveAccounts();
  Future<List<AccountEntity>> getAllAccounts();
  Future<AccountEntity?> getDefaultAccount();
  Future<void> insertAccount(AccountEntity entity);
  Future<void> updateAccount(AccountEntity entity);
  Future<void> updateAccountBalance(String id, int balanceCents);
  Future<void> setDefaultAccount(String id);
  Future<void> archiveAccount(String id);
  Future<void> restoreAccount(String id);
  Future<void> deleteAccount(String id);
  Stream<List<AccountEntity>> watchActiveAccounts();
  Stream<int> watchTotalBalance();
  Future<int> getTotalBalance();

  // ==================== Group Operations ====================

  Future<GroupEntity?> getGroupById(String id);
  Future<GroupEntity?> getGroupByInviteCode(String code);
  Future<List<GroupEntity>> getAllGroups();
  Future<List<GroupEntity>> getActiveGroups();
  Future<void> insertGroup(GroupEntity entity);
  Future<void> updateGroup(GroupEntity entity);
  Future<void> archiveGroup(String id);
  Future<void> deleteGroup(String id);
  Future<String> generateGroupInviteCode(String groupId);
  Stream<List<GroupEntity>> watchAllGroups();
  Stream<GroupEntity?> watchGroupById(String id);

  // ==================== Group Member Operations ====================

  Future<List<GroupMemberEntity>> getGroupMembers(String groupId);
  Future<void> insertGroupMember(GroupMemberEntity entity);
  Future<void> updateGroupMember(GroupMemberEntity entity);
  Future<void> removeGroupMember(String groupId, String userId);
  Stream<List<GroupMemberEntity>> watchGroupMembers(String groupId);

  // ==================== Settlement Operations ====================

  Future<SettlementEntity?> getSettlementById(String id);
  Future<List<SettlementEntity>> getSettlementsByGroup(String groupId);
  Future<List<SettlementEntity>> getSettlementsBetweenUsers(
    String groupId,
    String userId1,
    String userId2,
  );
  Future<List<SettlementEntity>> getSettlementsByStatus(
    String groupId,
    String status,
  );
  Future<List<SettlementEntity>> getPendingSettlementsForUser(String userId);
  Future<void> insertSettlement(SettlementEntity entity);
  Future<void> updateSettlement(SettlementEntity entity);
  Future<void> completeSettlement(String id);
  Future<void> cancelSettlement(String id);
  Future<void> deleteSettlement(String id);
  Stream<List<SettlementEntity>> watchSettlementsByGroup(String groupId);
  Stream<List<SettlementEntity>> watchPendingSettlementsForUser(String userId);
  Future<int> getTotalSettled(String groupId);
  Future<List<SettlementEntity>> getSettlementHistory(
    String userId1,
    String userId2,
    int limit,
  );
}

// ==================== Entity Classes ====================
// These represent database table rows

class TransactionEntity {
  final String id;
  final String description;
  final int amountCents;
  final String type;
  final String categoryId;
  final String accountId;
  final DateTime transactionDate;
  final String? notes;
  final String? receiptId;
  final String? tags; // JSON encoded
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  TransactionEntity({
    required this.id,
    required this.description,
    required this.amountCents,
    required this.type,
    required this.categoryId,
    required this.accountId,
    required this.transactionDate,
    this.notes,
    this.receiptId,
    this.tags,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  });
}

class BudgetEntity {
  final String id;
  final String name;
  final String categoryId;
  final int limitCents;
  final String period;
  final int alertThresholdPercent;
  final bool isActive;
  final String currencyCode;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BudgetEntity({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.limitCents,
    required this.period,
    required this.alertThresholdPercent,
    required this.isActive,
    required this.currencyCode,
    required this.startDate,
    this.endDate,
    required this.createdAt,
    this.updatedAt,
  });
}

class AccountEntity {
  final String id;
  final String name;
  final String type;
  final int balanceCents;
  final String currencyCode;
  final String? iconName;
  final String? color;
  final bool isDefault;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AccountEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.balanceCents,
    required this.currencyCode,
    this.iconName,
    this.color,
    this.isDefault = false,
    this.isArchived = false,
    required this.createdAt,
    this.updatedAt,
  });
}

class GroupEntity {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String defaultCurrencyCode;
  final String? settings; // JSON encoded
  final String creatorId;
  final String? inviteCode;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime? updatedAt;

  GroupEntity({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    required this.defaultCurrencyCode,
    this.settings,
    required this.creatorId,
    this.inviteCode,
    this.isArchived = false,
    required this.createdAt,
    this.updatedAt,
  });
}

class GroupMemberEntity {
  final String id;
  final String groupId;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String role;
  final String currencyCode;
  final DateTime joinedAt;

  GroupMemberEntity({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.role,
    required this.currencyCode,
    required this.joinedAt,
  });
}

class SettlementEntity {
  final String id;
  final String groupId;
  final String fromUserId;
  final String toUserId;
  final int amountCents;
  final String currencyCode;
  final String status;
  final String? paymentMethod;
  final String? paymentReference;
  final String? notes;
  final DateTime createdAt;
  final DateTime? completedAt;

  SettlementEntity({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amountCents,
    required this.currencyCode,
    required this.status,
    this.paymentMethod,
    this.paymentReference,
    this.notes,
    required this.createdAt,
    this.completedAt,
  });
}

