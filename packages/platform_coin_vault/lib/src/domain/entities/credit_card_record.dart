import 'package:equatable/equatable.dart';

enum CardNetwork { visa, mastercard, rupay, amex }

/// A masked credit card reference stored in the Airo Coin vault.
///
/// Deliberately excludes the full card number, CVV, and PIN — only enough
/// to identify the card is stored, matching the debit-card rule on
/// [BankAccountRecord].
class CreditCardRecord extends Equatable {
  const CreditCardRecord({
    required this.id,
    required this.nickname,
    required this.cardNetwork,
    required this.last4,
    required this.expiryMonth,
    required this.expiryYear,
    required this.issuingBank,
    required this.createdAt,
  });

  final int? id;
  final String nickname;
  final CardNetwork cardNetwork;
  final String last4;
  final int expiryMonth;
  final int expiryYear;
  final String issuingBank;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    nickname,
    cardNetwork,
    last4,
    expiryMonth,
    expiryYear,
    issuingBank,
    createdAt,
  ];
}
