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
  final String? name;
  final String categoryId;
  final int limitCents; // Budget limit in smallest currency unit
  final String currencyCode;
  final BudgetPeriod period;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final int alertThresholdPercent; // e.g., 80 for 80% warning
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Budget({
    required this.id,
    this.name,
    required this.categoryId,
    required this.limitCents,
    this.currencyCode = 'INR',
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

  /// Display name used by budget UI.
  String get displayName => name ?? categoryId;

  /// Check if budget is recurring (no end date)
  bool get isRecurring => endDate == null;

  /// Create a copy with updated fields
  Budget copyWith({
    String? id,
    String? name,
    String? categoryId,
    int? limitCents,
    String? currencyCode,
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
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      limitCents: limitCents ?? this.limitCents,
      currencyCode: currencyCode ?? this.currencyCode,
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
    name,
    categoryId,
    limitCents,
    currencyCode,
    period,
    startDate,
    endDate,
    isActive,
    alertThresholdPercent,
    createdAt,
    updatedAt,
  ];
}
