enum WalletType {
  cash,
  bank,
  credit,
  investment,
  crypto,
}

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
    this.currency = 'USD',
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

  String get formattedBalance {
    return '\$${balance.toStringAsFixed(2)}';
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
      type: WalletType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      currency: json['currency'] as String? ?? 'USD',
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
