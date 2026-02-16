import 'dart:math';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import 'coins_local_datasource.dart';

/// Implementation of CoinsLocalDatasource using Drift
///
/// Phase: 1 & 2
/// See: docs/features/coins/PROJECT_STRUCTURE.md
class CoinsLocalDatasourceImpl implements CoinsLocalDatasource {
  final AppDatabase _db;

  CoinsLocalDatasourceImpl(this._db);

  // ==================== Transaction Operations ====================
  // Note: Using existing TransactionEntries table from app_database.dart
  // The Coins feature reuses the existing transaction table with some adaptations

  @override
  Future<TransactionEntity?> getTransactionById(String id) async {
    final result = await (_db.select(
      _db.transactionEntries,
    )..where((t) => t.uuid.equals(id))).getSingleOrNull();
    return result != null ? _mapTransactionEntry(result) : null;
  }

  @override
  Future<List<TransactionEntity>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final results =
        await (_db.select(_db.transactionEntries)
              ..where(
                (t) =>
                    t.timestamp.isBiggerOrEqualValue(start) &
                    t.timestamp.isSmallerOrEqualValue(end),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
            .get();
    return results.map(_mapTransactionEntry).toList();
  }

  @override
  Future<List<TransactionEntity>> getTransactionsByCategory(
    String categoryId,
  ) async {
    final results =
        await (_db.select(_db.transactionEntries)
              ..where((t) => t.category.equals(categoryId))
              ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
            .get();
    return results.map(_mapTransactionEntry).toList();
  }

  @override
  Future<List<TransactionEntity>> getTransactionsByAccount(
    String accountId,
  ) async {
    final results =
        await (_db.select(_db.transactionEntries)
              ..where((t) => t.accountId.equals(accountId))
              ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
            .get();
    return results.map(_mapTransactionEntry).toList();
  }

  @override
  Future<List<TransactionEntity>> getRecentTransactions(int limit) async {
    final results =
        await (_db.select(_db.transactionEntries)
              ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
              ..limit(limit))
            .get();
    return results.map(_mapTransactionEntry).toList();
  }

  @override
  Future<void> insertTransaction(TransactionEntity entity) async {
    await _db
        .into(_db.transactionEntries)
        .insert(
          TransactionEntriesCompanion.insert(
            uuid: entity.id,
            accountId: entity.accountId,
            timestamp: entity.transactionDate,
            amountCents: entity.amountCents,
            description: entity.description,
            category: entity.categoryId,
            tags: Value(entity.tags ?? '[]'),
            receiptUrl: Value(entity.receiptId),
            syncStatus: const Value('pending'),
          ),
        );
  }

  @override
  Future<void> updateTransaction(TransactionEntity entity) async {
    await (_db.update(
      _db.transactionEntries,
    )..where((t) => t.uuid.equals(entity.id))).write(
      TransactionEntriesCompanion(
        accountId: Value(entity.accountId),
        timestamp: Value(entity.transactionDate),
        amountCents: Value(entity.amountCents),
        description: Value(entity.description),
        category: Value(entity.categoryId),
        tags: Value(entity.tags ?? '[]'),
        receiptUrl: Value(entity.receiptId),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> softDeleteTransaction(String id) async {
    // Using sync status as a soft delete marker since TransactionEntries
    // doesn't have isDeleted column - mark as 'deleted' status
    await (_db.update(
      _db.transactionEntries,
    )..where((t) => t.uuid.equals(id))).write(
      TransactionEntriesCompanion(
        syncStatus: const Value('deleted'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> hardDeleteTransaction(String id) async {
    await (_db.delete(
      _db.transactionEntries,
    )..where((t) => t.uuid.equals(id))).go();
  }

  @override
  Future<void> restoreTransaction(String id) async {
    await (_db.update(
      _db.transactionEntries,
    )..where((t) => t.uuid.equals(id))).write(
      TransactionEntriesCompanion(
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Stream<List<TransactionEntity>> watchAllTransactions() {
    return (_db.select(_db.transactionEntries)
          ..where((t) => t.syncStatus.equals('deleted').not())
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .watch()
        .map((rows) => rows.map(_mapTransactionEntry).toList());
  }

  @override
  Stream<List<TransactionEntity>> watchTransactionsByCategory(
    String categoryId,
  ) {
    return (_db.select(_db.transactionEntries)
          ..where(
            (t) =>
                t.category.equals(categoryId) &
                t.syncStatus.equals('deleted').not(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .watch()
        .map((rows) => rows.map(_mapTransactionEntry).toList());
  }

  @override
  Stream<List<TransactionEntity>> watchTransactionsByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return (_db.select(_db.transactionEntries)
          ..where(
            (t) =>
                t.timestamp.isBiggerOrEqualValue(startOfDay) &
                t.timestamp.isSmallerThanValue(endOfDay) &
                t.syncStatus.equals('deleted').not(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .watch()
        .map((rows) => rows.map(_mapTransactionEntry).toList());
  }

  @override
  Future<int> getTotalSpent(DateTime start, DateTime end) async {
    final results = await getTransactionsByDateRange(start, end);
    return results
        .where((t) => t.amountCents < 0) // Expenses are negative
        .fold<int>(0, (sum, t) => sum + t.amountCents.abs());
  }

  @override
  Future<Map<String, int>> getSpentByCategory(
    DateTime start,
    DateTime end,
  ) async {
    final results = await getTransactionsByDateRange(start, end);
    final Map<String, int> byCategory = {};
    for (final t in results.where((t) => t.amountCents < 0)) {
      byCategory[t.categoryId] =
          (byCategory[t.categoryId] ?? 0) + t.amountCents.abs();
    }
    return byCategory;
  }

  @override
  Future<List<TransactionEntity>> searchTransactions(String query) async {
    final results =
        await (_db.select(_db.transactionEntries)
              ..where(
                (t) =>
                    t.description.contains(query) |
                    t.category.contains(query) &
                        t.syncStatus.equals('deleted').not(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
            .get();
    return results.map(_mapTransactionEntry).toList();
  }

  TransactionEntity _mapTransactionEntry(TransactionEntry entry) {
    return TransactionEntity(
      id: entry.uuid,
      description: entry.description,
      amountCents: entry.amountCents,
      type: entry.amountCents >= 0 ? 'income' : 'expense',
      categoryId: entry.category,
      accountId: entry.accountId,
      transactionDate: entry.timestamp,
      notes: null, // Not in existing schema
      receiptId: entry.receiptUrl,
      tags: entry.tags,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      isDeleted: entry.syncStatus == 'deleted',
    );
  }

  // ==================== Budget Operations ====================
  // Note: Using existing BudgetEntries table from app_database.dart

  @override
  Future<BudgetEntity?> getBudgetById(String id) async {
    final result = await (_db.select(
      _db.budgetEntries,
    )..where((b) => b.uuid.equals(id))).getSingleOrNull();
    return result != null ? _mapBudgetEntry(result) : null;
  }

  @override
  Future<BudgetEntity?> getBudgetByCategory(String categoryId) async {
    final result = await (_db.select(
      _db.budgetEntries,
    )..where((b) => b.tag.equals(categoryId))).getSingleOrNull();
    return result != null ? _mapBudgetEntry(result) : null;
  }

  @override
  Future<List<BudgetEntity>> getActiveBudgets() async {
    final currentPeriod = _currentPeriodMonth;
    final results = await (_db.select(
      _db.budgetEntries,
    )..where((b) => b.periodMonth.equals(currentPeriod))).get();
    return results.map(_mapBudgetEntry).toList();
  }

  @override
  Future<List<BudgetEntity>> getAllBudgets() async {
    final results = await _db.select(_db.budgetEntries).get();
    return results.map(_mapBudgetEntry).toList();
  }

  @override
  Future<void> insertBudget(BudgetEntity entity) async {
    await _db
        .into(_db.budgetEntries)
        .insert(
          BudgetEntriesCompanion.insert(
            uuid: entity.id,
            tag: entity.categoryId,
            limitCents: entity.limitCents,
            periodMonth: _periodMonthFromDate(entity.startDate),
            syncStatus: const Value('pending'),
          ),
        );
  }

  @override
  Future<void> updateBudget(BudgetEntity entity) async {
    await (_db.update(
      _db.budgetEntries,
    )..where((b) => b.uuid.equals(entity.id))).write(
      BudgetEntriesCompanion(
        tag: Value(entity.categoryId),
        limitCents: Value(entity.limitCents),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deactivateBudget(String id) async {
    // Mark budget as synced (effectively deactivated for current period)
    await (_db.update(
      _db.budgetEntries,
    )..where((b) => b.uuid.equals(id))).write(
      BudgetEntriesCompanion(
        syncStatus: const Value('archived'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteBudget(String id) async {
    await (_db.delete(_db.budgetEntries)..where((b) => b.uuid.equals(id))).go();
  }

  @override
  Stream<List<BudgetEntity>> watchActiveBudgets() {
    final currentPeriod = _currentPeriodMonth;
    return (_db.select(_db.budgetEntries)
          ..where((b) => b.periodMonth.equals(currentPeriod)))
        .watch()
        .map((rows) => rows.map(_mapBudgetEntry).toList());
  }

  @override
  Stream<BudgetEntity?> watchBudgetById(String id) {
    return (_db.select(_db.budgetEntries)..where((b) => b.uuid.equals(id)))
        .watchSingleOrNull()
        .map((row) => row != null ? _mapBudgetEntry(row) : null);
  }

  int get _currentPeriodMonth {
    final now = DateTime.now();
    return now.year * 100 + now.month;
  }

  int _periodMonthFromDate(DateTime date) {
    return date.year * 100 + date.month;
  }

  BudgetEntity _mapBudgetEntry(BudgetEntry entry) {
    final year = entry.periodMonth ~/ 100;
    final month = entry.periodMonth % 100;
    return BudgetEntity(
      id: entry.uuid,
      name: entry.tag, // Using tag as name
      categoryId: entry.tag,
      limitCents: entry.limitCents,
      period: 'monthly',
      alertThresholdPercent: 80, // Default
      isActive: entry.syncStatus != 'archived',
      currencyCode: 'INR', // Default
      startDate: DateTime(year, month, 1),
      endDate: DateTime(year, month + 1, 0),
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  // ==================== Account Operations ====================
  // Note: Using existing AccountEntries table from app_database.dart
  // AccountEntries uses: uuid, name, accountType, currency, balanceCents, syncStatus

  @override
  Future<AccountEntity?> getAccountById(String id) async {
    final result = await (_db.select(
      _db.accountEntries,
    )..where((a) => a.uuid.equals(id))).getSingleOrNull();
    return result != null ? _mapAccountEntry(result) : null;
  }

  @override
  Future<List<AccountEntity>> getActiveAccounts() async {
    // Using syncStatus != 'archived' as active filter since no isActive column
    final results = await (_db.select(
      _db.accountEntries,
    )..where((a) => a.syncStatus.equals('archived').not())).get();
    return results.map(_mapAccountEntry).toList();
  }

  @override
  Future<List<AccountEntity>> getAllAccounts() async {
    final results = await _db.select(_db.accountEntries).get();
    return results.map(_mapAccountEntry).toList();
  }

  @override
  Future<AccountEntity?> getDefaultAccount() async {
    final results = await getActiveAccounts();
    return results.isNotEmpty ? results.first : null;
  }

  @override
  Future<void> insertAccount(AccountEntity entity) async {
    await _db
        .into(_db.accountEntries)
        .insert(
          AccountEntriesCompanion.insert(
            uuid: entity.id,
            name: entity.name,
            accountType: entity.type,
            balanceCents: Value(entity.balanceCents),
            currency: Value(entity.currencyCode),
            syncStatus: const Value('pending'),
          ),
        );
  }

  @override
  Future<void> updateAccount(AccountEntity entity) async {
    await (_db.update(
      _db.accountEntries,
    )..where((a) => a.uuid.equals(entity.id))).write(
      AccountEntriesCompanion(
        name: Value(entity.name),
        balanceCents: Value(entity.balanceCents),
        accountType: Value(entity.type),
        currency: Value(entity.currencyCode),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> updateAccountBalance(String id, int balanceCents) async {
    await (_db.update(
      _db.accountEntries,
    )..where((a) => a.uuid.equals(id))).write(
      AccountEntriesCompanion(
        balanceCents: Value(balanceCents),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> setDefaultAccount(String id) async {
    // AccountEntries doesn't have isDefault - first active account is default
    // This is a no-op for now
  }

  @override
  Future<void> archiveAccount(String id) async {
    await (_db.update(
      _db.accountEntries,
    )..where((a) => a.uuid.equals(id))).write(
      AccountEntriesCompanion(
        syncStatus: const Value('archived'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> restoreAccount(String id) async {
    await (_db.update(
      _db.accountEntries,
    )..where((a) => a.uuid.equals(id))).write(
      AccountEntriesCompanion(
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteAccount(String id) async {
    await (_db.delete(
      _db.accountEntries,
    )..where((a) => a.uuid.equals(id))).go();
  }

  @override
  Stream<List<AccountEntity>> watchActiveAccounts() {
    return (_db.select(_db.accountEntries)
          ..where((a) => a.syncStatus.equals('archived').not()))
        .watch()
        .map((rows) => rows.map(_mapAccountEntry).toList());
  }

  @override
  Stream<int> watchTotalBalance() {
    return watchActiveAccounts().map(
      (accounts) => accounts.fold<int>(0, (sum, a) => sum + a.balanceCents),
    );
  }

  @override
  Future<int> getTotalBalance() async {
    final accounts = await getActiveAccounts();
    return accounts.fold<int>(0, (sum, a) => sum + a.balanceCents);
  }

  AccountEntity _mapAccountEntry(AccountEntry entry) {
    return AccountEntity(
      id: entry.uuid,
      name: entry.name,
      type: entry.accountType,
      balanceCents: entry.balanceCents,
      currencyCode: entry.currency,
      iconName: null,
      color: null,
      isDefault: false,
      isArchived: entry.syncStatus == 'archived',
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  // ==================== Group Operations ====================
  // Note: Using new GroupEntries table

  @override
  Future<GroupEntity?> getGroupById(String id) async {
    final result = await (_db.select(
      _db.groupEntries,
    )..where((g) => g.uuid.equals(id))).getSingleOrNull();
    return result != null ? _mapGroupEntry(result) : null;
  }

  @override
  Future<GroupEntity?> getGroupByInviteCode(String code) async {
    final result = await (_db.select(
      _db.groupEntries,
    )..where((g) => g.inviteCode.equals(code))).getSingleOrNull();
    return result != null ? _mapGroupEntry(result) : null;
  }

  @override
  Future<List<GroupEntity>> getAllGroups() async {
    final results = await _db.select(_db.groupEntries).get();
    return results.map(_mapGroupEntry).toList();
  }

  @override
  Future<List<GroupEntity>> getActiveGroups() async {
    final results = await (_db.select(
      _db.groupEntries,
    )..where((g) => g.isActive.equals(true))).get();
    return results.map(_mapGroupEntry).toList();
  }

  @override
  Future<void> insertGroup(GroupEntity entity) async {
    await _db
        .into(_db.groupEntries)
        .insert(
          GroupEntriesCompanion.insert(
            uuid: entity.id,
            name: entity.name,
            description: Value(entity.description),
            iconUrl: Value(entity.iconUrl),
            createdByUserId: entity.creatorId,
            defaultCurrency: Value(entity.defaultCurrencyCode),
            inviteCode: Value(entity.inviteCode),
            syncStatus: const Value('pending'),
          ),
        );
  }

  @override
  Future<void> updateGroup(GroupEntity entity) async {
    await (_db.update(
      _db.groupEntries,
    )..where((g) => g.uuid.equals(entity.id))).write(
      GroupEntriesCompanion(
        name: Value(entity.name),
        description: Value(entity.description),
        iconUrl: Value(entity.iconUrl),
        defaultCurrency: Value(entity.defaultCurrencyCode),
        inviteCode: Value(entity.inviteCode),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> archiveGroup(String id) async {
    await (_db.update(_db.groupEntries)..where((g) => g.uuid.equals(id))).write(
      GroupEntriesCompanion(
        isActive: const Value(false),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteGroup(String id) async {
    await (_db.delete(_db.groupEntries)..where((g) => g.uuid.equals(id))).go();
  }

  @override
  Future<String> generateGroupInviteCode(String groupId) async {
    final code = _generateRandomCode(8);
    await (_db.update(
      _db.groupEntries,
    )..where((g) => g.uuid.equals(groupId))).write(
      GroupEntriesCompanion(
        inviteCode: Value(code),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return code;
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  @override
  Stream<List<GroupEntity>> watchAllGroups() {
    return _db
        .select(_db.groupEntries)
        .watch()
        .map((rows) => rows.map(_mapGroupEntry).toList());
  }

  @override
  Stream<GroupEntity?> watchGroupById(String id) {
    return (_db.select(_db.groupEntries)..where((g) => g.uuid.equals(id)))
        .watchSingleOrNull()
        .map((row) => row != null ? _mapGroupEntry(row) : null);
  }

  GroupEntity _mapGroupEntry(GroupEntry entry) {
    return GroupEntity(
      id: entry.uuid,
      name: entry.name,
      description: entry.description,
      iconUrl: entry.iconUrl,
      defaultCurrencyCode: entry.defaultCurrency,
      settings: null, // Will add JSON encoding later if needed
      creatorId: entry.createdByUserId,
      inviteCode: entry.inviteCode,
      isArchived: !entry.isActive,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  // ==================== Group Member Operations ====================

  @override
  Future<List<GroupMemberEntity>> getGroupMembers(String groupId) async {
    final results = await (_db.select(
      _db.groupMemberEntries,
    )..where((m) => m.groupId.equals(groupId) & m.isActive.equals(true))).get();
    return results.map(_mapGroupMemberEntry).toList();
  }

  @override
  Future<void> insertGroupMember(GroupMemberEntity entity) async {
    await _db
        .into(_db.groupMemberEntries)
        .insert(
          GroupMemberEntriesCompanion.insert(
            uuid: entity.id,
            groupId: entity.groupId,
            userId: entity.userId,
            displayName: entity.displayName,
            avatarUrl: Value(entity.avatarUrl),
            role: Value(entity.role),
            syncStatus: const Value('pending'),
          ),
        );
  }

  @override
  Future<void> updateGroupMember(GroupMemberEntity entity) async {
    await (_db.update(
      _db.groupMemberEntries,
    )..where((m) => m.uuid.equals(entity.id))).write(
      GroupMemberEntriesCompanion(
        displayName: Value(entity.displayName),
        avatarUrl: Value(entity.avatarUrl),
        role: Value(entity.role),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> removeGroupMember(String groupId, String userId) async {
    await (_db.update(
      _db.groupMemberEntries,
    )..where((m) => m.groupId.equals(groupId) & m.userId.equals(userId))).write(
      GroupMemberEntriesCompanion(
        isActive: const Value(false),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Stream<List<GroupMemberEntity>> watchGroupMembers(String groupId) {
    return (_db.select(_db.groupMemberEntries)
          ..where((m) => m.groupId.equals(groupId) & m.isActive.equals(true)))
        .watch()
        .map((rows) => rows.map(_mapGroupMemberEntry).toList());
  }

  GroupMemberEntity _mapGroupMemberEntry(GroupMemberEntry entry) {
    return GroupMemberEntity(
      id: entry.uuid,
      groupId: entry.groupId,
      userId: entry.userId,
      displayName: entry.displayName,
      avatarUrl: entry.avatarUrl,
      role: entry.role,
      currencyCode: 'INR', // Default
      joinedAt: entry.joinedAt,
    );
  }

  // ==================== Settlement Operations ====================

  @override
  Future<SettlementEntity?> getSettlementById(String id) async {
    final result = await (_db.select(
      _db.settlementEntries,
    )..where((s) => s.uuid.equals(id))).getSingleOrNull();
    return result != null ? _mapSettlementEntry(result) : null;
  }

  @override
  Future<List<SettlementEntity>> getSettlementsByGroup(String groupId) async {
    final results =
        await (_db.select(_db.settlementEntries)
              ..where((s) => s.groupId.equals(groupId))
              ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
            .get();
    return results.map(_mapSettlementEntry).toList();
  }

  @override
  Future<List<SettlementEntity>> getSettlementsBetweenUsers(
    String groupId,
    String userId1,
    String userId2,
  ) async {
    final results =
        await (_db.select(_db.settlementEntries)
              ..where(
                (s) =>
                    s.groupId.equals(groupId) &
                    ((s.fromUserId.equals(userId1) &
                            s.toUserId.equals(userId2)) |
                        (s.fromUserId.equals(userId2) &
                            s.toUserId.equals(userId1))),
              )
              ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
            .get();
    return results.map(_mapSettlementEntry).toList();
  }

  @override
  Future<List<SettlementEntity>> getSettlementsByStatus(
    String groupId,
    String status,
  ) async {
    final results =
        await (_db.select(_db.settlementEntries)
              ..where(
                (s) => s.groupId.equals(groupId) & s.status.equals(status),
              )
              ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
            .get();
    return results.map(_mapSettlementEntry).toList();
  }

  @override
  Future<List<SettlementEntity>> getPendingSettlementsForUser(
    String userId,
  ) async {
    final results =
        await (_db.select(_db.settlementEntries)
              ..where(
                (s) =>
                    (s.fromUserId.equals(userId) | s.toUserId.equals(userId)) &
                    s.status.equals('pending'),
              )
              ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
            .get();
    return results.map(_mapSettlementEntry).toList();
  }

  @override
  Future<void> insertSettlement(SettlementEntity entity) async {
    await _db
        .into(_db.settlementEntries)
        .insert(
          SettlementEntriesCompanion.insert(
            uuid: entity.id,
            groupId: entity.groupId,
            fromUserId: entity.fromUserId,
            toUserId: entity.toUserId,
            amountCents: entity.amountCents,
            currencyCode: Value(entity.currencyCode),
            paymentMethod: Value(entity.paymentMethod),
            paymentReference: Value(entity.paymentReference),
            notes: Value(entity.notes),
            status: Value(entity.status),
            syncStatus: const Value('pending'),
          ),
        );
  }

  @override
  Future<void> updateSettlement(SettlementEntity entity) async {
    await (_db.update(
      _db.settlementEntries,
    )..where((s) => s.uuid.equals(entity.id))).write(
      SettlementEntriesCompanion(
        amountCents: Value(entity.amountCents),
        paymentMethod: Value(entity.paymentMethod),
        paymentReference: Value(entity.paymentReference),
        notes: Value(entity.notes),
        status: Value(entity.status),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> completeSettlement(String id) async {
    await (_db.update(
      _db.settlementEntries,
    )..where((s) => s.uuid.equals(id))).write(
      SettlementEntriesCompanion(
        status: const Value('completed'),
        settledAt: Value(DateTime.now()),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> cancelSettlement(String id) async {
    await (_db.update(
      _db.settlementEntries,
    )..where((s) => s.uuid.equals(id))).write(
      SettlementEntriesCompanion(
        status: const Value('rejected'),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteSettlement(String id) async {
    await (_db.delete(
      _db.settlementEntries,
    )..where((s) => s.uuid.equals(id))).go();
  }

  @override
  Stream<List<SettlementEntity>> watchSettlementsByGroup(String groupId) {
    return (_db.select(_db.settlementEntries)
          ..where((s) => s.groupId.equals(groupId))
          ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
        .watch()
        .map((rows) => rows.map(_mapSettlementEntry).toList());
  }

  @override
  Stream<List<SettlementEntity>> watchPendingSettlementsForUser(String userId) {
    return (_db.select(_db.settlementEntries)
          ..where(
            (s) =>
                (s.fromUserId.equals(userId) | s.toUserId.equals(userId)) &
                s.status.equals('pending'),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
        .watch()
        .map((rows) => rows.map(_mapSettlementEntry).toList());
  }

  @override
  Future<int> getTotalSettled(String groupId) async {
    final results = await getSettlementsByStatus(groupId, 'completed');
    return results.fold<int>(0, (sum, s) => sum + s.amountCents);
  }

  @override
  Future<List<SettlementEntity>> getSettlementHistory(
    String userId1,
    String userId2,
    int limit,
  ) async {
    final results =
        await (_db.select(_db.settlementEntries)
              ..where(
                (s) =>
                    (s.fromUserId.equals(userId1) &
                        s.toUserId.equals(userId2)) |
                    (s.fromUserId.equals(userId2) & s.toUserId.equals(userId1)),
              )
              ..orderBy([(s) => OrderingTerm.desc(s.createdAt)])
              ..limit(limit))
            .get();
    return results.map(_mapSettlementEntry).toList();
  }

  SettlementEntity _mapSettlementEntry(SettlementEntry entry) {
    return SettlementEntity(
      id: entry.uuid,
      groupId: entry.groupId,
      fromUserId: entry.fromUserId,
      toUserId: entry.toUserId,
      amountCents: entry.amountCents,
      currencyCode: entry.currencyCode,
      status: entry.status,
      paymentMethod: entry.paymentMethod,
      paymentReference: entry.paymentReference,
      notes: entry.notes,
      createdAt: entry.createdAt,
      completedAt: entry.settledAt,
    );
  }
}
