import 'package:equatable/equatable.dart';

/// Investment types
enum InvestmentType {
  stock('Stocks'),
  mutualFund('Mutual Funds'),
  fixedDeposit('Fixed Deposit'),
  gold('Gold'),
  crypto('Cryptocurrency'),
  realEstate('Real Estate'),
  other('Other');

  final String displayName;
  const InvestmentType(this.displayName);
}

/// Investment entity for portfolio tracking
///
/// Tracks investments and their current values.
///
/// Phase: 4 (Investment Tracking)
/// See: docs/features/coins/DOMAIN_API_CONTRACTS.md
class Investment extends Equatable {
  final String id;
  final String name;
  final InvestmentType type;
  final int investedAmountCents;
  final int currentValueCents;
  final String currencyCode;
  final double? units; // Number of shares/units
  final double? currentPricePerUnit;
  final String? symbol; // Stock symbol, fund code
  final String? broker; // Platform/broker name
  final DateTime purchaseDate;
  final DateTime lastUpdated;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Investment({
    required this.id,
    required this.name,
    required this.type,
    required this.investedAmountCents,
    required this.currentValueCents,
    this.currencyCode = 'INR',
    this.units,
    this.currentPricePerUnit,
    this.symbol,
    this.broker,
    required this.purchaseDate,
    required this.lastUpdated,
    this.isActive = true,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  /// Get invested amount in major currency unit
  double get investedAmount => investedAmountCents / 100;

  /// Get current value in major currency unit
  double get currentValue => currentValueCents / 100;

  /// Calculate profit/loss in cents
  int get profitLossCents => currentValueCents - investedAmountCents;

  /// Get profit/loss in major currency unit
  double get profitLoss => profitLossCents / 100;

  /// Calculate return percentage
  double get returnPercentage {
    if (investedAmountCents == 0) return 0;
    return (profitLossCents / investedAmountCents) * 100;
  }

  /// Check if investment is profitable
  bool get isProfitable => currentValueCents >= investedAmountCents;

  /// Create a copy with updated fields
  Investment copyWith({
    String? id,
    String? name,
    InvestmentType? type,
    int? investedAmountCents,
    int? currentValueCents,
    String? currencyCode,
    double? units,
    double? currentPricePerUnit,
    String? symbol,
    String? broker,
    DateTime? purchaseDate,
    DateTime? lastUpdated,
    bool? isActive,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Investment(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      investedAmountCents: investedAmountCents ?? this.investedAmountCents,
      currentValueCents: currentValueCents ?? this.currentValueCents,
      currencyCode: currencyCode ?? this.currencyCode,
      units: units ?? this.units,
      currentPricePerUnit: currentPricePerUnit ?? this.currentPricePerUnit,
      symbol: symbol ?? this.symbol,
      broker: broker ?? this.broker,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        investedAmountCents,
        currentValueCents,
        currencyCode,
        units,
        currentPricePerUnit,
        symbol,
        broker,
        purchaseDate,
        lastUpdated,
        isActive,
        notes,
        createdAt,
        updatedAt,
      ];
}

