import 'package:equatable/equatable.dart';

/// Budget health status
enum BudgetHealth {
  healthy('Healthy', 0.7), // < 70% used
  warning('Warning', 0.9), // 70-90% used
  critical('Critical', 1.0); // > 90% used

  final String displayName;
  final double threshold;
  const BudgetHealth(this.displayName, this.threshold);
}

/// Safe-to-spend calculation result
///
/// Represents how much money is safe to spend today based on budgets.
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/TDD_MIND_INTERFACE.md
class SafeToSpend extends Equatable {
  final int amountCents;
  final int dailyLimitCents;
  final int spentTodayCents;
  final int spentThisMonthCents;
  final int monthlyBudgetCents;
  final int daysRemaining;
  final double percentUsed;
  final BudgetHealth health;
  final DateTime calculatedAt;

  const SafeToSpend({
    required this.amountCents,
    required this.dailyLimitCents,
    required this.spentTodayCents,
    required this.spentThisMonthCents,
    required this.monthlyBudgetCents,
    required this.daysRemaining,
    required this.percentUsed,
    required this.health,
    required this.calculatedAt,
  });

  /// Get safe-to-spend in major currency unit
  double get amount => amountCents / 100;

  /// Get daily limit in major currency unit
  double get dailyLimit => dailyLimitCents / 100;

  /// Get spent today in major currency unit
  double get spentToday => spentTodayCents / 100;

  /// Get monthly budget in major currency unit
  double get monthlyBudget => monthlyBudgetCents / 100;

  /// Check if user has exceeded budget
  bool get isOverBudget => amountCents < 0;

  /// Get amount remaining for the month
  int get remainingCents => monthlyBudgetCents - spentThisMonthCents;

  /// Create a copy with updated fields
  SafeToSpend copyWith({
    int? amountCents,
    int? dailyLimitCents,
    int? spentTodayCents,
    int? spentThisMonthCents,
    int? monthlyBudgetCents,
    int? daysRemaining,
    double? percentUsed,
    BudgetHealth? health,
    DateTime? calculatedAt,
  }) {
    return SafeToSpend(
      amountCents: amountCents ?? this.amountCents,
      dailyLimitCents: dailyLimitCents ?? this.dailyLimitCents,
      spentTodayCents: spentTodayCents ?? this.spentTodayCents,
      spentThisMonthCents: spentThisMonthCents ?? this.spentThisMonthCents,
      monthlyBudgetCents: monthlyBudgetCents ?? this.monthlyBudgetCents,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      percentUsed: percentUsed ?? this.percentUsed,
      health: health ?? this.health,
      calculatedAt: calculatedAt ?? this.calculatedAt,
    );
  }

  @override
  List<Object?> get props => [
        amountCents,
        dailyLimitCents,
        spentTodayCents,
        spentThisMonthCents,
        monthlyBudgetCents,
        daysRemaining,
        percentUsed,
        health,
        calculatedAt,
      ];
}

