import 'package:equatable/equatable.dart';

import '../validators/ifsc_validator.dart';

/// A bank account reference stored in the Airo Coin vault.
///
/// [nickname] is the canonical, unique-within-vault handle for this account —
/// other records (e.g. [SecureDocumentRecord.linkedAccountNickname]) refer to
/// it by this value, not by [id].
class BankAccountRecord extends Equatable {
  BankAccountRecord({
    required this.id,
    required this.nickname,
    required this.bankName,
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifscCode,
    required this.accountType,
    this.branchName,
    this.micrCode,
    this.swiftIban,
    this.customerId,
    this.upiIds,
    this.linkedMobile,
    this.linkedEmail,
    this.nomineeName,
    this.debitCardLast4,
    this.debitCardExpiry,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now() {
    if (!isValidIfsc(ifscCode)) {
      throw ArgumentError.value(ifscCode, 'ifscCode', 'Not a valid IFSC code');
    }
  }

  final int? id;
  final String nickname;
  final String bankName;
  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String accountType;
  final String? branchName;
  final String? micrCode;
  final String? swiftIban;
  final String? customerId;
  final String? upiIds;
  final String? linkedMobile;
  final String? linkedEmail;
  final String? nomineeName;
  final String? debitCardLast4;
  final String? debitCardExpiry;
  final String? notes;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    nickname,
    bankName,
    accountHolderName,
    accountNumber,
    ifscCode,
    accountType,
    branchName,
    micrCode,
    swiftIban,
    customerId,
    upiIds,
    linkedMobile,
    linkedEmail,
    nomineeName,
    debitCardLast4,
    debitCardExpiry,
    notes,
    createdAt,
  ];
}
