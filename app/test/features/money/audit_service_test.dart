import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airo_app/features/money/application/services/audit_service.dart';

void main() {
  setUp(() {
    // Initialize SharedPreferences with empty values for testing
    SharedPreferences.setMockInitialValues({});
  });

  group('AuditService', () {
    test('should log transaction creation', () async {
      final auditService = AuditService(userId: 'test_user');

      await auditService.logTransactionCreated(
        transactionId: 'txn_123',
        amountCents: 2500,
        category: 'Food & Drink',
        description: 'Coffee',
      );

      final logs = await auditService.getRecentLogs(limit: 10);
      expect(logs.length, 1);
      expect(logs.first.operation, AuditOperations.create);
      expect(logs.first.entityType, AuditEntityTypes.transaction);
      expect(logs.first.entityId, 'txn_123');
      expect(logs.first.userId, 'test_user');
    });

    test('should log budget deduction', () async {
      final auditService = AuditService(userId: 'test_user');

      await auditService.logBudgetDeduction(
        budgetId: 'budget_123',
        category: 'Food & Drink',
        deductionCents: 2500,
        previousUsedCents: 5000,
        newUsedCents: 7500,
        limitCents: 10000,
      );

      final logs = await auditService.getRecentLogs(limit: 10);
      expect(logs.length, 1);
      expect(logs.first.operation, AuditOperations.budgetDeduction);
      expect(logs.first.entityType, AuditEntityTypes.budget);
      expect(logs.first.previousValue, '5000');
      expect(logs.first.newValue, '7500');
    });

    test('should log budget exceeded event', () async {
      final auditService = AuditService(userId: 'test_user');

      await auditService.logBudgetExceeded(
        budgetId: 'budget_123',
        category: 'Food & Drink',
        usedCents: 12000,
        limitCents: 10000,
      );

      final logs = await auditService.getRecentLogs(limit: 10);
      expect(logs.length, 1);
      expect(logs.first.operation, AuditOperations.budgetExceeded);
      expect(logs.first.metadata!['exceededByCents'], 2000);
    });

    test('should log bill split creation', () async {
      final auditService = AuditService(userId: 'test_user');

      await auditService.logBillSplitCreated(
        splitId: 'split_123',
        totalAmountCents: 50000,
        participantCount: 4,
        vendor: 'Restaurant ABC',
      );

      final logs = await auditService.getRecentLogs(limit: 10);
      expect(logs.length, 1);
      expect(logs.first.operation, AuditOperations.create);
      expect(logs.first.entityType, AuditEntityTypes.billSplit);
      expect(logs.first.metadata!['participantCount'], 4);
    });

    test('should retrieve logs by entity ID', () async {
      final auditService = AuditService(userId: 'test_user');

      await auditService.logTransactionCreated(
        transactionId: 'txn_001',
        amountCents: 1000,
        category: 'Test',
        description: 'Test 1',
      );
      await auditService.logTransactionCreated(
        transactionId: 'txn_002',
        amountCents: 2000,
        category: 'Test',
        description: 'Test 2',
      );

      final logs = await auditService.getLogsForEntity('txn_001');
      expect(logs.length, 1);
      expect(logs.first.entityId, 'txn_001');
    });

    test('should retrieve logs by operation type', () async {
      final auditService = AuditService(userId: 'test_user');

      await auditService.logTransactionCreated(
        transactionId: 'txn_001',
        amountCents: 1000,
        category: 'Test',
        description: 'Test',
      );
      await auditService.logBudgetExceeded(
        budgetId: 'budget_001',
        category: 'Test',
        usedCents: 12000,
        limitCents: 10000,
      );

      final exceededLogs = await auditService.getLogsByOperation(AuditOperations.budgetExceeded);
      expect(exceededLogs.length, 1);
      expect(exceededLogs.first.entityType, AuditEntityTypes.budget);
    });

    test('should retrieve logs within date range', () async {
      final auditService = AuditService(userId: 'test_user');

      await auditService.logTransactionCreated(
        transactionId: 'txn_001',
        amountCents: 1000,
        category: 'Test',
        description: 'Test',
      );

      final now = DateTime.now();
      final logs = await auditService.getLogsByDateRange(
        now.subtract(const Duration(hours: 1)),
        now.add(const Duration(hours: 1)),
      );
      expect(logs.length, 1);
    });

    test('should maintain order (most recent first)', () async {
      final auditService = AuditService(userId: 'test_user');

      await auditService.logTransactionCreated(
        transactionId: 'txn_001',
        amountCents: 1000,
        category: 'Test',
        description: 'First',
      );
      await auditService.logTransactionCreated(
        transactionId: 'txn_002',
        amountCents: 2000,
        category: 'Test',
        description: 'Second',
      );

      final logs = await auditService.getRecentLogs(limit: 10);
      expect(logs.length, 2);
      expect(logs.first.entityId, 'txn_002'); // Most recent first
      expect(logs.last.entityId, 'txn_001');
    });
  });

  group('AuditLogEntry', () {
    test('should serialize and deserialize correctly', () {
      final entry = AuditLogEntry(
        id: '123',
        operation: AuditOperations.create,
        entityType: AuditEntityTypes.transaction,
        entityId: 'txn_001',
        userId: 'user_001',
        timestamp: DateTime(2024, 1, 15, 10, 30),
        metadata: {'amountCents': 1000},
        previousValue: null,
        newValue: 'created',
      );

      final json = entry.toJson();
      final restored = AuditLogEntry.fromJson(json);

      expect(restored.id, entry.id);
      expect(restored.operation, entry.operation);
      expect(restored.entityType, entry.entityType);
      expect(restored.entityId, entry.entityId);
      expect(restored.userId, entry.userId);
      expect(restored.metadata!['amountCents'], 1000);
    });
  });
}

