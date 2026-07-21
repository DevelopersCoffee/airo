import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import '../../application/vault_session.dart';
import '../../application/vault_summaries_provider.dart';
import '../../domain/vault_record_type.dart';
import '../widgets/record_detail_sheet.dart';

/// Grouped, key-free list of everything in the vault.
///
/// No decryption happens on this screen; rows render from summaries only.
class VaultHomeScreen extends ConsumerWidget {
  const VaultHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(vaultSummariesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Lock vault',
            onPressed: () => ref.read(vaultSessionProvider.notifier).lock(),
          ),
        ],
      ),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(vaultSummariesProvider),
        ),
        data: (data) => data.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.lock_open_outlined,
                title: 'Vault is empty',
                message: 'Add your first record with the + button.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(vaultSummariesProvider),
                child: ListView(
                  children: [
                    _SummarySection(
                      title: 'Bank accounts',
                      tiles: [
                        for (final summary in data.bankAccounts)
                          _tile(
                            context,
                            icon: Icons.account_balance_outlined,
                            title: summary.nickname,
                            subtitle:
                                '${summary.bankName} - ${summary.ifscCode}',
                            type: VaultRecordType.bankAccount,
                            recordKey: summary.nickname,
                            summary: summary,
                          ),
                      ],
                    ),
                    _SummarySection(
                      title: 'PAN cards',
                      tiles: [
                        for (final summary in data.panCards)
                          _tile(
                            context,
                            icon: Icons.badge_outlined,
                            title: summary.nameOnCard,
                            subtitle: 'PAN card',
                            type: VaultRecordType.panCard,
                            recordKey: '${summary.id}',
                            summary: summary,
                          ),
                      ],
                    ),
                    _SummarySection(
                      title: 'Cards',
                      tiles: [
                        for (final summary in data.creditCards)
                          _tile(
                            context,
                            icon: Icons.credit_card_outlined,
                            title: summary.nickname,
                            subtitle:
                                '${summary.cardNetwork.name} - **** ${summary.last4}',
                            type: VaultRecordType.creditCard,
                            recordKey: summary.nickname,
                            summary: summary,
                          ),
                      ],
                    ),
                    _SummarySection(
                      title: 'Documents',
                      tiles: [
                        for (final summary in data.secureDocuments)
                          _tile(
                            context,
                            icon: Icons.folder_shared_outlined,
                            title: summary.nickname,
                            subtitle: summary.category.name,
                            type: VaultRecordType.secureDocument,
                            recordKey: summary.nickname,
                            summary: summary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add record',
        onPressed: () => _showAddPicker(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VaultRecordType type,
    required String recordKey,
    required VaultEntrySummary summary,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => RecordDetailSheet(
          recordType: type,
          recordKey: recordKey,
          summary: summary,
        ),
      ),
    );
  }

  void _showAddPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (type, label, icon) in [
              (
                VaultRecordType.bankAccount,
                'Bank account',
                Icons.account_balance_outlined,
              ),
              (VaultRecordType.panCard, 'PAN card', Icons.badge_outlined),
              (
                VaultRecordType.creditCard,
                'Card (masked)',
                Icons.credit_card_outlined,
              ),
              (
                VaultRecordType.secureDocument,
                'Secure document',
                Icons.folder_shared_outlined,
              ),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/money/vault/add/${type.name}');
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.title, required this.tiles});

  final String title;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        ...tiles,
      ],
    );
  }
}
