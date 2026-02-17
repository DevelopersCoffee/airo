// ignore_for_file: avoid_unused_constructor_parameters

/// Web-compatible database implementation using Hive for IndexedDB storage.
/// This provides the same interface as the native AppDatabase but uses
/// Hive boxes instead of SQLite for web platform compatibility.
library;

import 'package:hive_flutter/hive_flutter.dart';

/// Sync status for offline-first support
enum SyncStatus { pending, synced, failed }

/// Database configuration (web implementation)
class DatabaseConfig {
  /// Whether to use encrypted database (not supported on web)
  static bool useEncryption = false;

  /// Encryption key (not used on web)
  static String? _encryptionKey;

  /// Set the encryption key (no-op on web)
  static void setEncryptionKey(String key) {
    _encryptionKey = key;
  }

  /// Get the encryption key
  static String? get encryptionKey => _encryptionKey;
}

/// Web-compatible database using Hive
/// Provides the same API as native AppDatabase for consistency
class AppDatabase {
  static bool _initialized = false;
  static AppDatabase? _instance;

  // Hive box names matching native table names
  static const String _transactionsBox = 'transaction_entries';
  static const String _budgetsBox = 'budget_entries';
  static const String _accountsBox = 'account_entries';
  static const String _categoriesBox = 'category_entries';
  static const String _groupsBox = 'group_entries';
  static const String _groupMembersBox = 'group_member_entries';
  static const String _sharedExpensesBox = 'shared_expense_entries';
  static const String _splitRecordsBox = 'split_entry_records';
  static const String _settlementsBox = 'settlement_entries';
  static const String _outboxBox = 'outbox_entries';
  static const String _syncMetadataBox = 'sync_metadata';

  AppDatabase._();

  /// Factory constructor that returns singleton
  factory AppDatabase() {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  /// For testing - allows custom initialization
  AppDatabase.forTesting(dynamic e);

  /// Initialize Hive for web
  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _initialized = true;
  }

  /// Open a Hive box (lazy initialization)
  Future<Box<Map<dynamic, dynamic>>> _openBox(String name) async {
    await _ensureInitialized();
    if (Hive.isBoxOpen(name)) {
      return Hive.box(name);
    }
    return Hive.openBox(name);
  }

  /// Close the database
  Future<void> close() async {
    if (!_initialized) return;
    await Hive.close();
    _initialized = false;
  }

  /// Transaction wrapper (Hive operations are atomic by default)
  Future<T> transaction<T>(Future<T> Function() action) async {
    return action();
  }

  /// Delete all data (for account deletion/reset)
  Future<void> deleteAllData() async {
    await _ensureInitialized();

    final boxes = [
      _transactionsBox,
      _budgetsBox,
      _accountsBox,
      _categoriesBox,
      _groupsBox,
      _groupMembersBox,
      _sharedExpensesBox,
      _splitRecordsBox,
      _settlementsBox,
      _outboxBox,
      _syncMetadataBox,
    ];

    for (final boxName in boxes) {
      final box = await _openBox(boxName);
      await box.clear();
    }
  }

  /// Get database schema version (simulated for web)
  int get schemaVersion => 1;

  // ============================================================================
  // Transaction Entries Operations
  // ============================================================================

  Future<Box<Map<dynamic, dynamic>>> get transactionEntriesBox =>
      _openBox(_transactionsBox);

  // ============================================================================
  // Budget Entries Operations
  // ============================================================================

  Future<Box<Map<dynamic, dynamic>>> get budgetEntriesBox =>
      _openBox(_budgetsBox);

  // ============================================================================
  // Account Entries Operations
  // ============================================================================

  Future<Box<Map<dynamic, dynamic>>> get accountEntriesBox =>
      _openBox(_accountsBox);

  // ============================================================================
  // Outbox Entries Operations
  // ============================================================================

  Future<Box<Map<dynamic, dynamic>>> get outboxEntriesBox =>
      _openBox(_outboxBox);

  // ============================================================================
  // Sync Metadata Operations
  // ============================================================================

  Future<Box<Map<dynamic, dynamic>>> get syncMetadataBox =>
      _openBox(_syncMetadataBox);
}

