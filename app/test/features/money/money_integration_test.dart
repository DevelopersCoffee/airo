import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:airo_app/core/database/app_database.dart';
import 'package:airo_app/features/money/data/repositories/local_transactions_repository.dart';
import 'package:airo_app/features/money/data/repositories/local_budgets_repository.dart';
import 'package:airo_app/features/money/application/services/expense_service.dart';
import 'package:airo_app/features/money/application/services/insights_service.dart';
import 'package:airo_app/features/money/application/services/audit_service.dart';

/// Integration tests for the complete money feature flow
void main() {
  late AppDatabase db;
  late LocalTransactionsRepository transactionsRepo;
  late LocalBudgetsRepository budgetsRepo;
  late AuditService auditService;
  late ExpenseService expenseService;
  late InsightsService insightsService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    transactionsRepo = LocalTransactionsRepository(db);
    budgetsRepo = LocalBudgetsRepository(db);
    auditService = AuditService(userId: 'test_user');
    expenseService = ExpenseService(db, transactionsRepo, budgetsRepo, auditService);
    insightsService = InsightsService(transactionsRepo, budgetsRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('Complete Expense Flow', () {
    test('expense creation with budget deduction is atomic', () async {
      // Create a budget
      await budgetsRepo.create(tag: 'Food & Drink', limitCents: 50000);

      // Save multiple expenses
      for (int i = 0; i < 5; i++) {
        await expenseService.saveExpense(
          accountId: 'acc1',
          timestamp: DateTime.now(),
          amountCents: 1000,
          description: 'Expense $i',
          category: 'Food & Drink',
        );
      }

      // Verify budget was updated correctly
      final budgetResult = await budgetsRepo.fetchByTag('Food & Drink');
      final budget = budgetResult.getOrNull()!;
      expect(budget.usedCents, 5000); // 5 x $10
    });

    test('insights service calculates correct summary', () async {
      // Add some transactions
      await transactionsRepo.create(
        accountId: 'acc1',
        timestamp: DateTime.now(),
        amountCents: -5000, // $50 expense
        description: 'Groceries',
        category: 'Food & Drink',
      );
      await transactionsRepo.create(
        accountId: 'acc1',
        timestamp: DateTime.now(),
        amountCents: -2000, // $20 expense
        description: 'Coffee',
        category: 'Food & Drink',
      );
      await transactionsRepo.create(
        accountId: 'acc1',
        timestamp: DateTime.now(),
        amountCents: 100000, // $1000 income
        description: 'Salary',
        category: 'Income',
      );

      // Get summary
      final summary = await insightsService.getSpendingSummary();

      expect(summary.totalExpenses, 7000);
      expect(summary.totalIncome, 100000);
      expect(summary.netChange, 93000);
      expect(summary.transactionCount, 3);
    });

    test('budget health reflects exceeded budgets', () async {
      // Create budget and exceed it
      await budgetsRepo.create(tag: 'Entertainment', limitCents: 5000);
      
      await expenseService.saveExpense(
        accountId: 'acc1',
        timestamp: DateTime.now(),
        amountCents: 7500, // Exceeds budget
        description: 'Concert tickets',
        category: 'Entertainment',
      );

      final health = await insightsService.getBudgetHealth();
      
      expect(health.exceededBudgets, 1);
      expect(health.hasExceeded, true);
      expect(health.insights.any((i) => i.category == 'Entertainment'), true);
    });

    test('pending sync transactions are tracked', () async {
      // Create transaction
      await transactionsRepo.create(
        accountId: 'acc1',
        timestamp: DateTime.now(),
        amountCents: -1000,
        description: 'Test',
        category: 'Other',
      );

      // Check pending
      final pending = await transactionsRepo.getPendingSync();
      expect(pending.length, 1);

      // Mark as synced
      await transactionsRepo.markSynced(pending.first.id);

      // Check no more pending
      final afterSync = await transactionsRepo.getPendingSync();
      expect(afterSync.length, 0);
    });
  });

  group('Budget Validation', () {
    test('prevents duplicate budgets', () async {
      await budgetsRepo.create(tag: 'Shopping', limitCents: 20000);
      
      final duplicate = await budgetsRepo.create(
        tag: 'Shopping',
        limitCents: 30000,
      );
      
      expect(duplicate.isErr, true);
    });

    test('rejects invalid budget amounts', () async {
      final zero = await budgetsRepo.create(tag: 'Test1', limitCents: 0);
      final negative = await budgetsRepo.create(tag: 'Test2', limitCents: -100);
      
      expect(zero.isErr, true);
      expect(negative.isErr, true);
    });
  });
}

