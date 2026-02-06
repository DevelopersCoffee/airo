import 'package:equatable/equatable.dart';

/// Currency enum for future multi-currency support
enum Currency {
  inr('INR', '₹', 'Indian Rupee'),
  usd('USD', '\$', 'US Dollar'),
  eur('EUR', '€', 'Euro'),
  gbp('GBP', '£', 'British Pound');

  final String code;
  final String symbol;
  final String name;

  const Currency(this.code, this.symbol, this.name);
}

/// Participant in a bill split (from contacts)
class Participant extends Equatable {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? avatarUrl;

  const Participant({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.avatarUrl,
  });

  /// Create from contact
  factory Participant.fromContact({
    required String id,
    required String name,
    String? phone,
    String? email,
  }) {
    return Participant(id: id, name: name, phone: phone, email: email);
  }

  /// Get initials for avatar
  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  List<Object?> get props => [id, name, phone, email, avatarUrl];
}

/// Line item from a bill
class BillItem extends Equatable {
  final String id;
  final String name;
  final int amountPaise; // Amount in smallest unit (paise for INR)
  final int quantity;

  const BillItem({
    required this.id,
    required this.name,
    required this.amountPaise,
    this.quantity = 1,
  });

  /// Get total amount for this item
  int get totalPaise => amountPaise * quantity;

  /// Format amount with currency
  String formatAmount(Currency currency) {
    final amount = amountPaise / 100;
    return '${currency.symbol}${amount.toStringAsFixed(2)}';
  }

  @override
  List<Object?> get props => [id, name, amountPaise, quantity];
}

/// A bill to be split
class Bill extends Equatable {
  final String id;
  final String? vendor;
  final DateTime date;
  final List<BillItem> items;
  final int subtotalPaise;
  final int taxPaise;
  final int tipPaise;
  final int totalPaise;
  final Currency currency;
  final String? rawText; // Original extracted text
  final DateTime createdAt;

  const Bill({
    required this.id,
    this.vendor,
    required this.date,
    required this.items,
    required this.subtotalPaise,
    this.taxPaise = 0,
    this.tipPaise = 0,
    required this.totalPaise,
    this.currency = Currency.inr,
    this.rawText,
    required this.createdAt,
  });

  /// Format total with currency
  String get formattedTotal {
    final amount = totalPaise / 100;
    return '${currency.symbol}${amount.toStringAsFixed(2)}';
  }

  /// Format subtotal with currency
  String get formattedSubtotal {
    final amount = subtotalPaise / 100;
    return '${currency.symbol}${amount.toStringAsFixed(2)}';
  }

  @override
  List<Object?> get props => [
    id,
    vendor,
    date,
    items,
    subtotalPaise,
    taxPaise,
    tipPaise,
    totalPaise,
    currency,
    createdAt,
  ];
}

/// Individual split result for a participant
class ParticipantSplit extends Equatable {
  final Participant participant;
  final int amountPaise;
  final Currency currency;

  const ParticipantSplit({
    required this.participant,
    required this.amountPaise,
    this.currency = Currency.inr,
  });

  /// Format amount with currency
  String get formattedAmount {
    final amount = amountPaise / 100;
    return '${currency.symbol}${amount.toStringAsFixed(2)}';
  }

  @override
  List<Object?> get props => [participant, amountPaise, currency];
}
