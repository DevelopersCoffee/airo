import 'package:equatable/equatable.dart';

/// Spending summary for a date range
class SpendingSummary extends Equatable {
  final DateTime startDate;
  final DateTime endDate;
  final int totalExpenses;
  final int totalIncome;
  final int netChange;
  final int transactionCount;
  final int dailyAverage;
  final List<CategorySpending> topCategories;
  final Map<DateTime, int> dailySpending;

  const SpendingSummary({
    required this.startDate,
    required this.endDate,
    required this.totalExpenses,
    required this.totalIncome,
    required this.netChange,
    required this.transactionCount,
    required this.dailyAverage,
    required this.topCategories,
    required this.dailySpending,
  });

  String get totalExpensesFormatted => _formatCurrency(totalExpenses);
  String get totalIncomeFormatted => _formatCurrency(totalIncome);
  String get netChangeFormatted => _formatCurrency(netChange);
  String get dailyAverageFormatted => _formatCurrency(dailyAverage);

  bool get isPositive => netChange >= 0;

  static String _formatCurrency(int cents) {
    final isNegative = cents < 0;
    final absCents = cents.abs();
    final dollars = absCents ~/ 100;
    final remaining = absCents % 100;
    final formatted = '\$$dollars.${remaining.toString().padLeft(2, '0')}';
    return isNegative ? '-$formatted' : formatted;
  }

  @override
  List<Object?> get props => [startDate, endDate, totalExpenses, totalIncome];
}

/// Spending breakdown by category
class CategorySpending extends Equatable {
  final String category;
  final int amountCents;

  const CategorySpending({
    required this.category,
    required this.amountCents,
  });

  String get amountFormatted {
    final dollars = amountCents ~/ 100;
    final cents = amountCents % 100;
    return '\$$dollars.${cents.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [category, amountCents];
}

/// Budget health overview
class BudgetHealth extends Equatable {
  final int totalBudgets;
  final int healthyBudgets;
  final int warningBudgets;
  final int exceededBudgets;
  final int overallHealthScore; // 0-100
  final List<BudgetInsight> insights;

  const BudgetHealth({
    required this.totalBudgets,
    required this.healthyBudgets,
    required this.warningBudgets,
    required this.exceededBudgets,
    required this.overallHealthScore,
    required this.insights,
  });

  bool get isHealthy => exceededBudgets == 0 && warningBudgets == 0;
  bool get hasWarnings => warningBudgets > 0;
  bool get hasExceeded => exceededBudgets > 0;

  @override
  List<Object?> get props => [totalBudgets, healthyBudgets, warningBudgets, exceededBudgets];
}

/// Individual budget insight
class BudgetInsight extends Equatable {
  final InsightType type;
  final String message;
  final String category;
  final InsightSeverity severity;

  const BudgetInsight({
    required this.type,
    required this.message,
    required this.category,
    required this.severity,
  });

  @override
  List<Object?> get props => [type, message, category, severity];
}

enum InsightType {
  exceeded,
  warning,
  saving,
  trend,
  tip,
}

enum InsightSeverity {
  low,
  medium,
  high,
}

/// Spending trend comparison
class SpendingTrend extends Equatable {
  final SpendingSummary currentPeriod;
  final SpendingSummary previousPeriod;
  final int expenseChangePercent;
  final bool isSpendingUp;

  const SpendingTrend({
    required this.currentPeriod,
    required this.previousPeriod,
    required this.expenseChangePercent,
    required this.isSpendingUp,
  });

  String get changeDescription {
    final absChange = expenseChangePercent.abs();
    if (absChange < 5) return 'Spending is stable';
    if (isSpendingUp) return 'Spending up $absChange%';
    return 'Spending down $absChange%';
  }

  @override
  List<Object?> get props => [expenseChangePercent, isSpendingUp];
}

