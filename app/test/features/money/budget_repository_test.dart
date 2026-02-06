import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:airo_app/core/database/app_database.dart';
import 'package:airo_app/core/utils/result.dart';
import 'package:airo_app/features/money/data/repositories/local_budgets_repository.dart';

void main() {
  late AppDatabase db;
  late LocalBudgetsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = LocalBudgetsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('LocalBudgetsRepository', () {
    group('create', () {
      test('should create budget with zero used cents', () async {
        final result = await repo.create(
          tag: 'Food & Drink',
          limitCents: 50000,
        );

        expect(result.isOk, true);
        final budget = (result as Ok).value;
        expect(budget.tag, 'Food & Drink');
        expect(budget.limitCents, 50000);
        expect(budget.usedCents, 0);
        expect(budget.isExceeded, false);
      });

      test('should reject duplicate budget for same category', () async {
        await repo.create(tag: 'Food & Drink', limitCents: 50000);

        final duplicateResult = await repo.create(
          tag: 'Food & Drink',
          limitCents: 30000,
        );

        expect(duplicateResult.isErr, true);
      });

      test('should reject non-positive limit', () async {
        final result = await repo.create(tag: 'Test', limitCents: 0);

        expect(result.isErr, true);
      });

      test('should reject negative limit', () async {
        final result = await repo.create(tag: 'Test', limitCents: -100);

        expect(result.isErr, true);
      });
    });

    group('fetchAll', () {
      test('should return all budgets for current month', () async {
        await repo.create(tag: 'Food', limitCents: 10000);
        await repo.create(tag: 'Transport', limitCents: 5000);

        final result = await repo.fetchAll();
        expect(result.isOk, true);
        final budgets = (result as Ok).value;
        expect(budgets.length, 2);
      });
    });

    group('fetchByTag', () {
      test('should return budget matching tag', () async {
        await repo.create(tag: 'Entertainment', limitCents: 20000);

        final result = await repo.fetchByTag('Entertainment');
        expect(result.isOk, true);
        final budget = (result as Ok).value;
        expect(budget, isNotNull);
        expect(budget!.tag, 'Entertainment');
      });

      test('should return null for non-existent tag', () async {
        final result = await repo.fetchByTag('NonExistent');
        expect(result.isOk, true);
        expect((result as Ok).value, isNull);
      });
    });

    group('updateUsage', () {
      test('should update used cents', () async {
        final createResult = await repo.create(
          tag: 'Shopping',
          limitCents: 30000,
        );
        final created = (createResult as Ok).value;

        final updateResult = await repo.updateUsage(created.id, 15000);
        expect(updateResult.isOk, true);
        final updated = (updateResult as Ok).value;
        expect(updated.usedCents, 15000);
        expect(updated.percentageUsed, 0.5);
      });

      test('should allow exceeding limit', () async {
        final createResult = await repo.create(tag: 'Bills', limitCents: 10000);
        final created = (createResult as Ok).value;

        final updateResult = await repo.updateUsage(created.id, 15000);
        expect(updateResult.isOk, true);
        final updated = (updateResult as Ok).value;
        expect(updated.usedCents, 15000);
        expect(updated.isExceeded, true);
      });
    });

    group('deductFromBudget', () {
      test('should deduct expense amount from budget', () async {
        await repo.create(tag: 'Food & Drink', limitCents: 50000);

        final result = await repo.deductFromBudget('Food & Drink', -2500);
        expect(result.isOk, true);
        expect((result as Ok).value, true);

        // Verify the deduction
        final budgetResult = await repo.fetchByTag('Food & Drink');
        final budget = (budgetResult as Ok).value!;
        expect(budget.usedCents, 2500);
      });

      test('should return false when no matching budget', () async {
        final result = await repo.deductFromBudget('NonExistent', -1000);
        expect(result.isOk, true);
        expect((result as Ok).value, false);
      });
    });

    group('delete', () {
      test('should delete budget', () async {
        final createResult = await repo.create(
          tag: 'ToDelete',
          limitCents: 1000,
        );
        final created = (createResult as Ok).value;

        await repo.delete(created.id);

        final fetchResult = await repo.fetchById(created.id);
        expect(fetchResult.isErr, true);
      });
    });

    group('update', () {
      test('should update budget limit', () async {
        final createResult = await repo.create(
          tag: 'Education',
          limitCents: 10000,
        );
        final created = (createResult as Ok).value;

        final updated = created.copyWith(limitCents: 20000);
        await repo.update(updated);

        final fetchResult = await repo.fetchById(created.id);
        final fetched = (fetchResult as Ok).value;
        expect(fetched.limitCents, 20000);
      });
    });
  });
}
