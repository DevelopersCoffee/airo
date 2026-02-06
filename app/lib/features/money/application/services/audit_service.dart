import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Audit log entry for financial operations
class AuditLogEntry {
  final String id;
  final String operation;
  final String entityType;
  final String entityId;
  final String userId;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final String? previousValue;
  final String? newValue;

  const AuditLogEntry({
    required this.id,
    required this.operation,
    required this.entityType,
    required this.entityId,
    required this.userId,
    required this.timestamp,
    this.metadata,
    this.previousValue,
    this.newValue,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'operation': operation,
    'entityType': entityType,
    'entityId': entityId,
    'userId': userId,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
    'previousValue': previousValue,
    'newValue': newValue,
  };

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
    id: json['id'] as String,
    operation: json['operation'] as String,
    entityType: json['entityType'] as String,
    entityId: json['entityId'] as String,
    userId: json['userId'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    metadata: json['metadata'] as Map<String, dynamic>?,
    previousValue: json['previousValue'] as String?,
    newValue: json['newValue'] as String?,
  );
}

/// Audit operation types
class AuditOperations {
  static const String create = 'CREATE';
  static const String update = 'UPDATE';
  static const String delete = 'DELETE';
  static const String budgetDeduction = 'BUDGET_DEDUCTION';
  static const String budgetExceeded = 'BUDGET_EXCEEDED';
  static const String transfer = 'TRANSFER';
  static const String sync = 'SYNC';
}

/// Entity types for audit logging
class AuditEntityTypes {
  static const String transaction = 'TRANSACTION';
  static const String budget = 'BUDGET';
  static const String wallet = 'WALLET';
  static const String account = 'ACCOUNT';
  static const String billSplit = 'BILL_SPLIT';
}

/// Service for audit logging of financial operations
/// Provides tamper-resistant logging with timestamps for compliance
class AuditService {
  static const String _storageKey = 'airo_audit_log';
  static const int _maxEntries = 1000; // Retain last 1000 entries

  final String _userId;

  AuditService({String userId = 'default_user'}) : _userId = userId;

  /// Log a financial operation
  Future<void> log({
    required String operation,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? metadata,
    String? previousValue,
    String? newValue,
  }) async {
    final entry = AuditLogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      operation: operation,
      entityType: entityType,
      entityId: entityId,
      userId: _userId,
      timestamp: DateTime.now(),
      metadata: metadata,
      previousValue: previousValue,
      newValue: newValue,
    );

    await _appendEntry(entry);
  }

  /// Log transaction creation
  Future<void> logTransactionCreated({
    required String transactionId,
    required int amountCents,
    required String category,
    required String description,
  }) async {
    await log(
      operation: AuditOperations.create,
      entityType: AuditEntityTypes.transaction,
      entityId: transactionId,
      metadata: {
        'amountCents': amountCents,
        'category': category,
        'description': description,
      },
    );
  }

  /// Log budget deduction
  Future<void> logBudgetDeduction({
    required String budgetId,
    required String category,
    required int deductionCents,
    required int previousUsedCents,
    required int newUsedCents,
    required int limitCents,
  }) async {
    final percentUsed = (newUsedCents / limitCents * 100).toStringAsFixed(1);
    await log(
      operation: AuditOperations.budgetDeduction,
      entityType: AuditEntityTypes.budget,
      entityId: budgetId,
      metadata: {
        'category': category,
        'deductionCents': deductionCents,
        'limitCents': limitCents,
        'percentUsed': percentUsed,
      },
      previousValue: previousUsedCents.toString(),
      newValue: newUsedCents.toString(),
    );
  }

  /// Log budget exceeded event
  Future<void> logBudgetExceeded({
    required String budgetId,
    required String category,
    required int usedCents,
    required int limitCents,
  }) async {
    final exceededBy = usedCents - limitCents;
    await log(
      operation: AuditOperations.budgetExceeded,
      entityType: AuditEntityTypes.budget,
      entityId: budgetId,
      metadata: {
        'category': category,
        'exceededByCents': exceededBy,
        'usedCents': usedCents,
        'limitCents': limitCents,
      },
    );
  }

  /// Log bill split creation
  Future<void> logBillSplitCreated({
    required String splitId,
    required int totalAmountCents,
    required int participantCount,
    required String? vendor,
  }) async {
    await log(
      operation: AuditOperations.create,
      entityType: AuditEntityTypes.billSplit,
      entityId: splitId,
      metadata: {
        'totalAmountCents': totalAmountCents,
        'participantCount': participantCount,
        'vendor': vendor,
      },
    );
  }

  /// Log wallet operation
  Future<void> logWalletOperation({
    required String walletId,
    required String operation,
    required int previousBalanceCents,
    required int newBalanceCents,
  }) async {
    await log(
      operation: operation,
      entityType: AuditEntityTypes.wallet,
      entityId: walletId,
      previousValue: previousBalanceCents.toString(),
      newValue: newBalanceCents.toString(),
    );
  }

  /// Get recent audit logs
  Future<List<AuditLogEntry>> getRecentLogs({int limit = 50}) async {
    final entries = await _loadEntries();
    return entries.take(limit).toList();
  }

  /// Get logs for a specific entity
  Future<List<AuditLogEntry>> getLogsForEntity(String entityId) async {
    final entries = await _loadEntries();
    return entries.where((e) => e.entityId == entityId).toList();
  }

  /// Get logs by operation type
  Future<List<AuditLogEntry>> getLogsByOperation(String operation) async {
    final entries = await _loadEntries();
    return entries.where((e) => e.operation == operation).toList();
  }

  /// Get logs within date range
  Future<List<AuditLogEntry>> getLogsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final entries = await _loadEntries();
    return entries
        .where((e) => e.timestamp.isAfter(start) && e.timestamp.isBefore(end))
        .toList();
  }

  /// Clear old logs (keep only recent entries)
  Future<void> pruneOldLogs() async {
    final entries = await _loadEntries();
    if (entries.length > _maxEntries) {
      final trimmed = entries.take(_maxEntries).toList();
      await _saveEntries(trimmed);
    }
  }

  // Private methods for storage

  Future<void> _appendEntry(AuditLogEntry entry) async {
    final entries = await _loadEntries();
    entries.insert(0, entry); // Prepend new entry (most recent first)

    // Prune if needed
    final trimmed = entries.length > _maxEntries
        ? entries.take(_maxEntries).toList()
        : entries;

    await _saveEntries(trimmed);
  }

  Future<List<AuditLogEntry>> _loadEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString == null) return [];

      final jsonList = json.decode(jsonString) as List;
      return jsonList
          .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If corrupted, start fresh
      return [];
    }
  }

  Future<void> _saveEntries(List<AuditLogEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }
}
