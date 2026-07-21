import 'package:equatable/equatable.dart';

import 'credit_card_record.dart';
import 'secure_document_record.dart';

/// List-screen projection of a vault record, built only from columns stored
/// unencrypted. Rendering a summary never requires the vault DEK, so list
/// screens perform no decryption at all.
sealed class VaultEntrySummary extends Equatable {
  const VaultEntrySummary();
}

final class BankAccountSummary extends VaultEntrySummary {
  const BankAccountSummary({
    required this.nickname,
    required this.bankName,
    required this.accountHolderName,
    required this.ifscCode,
    required this.accountType,
  });

  final String nickname;
  final String bankName;
  final String accountHolderName;
  final String ifscCode;
  final String accountType;

  @override
  List<Object?> get props => [
    nickname,
    bankName,
    accountHolderName,
    ifscCode,
    accountType,
  ];
}

final class PanCardSummary extends VaultEntrySummary {
  const PanCardSummary({
    required this.id,
    required this.nameOnCard,
    this.fathersName,
  });

  /// PAN cards have no nickname column — the row id is the canonical handle.
  final int id;
  final String nameOnCard;
  final String? fathersName;

  @override
  List<Object?> get props => [id, nameOnCard, fathersName];
}

final class CreditCardSummary extends VaultEntrySummary {
  const CreditCardSummary({
    required this.nickname,
    required this.cardNetwork,
    required this.last4,
    required this.expiryMonth,
    required this.expiryYear,
    required this.issuingBank,
  });

  final String nickname;
  final CardNetwork cardNetwork;
  final String last4;
  final int expiryMonth;
  final int expiryYear;
  final String issuingBank;

  @override
  List<Object?> get props => [
    nickname,
    cardNetwork,
    last4,
    expiryMonth,
    expiryYear,
    issuingBank,
  ];
}

final class SecureDocumentSummary extends VaultEntrySummary {
  const SecureDocumentSummary({
    required this.nickname,
    required this.category,
    this.linkedAccountNickname,
    required this.hasAttachment,
  });

  final String nickname;
  final DocumentCategory category;
  final String? linkedAccountNickname;
  final bool hasAttachment;

  @override
  List<Object?> get props => [
    nickname,
    category,
    linkedAccountNickname,
    hasAttachment,
  ];
}
