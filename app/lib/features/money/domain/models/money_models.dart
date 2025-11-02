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

  /// Get balance as formatted string
  String get balanceFormatted {
    final dollars = balanceCents ~/ 100;
    final cents = (balanceCents % 100).abs();
    return '\$$dollars.${cents.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [id, name, type, currency, balanceCents, createdAt, updatedAt];
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

  /// Get amount as formatted string
  String get amountFormatted {
    final dollars = amountCents.abs() ~/ 100;
    final cents = (amountCents.abs() % 100);
    final sign = isExpense ? '-' : '+';
    return '$sign\$$dollars.${cents.toString().padLeft(2, '0')}';
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

/// Budget model
class Budget extends Equatable {
  final String id;
  final String tag; // Budget is per tag/category
  final int limitCents; // Monthly limit in cents
  final int usedCents; // Amount used in current month
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Budget({
    required this.id,
    required this.tag,
    required this.limitCents,
    required this.usedCents,
    required this.createdAt,
    this.updatedAt,
  });

  /// Get percentage of budget used (0.0 to 1.0)
  double get percentageUsed {
    if (limitCents == 0) return 0.0;
    return (usedCents / limitCents).clamp(0.0, 1.0);
  }

  /// Check if budget is exceeded
  bool get isExceeded => usedCents > limitCents;

  /// Get remaining budget in cents
  int get remainingCents => (limitCents - usedCents).clamp(0, limitCents);

  /// Get limit as formatted string
  String get limitFormatted {
    final dollars = limitCents ~/ 100;
    final cents = (limitCents % 100);
    return '\$$dollars.${cents.toString().padLeft(2, '0')}';
  }

  /// Get used as formatted string
  String get usedFormatted {
    final dollars = usedCents ~/ 100;
    final cents = (usedCents % 100);
    return '\$$dollars.${cents.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [id, tag, limitCents, usedCents, createdAt, updatedAt];
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
  List<Object?> get props => [id, title, description, amountCents, type, createdAt];
}

