import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import '../../application/vault_record_ref.dart';
import '../../application/vault_session.dart';
import '../../application/vault_summaries_provider.dart';
import '../widgets/record_detail_sheet.dart';
import 'vault_record_form_screen.dart';

class VaultHomeScreen extends ConsumerWidget {
  const VaultHomeScreen({super.key, this.onAddRecord, this.onOpenRecord});

  final ValueChanged<VaultRecordType>? onAddRecord;
  final ValueChanged<VaultRecordRef>? onOpenRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(vaultSummariesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Vault'),
        actions: [
          IconButton(
            key: const ValueKey('vault_manual_lock_button'),
            tooltip: 'Lock vault',
            icon: const Icon(Icons.lock_outline),
            onPressed: () => ref.read(vaultSessionProvider.notifier).lock(),
          ),
        ],
      ),
      body: summaries.when(
        loading: () =>
            const Center(child: LoadingIndicator(message: 'Loading vault')),
        error: (error, stackTrace) => ErrorView(
          title: 'Could not load vault',
          message: error.toString(),
          onRetry: () => ref.invalidate(vaultSummariesProvider),
        ),
        data: (data) => data.isEmpty
            ? EmptyStateWidget(
                key: const ValueKey('vault_empty_state'),
                icon: Icons.account_balance_wallet_outlined,
                title: 'Your phone is the vault',
                message:
                    'Add bank accounts, PAN cards, masked cards, and secure documents stored locally with biometric protection.',
                action: FilledButton.icon(
                  onPressed: () =>
                      _openAddTypePicker(context, ref, onAddRecord),
                  icon: const Icon(Icons.add),
                  label: const Text('Add record'),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.refresh(vaultSummariesProvider.future),
                child: ListView(
                  padding: AppSpacing.paddingMd,
                  children: [
                    _SummaryHeader(count: data.count),
                    const SizedBox(height: AppSpacing.md),
                    _BankAccountsSection(
                      summaries: data.bankAccounts,
                      onOpen: (summary) => _openDetail(
                        context,
                        ref,
                        summary,
                        VaultRecordRef.bankAccount(summary.nickname),
                      ),
                      onCallback: onOpenRecord,
                    ),
                    _PanCardsSection(
                      summaries: data.panCards,
                      onOpen: (summary) => _openDetail(
                        context,
                        ref,
                        summary,
                        VaultRecordRef.panCard(summary.id),
                      ),
                      onCallback: onOpenRecord,
                    ),
                    _CreditCardsSection(
                      summaries: data.creditCards,
                      onOpen: (summary) => _openDetail(
                        context,
                        ref,
                        summary,
                        VaultRecordRef.creditCard(summary.nickname),
                      ),
                      onCallback: onOpenRecord,
                    ),
                    _DocumentsSection(
                      summaries: data.secureDocuments,
                      onOpen: (summary) => _openDetail(
                        context,
                        ref,
                        summary,
                        VaultRecordRef.secureDocument(summary.nickname),
                      ),
                      onCallback: onOpenRecord,
                    ),
                    const SizedBox(height: 96),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('vault_add_record_button'),
        onPressed: () => _openAddTypePicker(context, ref, onAddRecord),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  void _openDetail(
    BuildContext context,
    WidgetRef ref,
    VaultEntrySummary summary,
    VaultRecordRef recordRef,
  ) {
    onOpenRecord?.call(recordRef);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => RecordDetailSheet(summary: summary, recordRef: recordRef),
    );
  }

  Future<void> _openAddTypePicker(
    BuildContext context,
    WidgetRef ref,
    ValueChanged<VaultRecordType>? callback,
  ) async {
    final type = await showModalBottomSheet<VaultRecordType>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _AddTypePicker(),
    );
    if (type == null) return;
    callback?.call(type);
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => VaultRecordFormScreen(type: type)),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      elevation: 0,
      child: Row(
        children: [
          Icon(Icons.security_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count vault records',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Summaries only. Sensitive fields stay encrypted until reveal.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BankAccountsSection extends StatelessWidget {
  const _BankAccountsSection({
    required this.summaries,
    required this.onOpen,
    required this.onCallback,
  });

  final List<BankAccountSummary> summaries;
  final ValueChanged<BankAccountSummary> onOpen;
  final ValueChanged<VaultRecordRef>? onCallback;

  @override
  Widget build(BuildContext context) {
    return _VaultSection(
      title: 'Bank accounts',
      emptyText: 'No bank accounts yet',
      children: [
        for (final summary in summaries)
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: Text(summary.nickname),
            subtitle: Text('${summary.bankName} · ${summary.ifscCode}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              onCallback?.call(VaultRecordRef.bankAccount(summary.nickname));
              onOpen(summary);
            },
          ),
      ],
    );
  }
}

class _PanCardsSection extends StatelessWidget {
  const _PanCardsSection({
    required this.summaries,
    required this.onOpen,
    required this.onCallback,
  });

  final List<PanCardSummary> summaries;
  final ValueChanged<PanCardSummary> onOpen;
  final ValueChanged<VaultRecordRef>? onCallback;

  @override
  Widget build(BuildContext context) {
    return _VaultSection(
      title: 'PAN cards',
      emptyText: 'No PAN cards yet',
      children: [
        for (final summary in summaries)
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(summary.nameOnCard),
            subtitle: Text('PAN record #${summary.id}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              onCallback?.call(VaultRecordRef.panCard(summary.id));
              onOpen(summary);
            },
          ),
      ],
    );
  }
}

class _CreditCardsSection extends StatelessWidget {
  const _CreditCardsSection({
    required this.summaries,
    required this.onOpen,
    required this.onCallback,
  });

  final List<CreditCardSummary> summaries;
  final ValueChanged<CreditCardSummary> onOpen;
  final ValueChanged<VaultRecordRef>? onCallback;

  @override
  Widget build(BuildContext context) {
    return _VaultSection(
      title: 'Cards',
      emptyText: 'No masked cards yet',
      children: [
        for (final summary in summaries)
          ListTile(
            leading: const Icon(Icons.credit_card_outlined),
            title: Text(summary.nickname),
            subtitle: Text(
              '${summary.issuingBank} · ${summary.cardNetwork.name.toUpperCase()} ending ${summary.last4}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              onCallback?.call(VaultRecordRef.creditCard(summary.nickname));
              onOpen(summary);
            },
          ),
      ],
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({
    required this.summaries,
    required this.onOpen,
    required this.onCallback,
  });

  final List<SecureDocumentSummary> summaries;
  final ValueChanged<SecureDocumentSummary> onOpen;
  final ValueChanged<VaultRecordRef>? onCallback;

  @override
  Widget build(BuildContext context) {
    return _VaultSection(
      title: 'Documents',
      emptyText: 'No secure documents yet',
      children: [
        for (final summary in summaries)
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(summary.nickname),
            subtitle: Text(_documentCategoryLabel(summary.category)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              onCallback?.call(VaultRecordRef.secureDocument(summary.nickname));
              onOpen(summary);
            },
          ),
      ],
    );
  }
}

class _VaultSection extends StatelessWidget {
  const _VaultSection({
    required this.title,
    required this.emptyText,
    required this.children,
  });

  final String title;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: AppSpacing.paddingHorizontalSm,
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            elevation: 0,
            child: children.isEmpty
                ? ListTile(
                    title: Text(emptyText),
                    leading: const Icon(Icons.inbox_outlined),
                  )
                : Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _AddTypePicker extends StatelessWidget {
  const _AddTypePicker();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Add vault record')),
          _TypeTile(
            icon: Icons.account_balance_outlined,
            label: 'Bank account',
            type: VaultRecordType.bankAccount,
          ),
          _TypeTile(
            icon: Icons.badge_outlined,
            label: 'PAN card',
            type: VaultRecordType.panCard,
          ),
          _TypeTile(
            icon: Icons.credit_card_outlined,
            label: 'Masked card',
            type: VaultRecordType.creditCard,
          ),
          _TypeTile(
            icon: Icons.description_outlined,
            label: 'Secure document',
            type: VaultRecordType.secureDocument,
          ),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.icon,
    required this.label,
    required this.type,
  });

  final IconData icon;
  final String label;
  final VaultRecordType type;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => Navigator.of(context).pop(type),
    );
  }
}

String _documentCategoryLabel(DocumentCategory category) {
  return switch (category) {
    DocumentCategory.personalId => 'Personal ID',
    DocumentCategory.incomeProof => 'Income proof',
    DocumentCategory.taxCredit => 'Tax credit',
    DocumentCategory.investmentProof => 'Investment proof',
    DocumentCategory.hra => 'HRA',
    DocumentCategory.capitalGains => 'Capital gains',
    DocumentCategory.homeLoan => 'Home loan',
    DocumentCategory.other => 'Other',
  };
}
