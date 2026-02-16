import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

part 'app_database.g.dart';

/// Sync status for offline-first support
enum SyncStatus { pending, synced, failed }

/// Database configuration
class DatabaseConfig {
  /// Whether to use encrypted database (SQLCipher)
  static bool useEncryption = !kDebugMode;

  /// Encryption key (in production, fetch from secure storage)
  static String? _encryptionKey;

  /// Set the encryption key (call before database initialization)
  static void setEncryptionKey(String key) {
    _encryptionKey = key;
  }

  /// Get the encryption key
  static String? get encryptionKey => _encryptionKey;
}

/// Transactions table for storing expense/income records
class TransactionEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get accountId => text()();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get amountCents => integer()(); // Negative for expenses
  TextColumn get description => text()();
  TextColumn get category => text()();
  TextColumn get tags =>
      text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get receiptUrl => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

/// Budgets table for storing budget limits per category/tag
class BudgetEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get tag => text()(); // Category or tag name
  IntColumn get limitCents => integer()();
  IntColumn get usedCents => integer().withDefault(const Constant(0))();
  IntColumn get carryoverCents => integer().withDefault(const Constant(0))();
  IntColumn get periodMonth => integer()(); // YYYYMM format, e.g., 202411
  TextColumn get recurrence => text().withDefault(const Constant('monthly'))();
  TextColumn get carryoverBehavior =>
      text().withDefault(const Constant('none'))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

/// Accounts table for storing money accounts (checking, savings, etc.)
class AccountEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get accountType => text()(); // checking, savings, credit_card
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  IntColumn get balanceCents => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

/// Outbox table for offline-first sync operations
class OutboxEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get operationId => text().unique()();
  TextColumn get entityType => text()(); // transaction, budget, account
  TextColumn get entityId => text()();
  TextColumn get operationType => text()(); // create, update, delete
  TextColumn get payload => text()(); // JSON payload
  IntColumn get priority => integer().withDefault(
    const Constant(1),
  )(); // 0=low, 1=normal, 2=high, 3=critical
  TextColumn get status => text().withDefault(
    const Constant('pending'),
  )(); // pending, inProgress, completed, failed
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
}

/// Categories table for expense categorization
class CategoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get iconName => text().withDefault(const Constant('category'))();
  TextColumn get colorHex => text().withDefault(const Constant('#808080'))();
  TextColumn get categoryType =>
      text().withDefault(const Constant('expense'))(); // expense, income, both
  TextColumn get parentId => text().nullable()(); // For subcategories
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

/// Groups table for expense sharing groups
class GroupEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get iconUrl => text().nullable()();
  TextColumn get createdByUserId => text()();

  /// Default currency for the group.
  /// Note: 'INR' is a fallback default only. User locale settings should
  /// override this value when creating new groups. See LocaleSettings for
  /// supported currencies (INR, USD, EUR, GBP).
  TextColumn get defaultCurrency => text().withDefault(const Constant('INR'))();
  BoolColumn get simplifyDebts => boolean().withDefault(const Constant(true))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get inviteCode => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

/// Group members table
class GroupMemberEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get groupId => text()();
  TextColumn get userId => text()();
  TextColumn get displayName => text()();
  TextColumn get email => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get role =>
      text().withDefault(const Constant('member'))(); // admin, member
  IntColumn get defaultSharePercent =>
      integer().withDefault(const Constant(100))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get joinedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

/// Shared expenses table (group expenses)
class SharedExpenseEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get groupId => text()();
  TextColumn get description => text()();
  IntColumn get totalAmountCents => integer()();

  /// Currency code for the expense.
  /// Note: 'INR' is a fallback default only. User locale settings should
  /// override this value when creating new expenses. See LocaleSettings for
  /// supported currencies (INR, USD, EUR, GBP).
  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();
  TextColumn get paidByUserId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get splitType => text().withDefault(
    const Constant('equal'),
  )(); // equal, percentage, exact, shares
  TextColumn get notes => text().nullable()();
  TextColumn get receiptUrl => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get expenseDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

/// Split entries table (individual shares of shared expenses)
class SplitEntryRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get sharedExpenseId => text()();
  TextColumn get userId => text()();
  IntColumn get amountCents => integer()();
  IntColumn get shareValue =>
      integer().withDefault(const Constant(100))(); // percentage or shares
  BoolColumn get isSettled => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

/// Settlements table for debt payments
class SettlementEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get groupId => text()();
  TextColumn get fromUserId => text()();
  TextColumn get toUserId => text()();
  IntColumn get amountCents => integer()();

  /// Currency code for the settlement.
  /// Note: 'INR' is a fallback default only. User locale settings should
  /// override this value when creating new settlements. See LocaleSettings for
  /// supported currencies (INR, USD, EUR, GBP).
  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();
  TextColumn get paymentMethod =>
      text().nullable()(); // cash, upi, bank_transfer
  TextColumn get paymentReference => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(
    const Constant('pending'),
  )(); // pending, completed, rejected
  DateTimeColumn get settledAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

/// Sync metadata table for tracking sync state
class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    TransactionEntries,
    BudgetEntries,
    AccountEntries,
    CategoryEntries,
    GroupEntries,
    GroupMemberEntries,
    SharedExpenseEntries,
    SplitEntryRecords,
    SettlementEntries,
    OutboxEntries,
    SyncMetadata,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing - allows injecting a custom executor
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Early development - no migrations needed yet
      // When we have production data, add proper migrations here
    },
    beforeOpen: (details) async {
      // Enable foreign keys for data integrity
      await customStatement('PRAGMA foreign_keys = ON');

      // Optimize for mobile performance
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = NORMAL');
      await customStatement('PRAGMA cache_size = 10000');
    },
  );

  /// Export database for backup
  Future<List<int>> exportDatabase() async {
    final file = File(await getDatabasePath());
    return file.readAsBytes();
  }

  /// Get database file path
  static Future<String> getDatabasePath() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'airo_money.db');
  }

  /// Delete all data (for account deletion/reset)
  Future<void> deleteAllData() async {
    await transaction(() async {
      // Delete in order respecting foreign key constraints
      await delete(splitEntryRecords).go();
      await delete(settlementEntries).go();
      await delete(sharedExpenseEntries).go();
      await delete(groupMemberEntries).go();
      await delete(groupEntries).go();
      await delete(categoryEntries).go();
      await delete(transactionEntries).go();
      await delete(budgetEntries).go();
      await delete(accountEntries).go();
      await delete(outboxEntries).go();
      await delete(syncMetadata).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'airo_money.db'));

    // Use encryption in production
    if (DatabaseConfig.useEncryption && DatabaseConfig.encryptionKey != null) {
      return NativeDatabase.createInBackground(
        file,
        setup: (db) {
          // SQLCipher encryption setup
          db.execute("PRAGMA key = '${DatabaseConfig.encryptionKey}'");
        },
      );
    }

    return NativeDatabase.createInBackground(file);
  });
}
