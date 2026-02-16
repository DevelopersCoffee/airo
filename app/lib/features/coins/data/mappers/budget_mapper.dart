import '../../domain/entities/budget.dart';
import '../datasources/coins_local_datasource.dart';

/// Mapper for Budget entity <-> BudgetEntity conversion
///
/// Phase: 1 (Foundation)
class BudgetMapper {
  /// Convert database entity to domain entity
  Budget toDomain(BudgetEntity entity) {
    return Budget(
      id: entity.id,
      categoryId: entity.categoryId,
      limitCents: entity.limitCents,
      period: _parseBudgetPeriod(entity.period),
      alertThresholdPercent: entity.alertThresholdPercent,
      isActive: entity.isActive,
      startDate: entity.startDate,
      endDate: entity.endDate,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Convert domain entity to database entity
  BudgetEntity toEntity(Budget budget) {
    return BudgetEntity(
      id: budget.id,
      name: budget.categoryId, // Use categoryId as name for database entity
      categoryId: budget.categoryId,
      limitCents: budget.limitCents,
      period: budget.period.name,
      alertThresholdPercent: budget.alertThresholdPercent,
      isActive: budget.isActive,
      currencyCode: 'INR', // Default currency code for database entity
      startDate: budget.startDate,
      endDate: budget.endDate,
      createdAt: budget.createdAt,
      updatedAt: budget.updatedAt,
    );
  }

  BudgetPeriod _parseBudgetPeriod(String period) {
    return BudgetPeriod.values.firstWhere(
      (p) => p.name == period,
      orElse: () => BudgetPeriod.monthly,
    );
  }
}
