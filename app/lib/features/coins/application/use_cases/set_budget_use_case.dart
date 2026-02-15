import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';

/// Result type for use case operations
typedef Result<T> = ({T? data, String? error});

/// Use case for setting/updating a budget
///
/// Handles creation or update of budget for a category.
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/DOMAIN_API_CONTRACTS.md
class SetBudgetUseCase {
  final BudgetRepository _repository;

  SetBudgetUseCase(this._repository);

  /// Execute the use case
  ///
  /// Creates a new budget or updates existing one for the category.
  Future<Result<Budget>> execute(SetBudgetParams params) async {
    // Validate
    if (params.categoryId.isEmpty) {
      return (data: null, error: 'Category is required');
    }

    if (params.limitCents <= 0) {
      return (data: null, error: 'Budget limit must be greater than zero');
    }

    if (params.alertThresholdPercent < 0 ||
        params.alertThresholdPercent > 100) {
      return (data: null, error: 'Alert threshold must be between 0 and 100');
    }

    // Check if budget already exists for this category
    final existingResult = await _repository.findByCategory(params.categoryId);
    final existing = existingResult.data;

    final now = DateTime.now();

    if (existing != null) {
      // Update existing budget
      final updated = Budget(
        id: existing.id,
        name: params.name ?? existing.name,
        categoryId: existing.categoryId,
        limitCents: params.limitCents,
        period: params.period ?? existing.period,
        alertThresholdPercent:
            params.alertThresholdPercent ?? existing.alertThresholdPercent,
        isActive: params.isActive ?? existing.isActive,
        currencyCode: params.currencyCode ?? existing.currencyCode,
        startDate: existing.startDate,
        endDate: params.endDate ?? existing.endDate,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
      return _repository.update(updated);
    } else {
      // Create new budget
      final budget = Budget(
        id: _generateId(),
        name: params.name ?? 'Budget for ${params.categoryId}',
        categoryId: params.categoryId,
        limitCents: params.limitCents,
        period: params.period ?? BudgetPeriod.monthly,
        alertThresholdPercent: params.alertThresholdPercent ?? 80,
        isActive: params.isActive ?? true,
        currencyCode: params.currencyCode ?? 'INR',
        startDate: params.startDate ?? now,
        endDate: params.endDate,
        createdAt: now,
      );
      return _repository.create(budget);
    }
  }

  String _generateId() {
    return 'budget_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Parameters for setting a budget
class SetBudgetParams {
  final String? name;
  final String categoryId;
  final int limitCents;
  final BudgetPeriod? period;
  final int? alertThresholdPercent;
  final bool? isActive;
  final String? currencyCode;
  final DateTime? startDate;
  final DateTime? endDate;

  const SetBudgetParams({
    this.name,
    required this.categoryId,
    required this.limitCents,
    this.period,
    this.alertThresholdPercent,
    this.isActive,
    this.currencyCode,
    this.startDate,
    this.endDate,
  });
}

