import 'package:equatable/equatable.dart';

enum VaultRecordType { bankAccount, panCard, creditCard, secureDocument }

final class VaultRecordRef extends Equatable {
  const VaultRecordRef._({required this.type, this.nickname, this.id});

  const VaultRecordRef.bankAccount(String nickname)
    : this._(type: VaultRecordType.bankAccount, nickname: nickname);

  const VaultRecordRef.panCard(int id)
    : this._(type: VaultRecordType.panCard, id: id);

  const VaultRecordRef.creditCard(String nickname)
    : this._(type: VaultRecordType.creditCard, nickname: nickname);

  const VaultRecordRef.secureDocument(String nickname)
    : this._(type: VaultRecordType.secureDocument, nickname: nickname);

  final VaultRecordType type;
  final String? nickname;
  final int? id;

  String get displayHandle => nickname ?? '#$id';

  @override
  List<Object?> get props => [type, nickname, id];
}
