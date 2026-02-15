import 'package:equatable/equatable.dart';
import '../entities/budget.dart';

/// Budget status model
///
/// Represents the current status of a budget including spend progress.
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/DOMAIN_API_CONTRACTS.md
class BudgetStatus extends Equatable {
  final Budget budget;
  final int spentCents;
  final int remainingCents;
  final double percentUsed;
  final bool isOverBudget;
  final bool isWarning;
  final int transactionCount;
  final DateTime periodStart;
  final DateTime periodEnd;

  const BudgetStatus({
    required this.budget,
    required this.spentCents,
    required this.remainingCents,
    required this.percentUsed,
    required this.isOverBudget,
    required this.isWarning,
    required this.transactionCount,
    required this.periodStart,
    required this.periodEnd,
  });

  /// Get spent amount in major currency unit
  double get spent => spentCents / 100;

  /// Get remaining amount in major currency unit
  double get remaining => remainingCents / 100;

  /// Get the amount over budget (if any)
  int get overBudgetCents => isOverBudget ? (spentCents - budget.limitCents) : 0;

  /// Get days remaining in the budget period
  int daysRemaining(DateTime now) => periodEnd.difference(now).inDays;

  /// Calculate daily allowance for remaining days
  int dailyAllowanceCents(DateTime now) {
    final days = daysRemaining(now);
    if (days <= 0 || remainingCents <= 0) return 0;
    return remainingCents ~/ days;
  }

  /// Create from budget and transactions
  factory BudgetStatus.calculate({
    required Budget budget,
    required int spentCents,
    required int transactionCount,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final remainingCents = budget.limitCents - spentCents;
    final percentUsed = budget.limitCents > 0
        ? (spentCents / budget.limitCents) * 100
        : 0.0;
    final isOverBudget = spentCents > budget.limitCents;
    final isWarning = percentUsed >= budget.alertThresholdPercent;

    return BudgetStatus(
      budget: budget,
      spentCents: spentCents,
      remainingCents: remainingCents,
      percentUsed: percentUsed,
      isOverBudget: isOverBudget,
      isWarning: isWarning,
      transactionCount: transactionCount,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }

  @override
  List<Object?> get props => [
        budget,
        spentCents,
        remainingCents,
        percentUsed,
        isOverBudget,
        isWarning,
        transactionCount,
        periodStart,
        periodEnd,
      ];
}

