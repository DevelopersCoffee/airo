import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:airo_app/core/database/app_database.dart';
import 'package:airo_app/core/utils/result.dart';
import 'package:airo_app/features/money/data/repositories/local_transactions_repository.dart';
import 'package:airo_app/features/money/data/repositories/local_budgets_repository.dart';
import 'package:airo_app/features/money/application/services/expense_service.dart';
import 'package:airo_app/features/money/application/services/audit_service.dart';

void main() {
  late AppDatabase db;
  late LocalTransactionsRepository transactionsRepo;
  late LocalBudgetsRepository budgetsRepo;
  late AuditService auditService;
  late ExpenseService expenseService;

  setUp(() {
    // Initialize SharedPreferences with empty values for testing
    SharedPreferences.setMockInitialValues({});
    // Create in-memory database for testing
    db = AppDatabase.forTesting(NativeDatabase.memory());
    transactionsRepo = LocalTransactionsRepository(db);
    budgetsRepo = LocalBudgetsRepository(db);
    auditService = AuditService(userId: 'test_user');
    expenseService = ExpenseService(
      db,
      transactionsRepo,
      budgetsRepo,
      auditService,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('ExpenseService', () {
    group('saveExpense', () {
      test('should save expense successfully without budget', () async {
        final result = await expenseService.saveExpense(
          accountId: 'acc1',
          timestamp: DateTime.now(),
          amountCents: 2500, // $25.00
          description: 'Coffee',
          category: 'Food & Drink',
        );

        expect(result.isOk, true);
        final expense = (result as Ok).value;
        expect(expense.transaction.amountCents, -2500); // Negative for expense
        expect(expense.transaction.description, 'Coffee');
        expect(expense.budgetStatus, BudgetDeductionStatus.noBudget);
      });

      test('should deduct from budget when expense matches category', () async {
        // Create a budget first
        await budgetsRepo.create(tag: 'Food & Drink', limitCents: 10000);

        final result = await expenseService.saveExpense(
          accountId: 'acc1',
          timestamp: DateTime.now(),
          amountCents: 2500,
          description: 'Lunch',
          category: 'Food & Drink',
        );

        expect(result.isOk, true);
        final expense = (result as Ok).value;
        expect(expense.budgetStatus, BudgetDeductionStatus.success);
        expect(expense.budget, isNotNull);
        expect(expense.budget!.usedCents, 2500);
      });

      test('should mark budget as exceeded when limit reached', () async {
        // Create a budget with low limit
        await budgetsRepo.create(tag: 'Food & Drink', limitCents: 2000);

        final result = await expenseService.saveExpense(
          accountId: 'acc1',
          timestamp: DateTime.now(),
          amountCents: 2500, // More than budget
          description: 'Expensive lunch',
          category: 'Food & Drink',
        );

        expect(result.isOk, true);
        final expense = (result as Ok).value;
        expect(expense.budgetStatus, BudgetDeductionStatus.exceededLimit);
        expect(expense.isBudgetExceeded, true);
        expect(expense.budget!.isExceeded, true);
      });

      test('should convert positive amount to negative for expense', () async {
        final result = await expenseService.saveExpense(
          accountId: 'acc1',
          timestamp: DateTime.now(),
          amountCents: 1000, // Positive input
          description: 'Test',
          category: 'Other',
        );

        expect(result.isOk, true);
        final expense = (result as Ok).value;
        expect(expense.transaction.amountCents, -1000); // Should be negative
      });
    });

    group('saveIncome', () {
      test('should save income with positive amount', () async {
        final result = await expenseService.saveIncome(
          accountId: 'acc1',
          timestamp: DateTime.now(),
          amountCents: 500000, // $5000
          description: 'Salary',
          category: 'Income',
        );

        expect(result.isOk, true);
        final income = (result as Ok).value;
        expect(income.amountCents, 500000);
        expect(income.isIncome, true);
      });
    });
  });

  group('LocalTransactionsRepository', () {
    test('should create and fetch transaction', () async {
      final createResult = await transactionsRepo.create(
        accountId: 'acc1',
        timestamp: DateTime.now(),
        amountCents: -1500,
        description: 'Test transaction',
        category: 'Test',
      );

      expect(createResult.isOk, true);
      final created = (createResult as Ok).value;

      final fetchResult = await transactionsRepo.fetchById(created.id);
      expect(fetchResult.isOk, true);
      final fetched = (fetchResult as Ok).value;
      expect(fetched.description, 'Test transaction');
    });

    test('should return pending sync transactions', () async {
      await transactionsRepo.create(
        accountId: 'acc1',
        timestamp: DateTime.now(),
        amountCents: -100,
        description: 'Pending',
        category: 'Test',
      );

      final pending = await transactionsRepo.getPendingSync();
      expect(pending.length, 1);
      expect(pending.first.description, 'Pending');
    });
  });
}
