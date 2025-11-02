enum TransactionType {
  income,
  expense,
  transfer,
}

enum TransactionCategory {
  // Income categories
  salary,
  freelance,
  investment,
  gift,
  other_income,
  
  // Expense categories
  food,
  transport,
  entertainment,
  shopping,
  bills,
  healthcare,
  education,
  other_expense,
}

class Transaction {
  final String id;
  final String title;
  final String? description;
  final double amount;
  final TransactionType type;
  final TransactionCategory category;
  final DateTime date;
  final String? walletId;
  final String? toWalletId; // For transfers
  final Map<String, dynamic>? metadata;

  const Transaction({
    required this.id,
    required this.title,
    this.description,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.walletId,
    this.toWalletId,
    this.metadata,
  });

  Transaction copyWith({
    String? id,
    String? title,
    String? description,
    double? amount,
    TransactionType? type,
    TransactionCategory? category,
    DateTime? date,
    String? walletId,
    String? toWalletId,
    Map<String, dynamic>? metadata,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      walletId: walletId ?? this.walletId,
      toWalletId: toWalletId ?? this.toWalletId,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'amount': amount,
      'type': type.name,
      'category': category.name,
      'date': date.toIso8601String(),
      'walletId': walletId,
      'toWalletId': toWalletId,
      'metadata': metadata,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      amount: (json['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      category: TransactionCategory.values.firstWhere(
        (e) => e.name == json['category'],
      ),
      date: DateTime.parse(json['date'] as String),
      walletId: json['walletId'] as String?,
      toWalletId: json['toWalletId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Transaction(id: $id, title: $title, amount: $amount, type: $type, category: $category, date: $date)';
  }
}
