import 'package:equatable/equatable.dart';

/// Account types supported
enum AccountType {
  cash('Cash'),
  bank('Bank Account'),
  creditCard('Credit Card'),
  wallet('Digital Wallet'),
  investment('Investment');

  final String displayName;
  const AccountType(this.displayName);
}

/// Account entity representing a financial account
///
/// Tracks balance and serves as source/destination for transactions.
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/DOMAIN_API_CONTRACTS.md
class Account extends Equatable {
  final String id;
  final String name;
  final AccountType type;
  final int balanceCents; // Current balance in smallest currency unit
  final String currencyCode; // ISO 4217 code (e.g., 'INR', 'USD')
  final String? iconName;
  final String? color; // Hex color code
  final bool isDefault;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balanceCents,
    this.currencyCode = 'INR',
    this.iconName,
    this.color,
    this.isDefault = false,
    this.isArchived = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// Get balance in major currency unit
  double get balance => balanceCents / 100;

  /// Create a copy with updated fields
  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    int? balanceCents,
    String? currencyCode,
    String? iconName,
    String? color,
    bool? isDefault,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balanceCents: balanceCents ?? this.balanceCents,
      currencyCode: currencyCode ?? this.currencyCode,
      iconName: iconName ?? this.iconName,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        balanceCents,
        currencyCode,
        iconName,
        color,
        isDefault,
        isArchived,
        createdAt,
        updatedAt,
      ];
}

