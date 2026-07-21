import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/vault_record_type.dart';
import '../widgets/forms/bank_account_form.dart';
import '../widgets/forms/credit_card_form.dart';
import '../widgets/forms/pan_card_form.dart';
import '../widgets/forms/secure_document_form.dart';

/// Add/edit host routed at `/money/vault/add/:type` and
/// `/money/vault/edit/:type/:key`. Dispatches to the per-type form.
class VaultRecordFormScreen extends ConsumerWidget {
  const VaultRecordFormScreen({
    super.key,
    required this.recordType,
    this.recordKey,
  });

  final VaultRecordType recordType;

  /// Nickname, or PAN row id as a decimal string. Null means add mode.
  final String? recordKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panRecordId =
        recordType == VaultRecordType.panCard && recordKey != null
        ? int.tryParse(recordKey!)
        : null;
    final typeLabel = switch (recordType) {
      VaultRecordType.bankAccount => 'Bank account',
      VaultRecordType.panCard => 'PAN card',
      VaultRecordType.creditCard => 'Card (masked)',
      VaultRecordType.secureDocument => 'Secure document',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text('${recordKey == null ? 'Add' : 'Edit'} $typeLabel'),
      ),
      body: switch (recordType) {
        VaultRecordType.bankAccount => BankAccountForm(nickname: recordKey),
        VaultRecordType.panCard =>
          recordKey != null && panRecordId == null
              ? const Center(child: Text('Invalid PAN record key'))
              : PanCardForm(recordId: panRecordId),
        VaultRecordType.creditCard => CreditCardForm(nickname: recordKey),
        VaultRecordType.secureDocument => SecureDocumentForm(
          nickname: recordKey,
        ),
      },
    );
  }
}
