import 'package:equatable/equatable.dart';

/// Budget period options
enum BudgetPeriod {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  yearly('Yearly');

  final String displayName;
  const BudgetPeriod(this.displayName);
}

/// Budget entity representing a spending limit for a category
///
/// Supports recurring and one-time budgets with configurable alert thresholds.
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/DOMAIN_API_CONTRACTS.md
class Budget extends Equatable {
  final String id;
  final String categoryId;
  final int limitCents; // Budget limit in smallest currency unit
  final BudgetPeriod period;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final int alertThresholdPercent; // e.g., 80 for 80% warning
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Budget({
    required this.id,
    required this.categoryId,
    required this.limitCents,
    required this.period,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    this.alertThresholdPercent = 80,
    required this.createdAt,
    this.updatedAt,
  });

  /// Get limit in major currency unit (rupees/dollars)
  double get limit => limitCents / 100;

  /// Check if budget is recurring (no end date)
  bool get isRecurring => endDate == null;

  /// Create a copy with updated fields
  Budget copyWith({
    String? id,
    String? categoryId,
    int? limitCents,
    BudgetPeriod? period,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    int? alertThresholdPercent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      limitCents: limitCents ?? this.limitCents,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      alertThresholdPercent:
          alertThresholdPercent ?? this.alertThresholdPercent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        categoryId,
        limitCents,
        period,
        startDate,
        endDate,
        isActive,
        alertThresholdPercent,
        createdAt,
        updatedAt,
      ];
}

