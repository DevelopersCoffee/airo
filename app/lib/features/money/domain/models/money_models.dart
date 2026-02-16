import 'package:equatable/equatable.dart';

import '../../../../core/utils/currency_formatter.dart';

/// Money account model
class MoneyAccount extends Equatable {
  final String id;
  final String name;
  final String type; // 'checking', 'savings', 'credit_card', etc.
  final String currency; // 'USD', 'EUR', etc.
  final int balanceCents; // Amount in cents to avoid floating point issues
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MoneyAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.balanceCents,
    required this.createdAt,
    this.updatedAt,
  });

  /// Get currency symbol based on currency code
  String get currencySymbol {
    return SupportedCurrency.fromCode(currency).symbol;
  }

  /// Get balance formatted using locale-aware CurrencyFormatter
  ///
  /// This is the preferred method for formatting currency.
  /// Pass the formatter from the user's locale settings.
  String formatBalance(CurrencyFormatter formatter) {
    return formatter.formatCents(balanceCents);
  }

  /// Get balance as formatted string with proper currency
  ///
  /// @Deprecated: Use [formatBalance] with a CurrencyFormatter for global locale support.
  /// This method uses the account's currency but may not respect user's locale preferences.
  @Deprecated('Use formatBalance(CurrencyFormatter) for global locale support')
  String get balanceFormatted {
    final formatter = CurrencyFormatter.fromCode(currency);
    return formatter.formatCents(balanceCents);
  }

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    currency,
    balanceCents,
    createdAt,
    updatedAt,
  ];
}

/// Transaction model
class Transaction extends Equatable {
  final String id;
  final String accountId;
  final DateTime timestamp;
  final int amountCents; // Negative for expenses, positive for income
  final String description;
  final String category;
  final List<String> tags;
  final String? receiptUrl;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.accountId,
    required this.timestamp,
    required this.amountCents,
    required this.description,
    required this.category,
    this.tags = const [],
    this.receiptUrl,
    required this.createdAt,
  });

  /// Check if transaction is expense (negative amount)
  bool get isExpense => amountCents < 0;

  /// Check if transaction is income (positive amount)
  bool get isIncome => amountCents > 0;

  /// Format amount using locale-aware CurrencyFormatter
  ///
  /// This is the preferred method for formatting currency.
  /// Pass the formatter from the user's locale settings.
  String formatAmount(CurrencyFormatter formatter) {
    return formatter.formatCentsWithSign(amountCents);
  }

  /// Get amount as formatted string
  ///
  /// @Deprecated: Use [formatAmount] with a CurrencyFormatter for global locale support.
  /// This method defaults to INR formatting.
  @Deprecated('Use formatAmount(CurrencyFormatter) for global locale support')
  String get amountFormatted {
    return CurrencyFormatter.inr.formatCentsWithSign(amountCents);
  }

  @override
  List<Object?> get props => [
    id,
    accountId,
    timestamp,
    amountCents,
    description,
    category,
    tags,
    receiptUrl,
    createdAt,
  ];
}

/// Budget recurrence type
enum BudgetRecurrence { monthly, weekly, yearly }

/// Budget carryover behavior
enum CarryoverBehavior {
  /// No carryover - unused budget is lost
  none,

  /// Unused budget carries over to next period
  carryUnused,

  /// Overspent amount is added to next period's used
  carryDeficit,

  /// Both unused and deficit carry over
  carryBoth,
}

/// Budget warning level
enum BudgetWarningLevel {
  /// Under 80% - safe
  normal,

  /// 80-100% - approaching limit
  warning,

  /// Over 100% - exceeded
  exceeded,
}

/// Budget model
class Budget extends Equatable {
  final String id;
  final String tag; // Budget is per tag/category
  final int limitCents; // Budget limit in cents
  final int usedCents; // Amount used in current period
  final int carryoverCents; // Amount carried over from previous period
  final BudgetRecurrence recurrence;
  final CarryoverBehavior carryoverBehavior;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Budget({
    required this.id,
    required this.tag,
    required this.limitCents,
    required this.usedCents,
    this.carryoverCents = 0,
    this.recurrence = BudgetRecurrence.monthly,
    this.carryoverBehavior = CarryoverBehavior.none,
    required this.createdAt,
    this.updatedAt,
  });

  /// Effective limit after carryover adjustments
  int get effectiveLimitCents {
    switch (carryoverBehavior) {
      case CarryoverBehavior.none:
        return limitCents;
      case CarryoverBehavior.carryUnused:
        return limitCents + (carryoverCents > 0 ? carryoverCents : 0);
      case CarryoverBehavior.carryDeficit:
        return limitCents - (carryoverCents < 0 ? carryoverCents.abs() : 0);
      case CarryoverBehavior.carryBoth:
        return limitCents + carryoverCents;
    }
  }

  /// Get percentage of budget used (0.0 to 1.0+)
  double get percentageUsed {
    final effective = effectiveLimitCents;
    if (effective == 0) return 0.0;
    return usedCents / effective;
  }

