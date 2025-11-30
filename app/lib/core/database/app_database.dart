import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

part 'app_database.g.dart';

/// Sync status for offline-first support
enum SyncStatus {
  pending,
  synced,
  failed,
}

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
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON array
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
  TextColumn get carryoverBehavior => text().withDefault(const Constant('none'))();
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

@DriftDatabase(tables: [TransactionEntries, BudgetEntries, AccountEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing - allows injecting a custom executor
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Migration from v1 to v2: Add indexes for performance
      if (from < 2) {
        await m.createIndex(Index('idx_transactions_account',
          'CREATE INDEX idx_transactions_account ON transaction_entries(account_id)'));
        await m.createIndex(Index('idx_transactions_category',
          'CREATE INDEX idx_transactions_category ON transaction_entries(category)'));
        await m.createIndex(Index('idx_transactions_timestamp',
          'CREATE INDEX idx_transactions_timestamp ON transaction_entries(timestamp DESC)'));
        await m.createIndex(Index('idx_budgets_period',
          'CREATE INDEX idx_budgets_period ON budget_entries(period_month, tag)'));
      }
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
      await delete(transactionEntries).go();
      await delete(budgetEntries).go();
      await delete(accountEntries).go();
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

