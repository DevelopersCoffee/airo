import 'package:equatable/equatable.dart';

/// Common currencies supported
enum CurrencyCode {
  inr('INR', '₹', 'Indian Rupee', 2),
  usd('USD', '\$', 'US Dollar', 2),
  eur('EUR', '€', 'Euro', 2),
  gbp('GBP', '£', 'British Pound', 2),
  jpy('JPY', '¥', 'Japanese Yen', 0),
  cad('CAD', '\$', 'Canadian Dollar', 2),
  aud('AUD', '\$', 'Australian Dollar', 2),
  sgd('SGD', '\$', 'Singapore Dollar', 2),
  aed('AED', 'د.إ', 'UAE Dirham', 2);

  final String code;
  final String symbol;
  final String name;
  final int decimalPlaces;

  const CurrencyCode(this.code, this.symbol, this.name, this.decimalPlaces);

  /// Get divisor for converting cents to major unit
  int get divisor => decimalPlaces > 0 ? (10 * decimalPlaces) : 1;
}

/// Currency model with exchange rate support
///
/// Used for multi-currency group expense handling.
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_2.md
class Currency extends Equatable {
  final String code;
  final String symbol;
  final String name;
  final int decimalPlaces;
  final double? exchangeRateToBase; // Rate to INR (base currency)
  final DateTime? rateUpdatedAt;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
    this.decimalPlaces = 2,
    this.exchangeRateToBase,
    this.rateUpdatedAt,
  });

  /// Create from enum
  factory Currency.fromCode(CurrencyCode code) {
    return Currency(
      code: code.code,
      symbol: code.symbol,
      name: code.name,
      decimalPlaces: code.decimalPlaces,
    );
  }

  /// Format amount in this currency
  String format(int amountCents) {
    final amount = amountCents / (decimalPlaces > 0 ? 100 : 1);
    return '$symbol${amount.toStringAsFixed(decimalPlaces)}';
  }

  /// Convert to base currency (INR)
  int? convertToBase(int amountCents) {
    if (exchangeRateToBase == null) return null;
    return (amountCents * exchangeRateToBase!).round();
  }

  /// Convert from base currency (INR)
  int? convertFromBase(int baseCents) {
    if (exchangeRateToBase == null || exchangeRateToBase == 0) return null;
    return (baseCents / exchangeRateToBase!).round();
  }

  /// Create a copy with updated fields
  Currency copyWith({
    String? code,
    String? symbol,
    String? name,
    int? decimalPlaces,
    double? exchangeRateToBase,
    DateTime? rateUpdatedAt,
  }) {
    return Currency(
      code: code ?? this.code,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      decimalPlaces: decimalPlaces ?? this.decimalPlaces,
      exchangeRateToBase: exchangeRateToBase ?? this.exchangeRateToBase,
      rateUpdatedAt: rateUpdatedAt ?? this.rateUpdatedAt,
    );
  }

  @override
  List<Object?> get props => [
        code,
        symbol,
        name,
        decimalPlaces,
        exchangeRateToBase,
        rateUpdatedAt,
      ];
}