  /// Get percentage clamped to 0.0-1.0 for progress bars
  double get percentageUsedClamped => percentageUsed.clamp(0.0, 1.0);

  /// Check if budget is exceeded
  bool get isExceeded => usedCents > effectiveLimitCents;

  /// Check if budget is approaching limit (80% or more)
  bool get isApproachingLimit => percentageUsed >= 0.8 && !isExceeded;

  /// Check if budget is at warning level (80%) or exceeded (100%)
  BudgetWarningLevel get warningLevel {
    if (isExceeded) return BudgetWarningLevel.exceeded;
    if (percentageUsed >= 0.8) return BudgetWarningLevel.warning;
    return BudgetWarningLevel.normal;
  }

  /// Get remaining budget in cents
  int get remainingCents =>
      (effectiveLimitCents - usedCents).clamp(0, effectiveLimitCents);

  // ---- Locale-aware formatting methods (preferred) ----

  /// Format limit using locale-aware CurrencyFormatter
  String formatLimit(CurrencyFormatter formatter) =>
      formatter.formatCents(limitCents);

  /// Format effective limit using locale-aware CurrencyFormatter
  String formatEffectiveLimit(CurrencyFormatter formatter) =>
      formatter.formatCents(effectiveLimitCents);

  /// Format used amount using locale-aware CurrencyFormatter
  String formatUsed(CurrencyFormatter formatter) =>
      formatter.formatCents(usedCents);

  /// Format remaining amount using locale-aware CurrencyFormatter
  String formatRemaining(CurrencyFormatter formatter) =>
      formatter.formatCents(remainingCents);

  // ---- Deprecated getters for backward compatibility ----

  /// Get limit as formatted string
  ///
  /// @Deprecated: Use [formatLimit] with a CurrencyFormatter for global locale support.
  @Deprecated('Use formatLimit(CurrencyFormatter) for global locale support')
  String get limitFormatted => CurrencyFormatter.inr.formatCents(limitCents);

  /// Get effective limit as formatted string
  ///
  /// @Deprecated: Use [formatEffectiveLimit] with a CurrencyFormatter for global locale support.
  @Deprecated(
    'Use formatEffectiveLimit(CurrencyFormatter) for global locale support',
  )
  String get effectiveLimitFormatted =>
      CurrencyFormatter.inr.formatCents(effectiveLimitCents);

  /// Get used as formatted string
  ///
  /// @Deprecated: Use [formatUsed] with a CurrencyFormatter for global locale support.
  @Deprecated('Use formatUsed(CurrencyFormatter) for global locale support')
  String get usedFormatted => CurrencyFormatter.inr.formatCents(usedCents);

  /// Get remaining as formatted string
  ///
  /// @Deprecated: Use [formatRemaining] with a CurrencyFormatter for global locale support.
  @Deprecated(
    'Use formatRemaining(CurrencyFormatter) for global locale support',
  )
  String get remainingFormatted =>
      CurrencyFormatter.inr.formatCents(remainingCents);

  /// Create a copy with updated fields
  Budget copyWith({
    String? id,
    String? tag,
    int? limitCents,
    int? usedCents,
    int? carryoverCents,
    BudgetRecurrence? recurrence,
    CarryoverBehavior? carryoverBehavior,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      tag: tag ?? this.tag,
      limitCents: limitCents ?? this.limitCents,
      usedCents: usedCents ?? this.usedCents,
      carryoverCents: carryoverCents ?? this.carryoverCents,
      recurrence: recurrence ?? this.recurrence,
      carryoverBehavior: carryoverBehavior ?? this.carryoverBehavior,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tag,
    limitCents,
    usedCents,
    carryoverCents,
    recurrence,
    carryoverBehavior,
    createdAt,
    updatedAt,
  ];
}

/// Insight model for analytics
class MoneyInsight extends Equatable {
  final String id;
  final String title;
  final String description;
  final int amountCents;
  final String type; // 'spending_trend', 'budget_alert', 'savings_goal', etc.
  final DateTime createdAt;

  const MoneyInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.amountCents,
    required this.type,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    amountCents,
    type,
    createdAt,
  ];
}

/// Result of saving an expense
class SaveExpenseResult {
  final Transaction transaction;
  final BudgetDeductionStatus budgetStatus;
  final Budget? budget;

  const SaveExpenseResult({
    required this.transaction,
    required this.budgetStatus,
    this.budget,
  });

  /// Check if budget limit was exceeded
  bool get isBudgetExceeded =>
      budgetStatus == BudgetDeductionStatus.exceededLimit;

  /// Check if there was a matching budget
  bool get hasBudget => budgetStatus != BudgetDeductionStatus.noBudget;
}

/// Status of budget deduction after saving expense
enum BudgetDeductionStatus {
  /// Successfully deducted from budget, within limit
  success,

  /// Successfully deducted, but budget limit exceeded
  exceededLimit,

  /// No budget exists for this category
  noBudget,

  /// Error occurred during deduction
  error,
}
