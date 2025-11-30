import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/money/domain/models/money_models.dart';

void main() {
  group('Budget Warning Levels', () {
    Budget createBudget({required int limitCents, required int usedCents}) {
      return Budget(
        id: 'test_budget',
        tag: 'Test Category',
        limitCents: limitCents,
        usedCents: usedCents,
        periodStart: DateTime.now(),
        periodEnd: DateTime.now().add(const Duration(days: 30)),
        periodType: BudgetPeriodType.monthly,
        carryover: CarryoverBehavior.none,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    test('should return normal level when under 80%', () {
      final budget = createBudget(limitCents: 10000, usedCents: 5000); // 50%
      
      expect(budget.warningLevel, BudgetWarningLevel.normal);
      expect(budget.isApproachingLimit, false);
      expect(budget.isExceeded, false);
    });

    test('should return normal level at exactly 79%', () {
      final budget = createBudget(limitCents: 10000, usedCents: 7900); // 79%
      
      expect(budget.warningLevel, BudgetWarningLevel.normal);
      expect(budget.isApproachingLimit, false);
    });

    test('should return warning level at 80%', () {
      final budget = createBudget(limitCents: 10000, usedCents: 8000); // 80%
      
      expect(budget.warningLevel, BudgetWarningLevel.warning);
      expect(budget.isApproachingLimit, true);
      expect(budget.isExceeded, false);
    });

    test('should return warning level at 90%', () {
      final budget = createBudget(limitCents: 10000, usedCents: 9000); // 90%
      
      expect(budget.warningLevel, BudgetWarningLevel.warning);
      expect(budget.isApproachingLimit, true);
      expect(budget.isExceeded, false);
    });

    test('should return warning level at 99%', () {
      final budget = createBudget(limitCents: 10000, usedCents: 9900); // 99%
      
      expect(budget.warningLevel, BudgetWarningLevel.warning);
      expect(budget.isApproachingLimit, true);
      expect(budget.isExceeded, false);
    });

    test('should return exceeded level at 100%', () {
      final budget = createBudget(limitCents: 10000, usedCents: 10000); // 100%
      
      expect(budget.warningLevel, BudgetWarningLevel.normal);
      expect(budget.isApproachingLimit, false);
      expect(budget.isExceeded, false);
    });

    test('should return exceeded level when over 100%', () {
      final budget = createBudget(limitCents: 10000, usedCents: 12000); // 120%
      
      expect(budget.warningLevel, BudgetWarningLevel.exceeded);
      expect(budget.isApproachingLimit, false); // Not approaching, already exceeded
      expect(budget.isExceeded, true);
    });

    test('should calculate remaining cents correctly', () {
      final budget = createBudget(limitCents: 10000, usedCents: 7500);
      
      expect(budget.remainingCents, 2500);
    });

    test('should return 0 remaining when exceeded', () {
      final budget = createBudget(limitCents: 10000, usedCents: 12000);
      
      expect(budget.remainingCents, 0);
    });

    test('should calculate percentage correctly', () {
      final budget = createBudget(limitCents: 10000, usedCents: 8500);
      
      expect(budget.percentageUsed, 0.85);
      expect(budget.percentageUsedClamped, 0.85);
    });

    test('should clamp percentage at 1.0 when exceeded', () {
      final budget = createBudget(limitCents: 10000, usedCents: 15000);
      
      expect(budget.percentageUsed, 1.5);
      expect(budget.percentageUsedClamped, 1.0);
    });
  });

  group('BudgetWarningLevel enum', () {
    test('should have all expected values', () {
      expect(BudgetWarningLevel.values.length, 3);
      expect(BudgetWarningLevel.values, contains(BudgetWarningLevel.normal));
      expect(BudgetWarningLevel.values, contains(BudgetWarningLevel.warning));
      expect(BudgetWarningLevel.values, contains(BudgetWarningLevel.exceeded));
    });
  });
}

