// ignore_for_file: avoid_unused_constructor_parameters

/// Web-compatible database facade.
///
/// The v2 storage policy does not allow new Hive persistence. Web builds keep
/// this lightweight in-memory adapter until a queryable IndexedDB/Drift-backed
/// web store is selected and migrated explicitly.
library;

/// Sync status for offline-first support.
enum SyncStatus { pending, synced, failed }

/// Database configuration (web implementation).
class DatabaseConfig {
  /// Whether to use encrypted database (not supported on web).
  static bool useEncryption = false;

  /// Encryption key (not used on web).
  static String? _encryptionKey;

  /// Set the encryption key (no-op on web).
  static void setEncryptionKey(String key) {
    _encryptionKey = key;
  }

  /// Get the encryption key.
  static String? get encryptionKey => _encryptionKey;
}

/// Small named in-memory store used by the web database facade.
///
/// This intentionally exposes only deterministic map-like operations instead
/// of a Hive-compatible API so web callers do not accidentally depend on Hive
/// persistence semantics.
class AiroWebDatabaseStore {
  AiroWebDatabaseStore(this.name);

  final String name;
  final Map<String, Map<String, Object?>> _records =
      <String, Map<String, Object?>>{};

  int get length => _records.length;

  bool containsKey(String key) => _records.containsKey(key);

  Map<String, Object?>? get(String key) {
    final value = _records[key];
    return value == null ? null : Map<String, Object?>.from(value);
  }

  Future<void> put(String key, Map<String, Object?> value) async {
    _records[key] = Map<String, Object?>.from(value);
  }

  Future<void> delete(String key) async {
    _records.remove(key);
  }

  Future<void> clear() async {
    _records.clear();
  }

  List<Map<String, Object?>> values() {
    return _records.values
        .map((value) => Map<String, Object?>.from(value))
        .toList(growable: false);
  }
}

/// Web-compatible database facade.
class AppDatabase {
  static AppDatabase? _instance;

  static const String _transactionsStore = 'transaction_entries';
  static const String _budgetsStore = 'budget_entries';
  static const String _accountsStore = 'account_entries';
  static const String _categoriesStore = 'category_entries';
  static const String _groupsStore = 'group_entries';
  static const String _groupMembersStore = 'group_member_entries';
  static const String _sharedExpensesStore = 'shared_expense_entries';
  static const String _splitRecordsStore = 'split_entry_records';
  static const String _settlementsStore = 'settlement_entries';
  static const String _outboxStore = 'outbox_entries';
  static const String _syncMetadataStore = 'sync_metadata';

  final Map<String, AiroWebDatabaseStore> _stores =
      <String, AiroWebDatabaseStore>{};

  AppDatabase._();

  /// Factory constructor that returns singleton.
  factory AppDatabase() {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  /// For testing - allows custom initialization.
  AppDatabase.forTesting(dynamic e);

  AiroWebDatabaseStore _openStore(String name) {
    return _stores.putIfAbsent(name, () => AiroWebDatabaseStore(name));
  }

  /// Close the database.
  Future<void> close() async {
    _stores.clear();
    if (identical(_instance, this)) {
      _instance = null;
    }
  }

  /// Transaction wrapper.
  Future<T> transaction<T>(Future<T> Function() action) async {
    return action();
  }

  /// Delete all data (for account deletion/reset).
  Future<void> deleteAllData() async {
    for (final storeName in _storeNames) {
      await _openStore(storeName).clear();
    }
  }

  /// Get database schema version.
  int get schemaVersion => 1;

  Future<AiroWebDatabaseStore> get transactionEntriesBox async =>
      _openStore(_transactionsStore);

  Future<AiroWebDatabaseStore> get budgetEntriesBox async =>
      _openStore(_budgetsStore);

  Future<AiroWebDatabaseStore> get accountEntriesBox async =>
      _openStore(_accountsStore);

  Future<AiroWebDatabaseStore> get outboxEntriesBox async =>
      _openStore(_outboxStore);

  Future<AiroWebDatabaseStore> get syncMetadataBox async =>
      _openStore(_syncMetadataStore);

  List<String> get _storeNames => const <String>[
    _transactionsStore,
    _budgetsStore,
    _accountsStore,
    _categoriesStore,
    _groupsStore,
    _groupMembersStore,
    _sharedExpensesStore,
    _splitRecordsStore,
    _settlementsStore,
    _outboxStore,
    _syncMetadataStore,
  ];
}
