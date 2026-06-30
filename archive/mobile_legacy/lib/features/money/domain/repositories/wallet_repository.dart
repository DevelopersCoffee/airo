import '../../../../core/domain/repository.dart';
import '../../../../core/utils/result.dart';

/// Wallet type enum matching airomoney package
enum WalletType { cash, bank, credit, investment, crypto }

/// Wallet model for the money feature
/// Uses cents to avoid floating point precision issues with real money
class Wallet {
  final String id;
  final String name;
  final String? description;
  final int balanceCents; // Store in cents for precision
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
    required this.balanceCents,
    required this.type,
    this.currency = 'INR',
    this.bankName,
    this.accountNumber,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  /// Get balance as double (for display only, not calculations)
  double get balanceAsDouble => balanceCents / 100.0;

  /// Get masked account number for security
  String get maskedAccountNumber {
    if (accountNumber == null || accountNumber!.length < 4) {
      return accountNumber ?? '';
    }
    final lastFour = accountNumber!.substring(accountNumber!.length - 4);
    return '****$lastFour';
  }

  Wallet copyWith({
    String? id,
    String? name,
    String? description,
    int? balanceCents,
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
      balanceCents: balanceCents ?? this.balanceCents,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'balanceCents': balanceCents,
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
      balanceCents: json['balanceCents'] as int,
      type: WalletType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => WalletType.cash,
      ),
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
}

/// Wallet repository interface for managing user wallets
abstract interface class WalletRepository
    implements CacheRepository<String, Wallet> {
  /// Fetch all wallets for the current user
  Future<Result<List<Wallet>>> fetchAll();

  /// Fetch wallet by ID
  Future<Result<Wallet>> fetchById(String id);

  /// Create new wallet
  Future<Result<Wallet>> create({
    required String name,
    String? description,
    required int balanceCents,
    required WalletType type,
    required String currency,
    String? bankName,
    String? accountNumber,
  });

  /// Update wallet
  Future<Result<Wallet>> update(Wallet wallet);

  /// Delete wallet
  @override
  Future<Result<void>> delete(String id);

  /// Update wallet balance (atomic operation)
  Future<Result<Wallet>> updateBalance(String id, int newBalanceCents);

  /// Get total balance across all wallets in cents
  Future<Result<int>> getTotalBalanceCents();
}
