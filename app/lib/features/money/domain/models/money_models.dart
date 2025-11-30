import 'package:equatable/equatable.dart';

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
    switch (currency.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return currency;
    }
  }

  /// Get balance as formatted string with proper currency
  String get balanceFormatted {
    final wholePart = balanceCents ~/ 100;
    final decimalPart = (balanceCents % 100).abs();

    if (currency.toUpperCase() == 'INR') {
      return _formatIndianCurrency(wholePart, decimalPart);
    }
    return '$currencySymbol$wholePart.${decimalPart.toString().padLeft(2, '0')}';
  }

  /// Format amount using Indian numbering system (lakhs, crores)
  String _formatIndianCurrency(int wholePart, int decimalPart) {
    final isNegative = wholePart < 0;
    final absWhole = wholePart.abs();

    String formatted;
    if (absWhole < 1000) {
      formatted = absWhole.toString();
    } else if (absWhole < 100000) {
      final thousands = absWhole ~/ 1000;
      final remainder = absWhole % 1000;
      formatted = '$thousands,${remainder.toString().padLeft(3, '0')}';
    } else if (absWhole < 10000000) {
      final lakhs = absWhole ~/ 100000;
      final thousands = (absWhole % 100000) ~/ 1000;
      final remainder = absWhole % 1000;
      formatted =
          '$lakhs,${thousands.toString().padLeft(2, '0')},${remainder.toString().padLeft(3, '0')}';
    } else {
      final crores = absWhole ~/ 10000000;
      final lakhs = (absWhole % 10000000) ~/ 100000;
      final thousands = (absWhole % 100000) ~/ 1000;
      final remainder = absWhole % 1000;
      formatted =
          '$crores,${lakhs.toString().padLeft(2, '0')},${thousands.toString().padLeft(2, '0')},${remainder.toString().padLeft(3, '0')}';
    }

    final sign = isNegative ? '-' : '';
    return '$sign₹$formatted.${decimalPart.toString().padLeft(2, '0')}';
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

  /// Get amount as formatted string (uses INR by default)
  String get amountFormatted {
    final wholePart = amountCents.abs() ~/ 100;
    final decimalPart = (amountCents.abs() % 100);
    final sign = isExpense ? '-' : '+';
    return '$sign₹$wholePart.${decimalPart.toString().padLeft(2, '0')}';
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
enum BudgetRecurrence {
  monthly,
  weekly,
  yearly,
}

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

  /// Get remaining budget in cents
  int get remainingCents => (effectiveLimitCents - usedCents).clamp(0, effectiveLimitCents);

  /// Get limit as formatted string
  String get limitFormatted => _formatCurrency(limitCents);

  /// Get effective limit as formatted string
  String get effectiveLimitFormatted => _formatCurrency(effectiveLimitCents);

  /// Get used as formatted string
  String get usedFormatted => _formatCurrency(usedCents);

  /// Get remaining as formatted string
  String get remainingFormatted => _formatCurrency(remainingCents);

  /// Format currency using INR by default
  static String _formatCurrency(int cents) {
    final wholePart = cents.abs() ~/ 100;
    final decimalPart = cents.abs() % 100;
    final formatted = '₹$wholePart.${decimalPart.toString().padLeft(2, '0')}';
    return cents < 0 ? '-$formatted' : formatted;
  }

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
