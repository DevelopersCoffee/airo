import 'package:equatable/equatable.dart';

/// ITR-filing-driven taxonomy for generic vault documents. New document
/// types are new values here (or [other] + custom fields) — no schema
/// migration required.
enum DocumentCategory {
  personalId,
  incomeProof,
  taxCredit,
  investmentProof,
  hra,
  capitalGains,
  homeLoan,
  other,
}

/// A generic, category-tagged secure document stored in the Airo Coin vault
/// (e.g. Form 16, Form 26AS, 80C investment proofs, rent receipts).
class SecureDocumentRecord extends Equatable {
  const SecureDocumentRecord({
    required this.id,
    required this.nickname,
    required this.category,
    required this.createdAt,
    this.linkedAccountNickname,
    this.customFields = const {},
    this.attachmentBlob,
    this.notes,
  });

  final int? id;
  final String nickname;
  final DocumentCategory category;

  /// Optional reference to [BankAccountRecord.nickname], e.g. an FD interest
  /// statement linked to the account it came from.
  final String? linkedAccountNickname;
  final Map<String, String> customFields;
  final List<int>? attachmentBlob;
  final String? notes;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    nickname,
    category,
    linkedAccountNickname,
    customFields,
    attachmentBlob,
    notes,
    createdAt,
  ];
}
