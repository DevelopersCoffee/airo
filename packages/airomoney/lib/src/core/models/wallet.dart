enum WalletType { cash, bank, credit, investment, crypto }

class Wallet {
  final String id;
  final String name;
  final String? description;
  final double balance;
  final WalletType type;
  final String currency;
  final String? bankName;
  final String? accountNumber;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  const Wallet({
    required this.id,
    required this.name,
    this.description,
    required this.balance,
    required this.type,
    this.currency = 'INR', // Default to INR for India
    this.bankName,
    this.accountNumber,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  Wallet copyWith({
    String? id,
    String? name,
    String? description,
    double? balance,
    WalletType? type,
    String? currency,
    String? bankName,
    String? accountNumber,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Wallet(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      balance: balance ?? this.balance,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

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

  /// Format balance with proper currency symbol
  /// Uses Indian numbering system for INR (lakhs, crores)
  String get formattedBalance {
    if (currency.toUpperCase() == 'INR') {
      return _formatIndianCurrency(balance);
    }
    return '$currencySymbol${balance.toStringAsFixed(2)}';
  }

  /// Format amount using Indian numbering system
  String _formatIndianCurrency(double amount) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final wholePart = absAmount.truncate();
    final decimalPart = ((absAmount - wholePart) * 100).round();

    String formatted;
    if (wholePart < 1000) {
      formatted = wholePart.toString();
    } else if (wholePart < 100000) {
      final thousands = wholePart ~/ 1000;
      final remainder = wholePart % 1000;
      formatted = '$thousands,${remainder.toString().padLeft(3, '0')}';
    } else if (wholePart < 10000000) {
      final lakhs = wholePart ~/ 100000;
      final thousands = (wholePart % 100000) ~/ 1000;
      final remainder = wholePart % 1000;
      formatted =
          '$lakhs,${thousands.toString().padLeft(2, '0')},${remainder.toString().padLeft(3, '0')}';
    } else {
      final crores = wholePart ~/ 10000000;
      final lakhs = (wholePart % 10000000) ~/ 100000;
      final thousands = (wholePart % 100000) ~/ 1000;
      final remainder = wholePart % 1000;
      formatted =
          '$crores,${lakhs.toString().padLeft(2, '0')},${thousands.toString().padLeft(2, '0')},${remainder.toString().padLeft(3, '0')}';
    }

    final sign = isNegative ? '-' : '';
    return '$sign₹$formatted.${decimalPart.toString().padLeft(2, '0')}';
  }

  String get maskedAccountNumber {
    if (accountNumber == null || accountNumber!.length < 4) {
      return accountNumber ?? '';
    }
    final lastFour = accountNumber!.substring(accountNumber!.length - 4);
    return '****$lastFour';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'balance': balance,
      'type': type.name,
      'currency': currency,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      balance: (json['balance'] as num).toDouble(),
      type: WalletType.values.firstWhere((e) => e.name == json['type']),
      currency: json['currency'] as String? ?? 'INR',
      bankName: json['bankName'] as String?,
      accountNumber: json['accountNumber'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Wallet && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Wallet(id: $id, name: $name, balance: $balance, type: $type, currency: $currency)';
  }
}
