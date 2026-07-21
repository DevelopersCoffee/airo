import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import '../../application/clipboard_service.dart';
import '../../application/vault_record_reader.dart';
import '../../application/vault_record_ref.dart';
import 'masked_vault_field.dart';

class RecordDetailSheet extends ConsumerWidget {
  const RecordDetailSheet({
    super.key,
    required this.summary,
    required this.recordRef,
  });

  final VaultEntrySummary summary;
  final VaultRecordRef recordRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              ..._summaryRows(),
              ..._sensitiveRows(ref),
            ],
          ),
        ),
      ),
    );
  }

  String get _title {
    return switch (summary) {
      BankAccountSummary(:final nickname) => nickname,
      PanCardSummary(:final nameOnCard) => nameOnCard,
      CreditCardSummary(:final nickname) => nickname,
      SecureDocumentSummary(:final nickname) => nickname,
    };
  }

  List<Widget> _summaryRows() {
    return switch (summary) {
      BankAccountSummary(
        :final bankName,
        :final accountHolderName,
        :final ifscCode,
        :final accountType,
      ) =>
        [
          _PlainRow(label: 'Bank', value: bankName),
          _PlainRow(label: 'Holder', value: accountHolderName),
          _PlainRow(label: 'IFSC', value: ifscCode),
          _PlainRow(label: 'Type', value: accountType),
        ],
      PanCardSummary(:final id, :final fathersName) => [
        _PlainRow(label: 'Record id', value: '$id'),
        if (fathersName != null)
          _PlainRow(label: 'Father name', value: fathersName),
      ],
      CreditCardSummary(
        :final cardNetwork,
        :final last4,
        :final expiryMonth,
        :final expiryYear,
        :final issuingBank,
      ) =>
        [
          _PlainRow(label: 'Issuer', value: issuingBank),
          _PlainRow(label: 'Network', value: cardNetwork.name.toUpperCase()),
          _PlainRow(label: 'Card', value: '•••• $last4'),
          _PlainRow(
            label: 'Expiry',
            value: '${expiryMonth.toString().padLeft(2, '0')}/$expiryYear',
          ),
        ],
      SecureDocumentSummary(
        :final category,
        :final linkedAccountNickname,
        :final hasAttachment,
      ) =>
        [
          _PlainRow(label: 'Category', value: category.name),
          if (linkedAccountNickname != null)
            _PlainRow(label: 'Linked account', value: linkedAccountNickname),
          _PlainRow(
            label: 'Attachment',
            value: hasAttachment ? 'Stored' : 'None',
          ),
        ],
    };
  }

  List<Widget> _sensitiveRows(WidgetRef ref) {
    final clipboard = ref.read(clipboardServiceProvider);
    final reader = ref.read(vaultRecordReaderProvider);
    Future<void> copy(String value) => clipboard.copyWithAutoClear(value);
    return switch (summary) {
      BankAccountSummary() => [
        MaskedVaultField(
          key: const ValueKey('vault_bank_account_number_field'),
          label: 'Account number',
          maskedValue: '••••••••',
          revealValue: () =>
              reader.revealBankAccountNumber(recordRef.nickname ?? ''),
          onCopy: copy,
        ),
        MaskedVaultField(
          label: 'Notes',
          maskedValue: '••••',
          revealValue: () => reader.revealBankNotes(recordRef.nickname ?? ''),
          onCopy: copy,
        ),
      ],
      PanCardSummary() => [
        MaskedVaultField(
          key: const ValueKey('vault_pan_number_field'),
          label: 'PAN number',
          maskedValue: '••••••••••',
          revealValue: () => reader.revealPanNumber(recordRef.id ?? -1),
          onCopy: copy,
        ),
      ],
      CreditCardSummary() => const [],
      SecureDocumentSummary() => [
        MaskedVaultField(
          label: 'Notes',
          maskedValue: '••••',
          revealValue: () =>
              reader.revealDocumentNotes(recordRef.nickname ?? ''),
          onCopy: copy,
        ),
      ],
    };
  }
}

class _PlainRow extends StatelessWidget {
  const _PlainRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value),
    );
  }
}
