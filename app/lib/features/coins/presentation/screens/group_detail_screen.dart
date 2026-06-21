import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/locale_settings.dart';
import '../../../bill_split/domain/models/receipt_item.dart';
import '../../../bill_split/presentation/screens/itemized_split_screen.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/entities/shared_expense.dart';
import '../../application/providers/group_providers.dart';
import '../../application/providers/settlement_providers.dart';
import '../../application/providers/split_providers.dart';
import '../../application/services/coins_platform_support.dart';
import '../../application/use_cases/add_split_use_case.dart';
import '../../domain/entities/split_entry.dart';
import 'add_split_expense_screen.dart';

/// Group Detail Screen
///
/// Shows group details including:
/// - Group info and members
/// - Expense list
/// - Balance summary
/// - Settlement actions
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/UI_WIREFRAMES.md (Screen 6)
class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!CoinsPlatformSupport.groupsAvailable()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Groups')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Group expense splitting is available on mobile and desktop. Web support needs a non-SQLite storage backend.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final groupAsync = ref.watch(groupByIdProvider(groupId));
    return groupAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $error')),
      ),
      data: (group) {
        if (group == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Group not found')),
          );
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(group.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_add_outlined),
                  onPressed: () {
                    _showAddMemberDialog(context, ref, groupId);
                  },
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'settings',
                      child: Text('Group Settings'),
                    ),
                    const PopupMenuItem(value: 'export', child: Text('Export')),
                    const PopupMenuItem(
                      value: 'leave',
                      child: Text('Leave Group'),
                    ),
                  ],
                  onSelected: (value) {
                    // TODO: Handle menu actions
                  },
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Expenses'),
                  Tab(text: 'Balances'),
                  Tab(text: 'Members'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // Expenses Tab
                _ExpensesTab(groupId: groupId),

                // Balances Tab
                _BalancesTab(groupId: groupId),

                // Members Tab
                _MembersTab(groupId: groupId),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _showAddExpenseActions(context, ref, groupId),
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            ),
          ),
        );
      },
    );
  }

  void _showAddExpenseActions(
    BuildContext context,
    WidgetRef ref,
    String groupId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Add manually'),
              subtitle: const Text('Enter amount and split equally'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddSplitExpenseScreen(groupId: groupId),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Upload bill'),
              subtitle: const Text('Scan items, assign owners, save split'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openItemizedBillSplit(context, ref, groupId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openItemizedBillSplit(
    BuildContext context,
    WidgetRef ref,
    String groupId,
  ) async {
    try {
      final members = await ref.read(groupMembersProvider(groupId).future);
      if (!context.mounted) return;
      if (members.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add group members before splitting')),
        );
        return;
      }

      final participants = members
          .map(
            (member) => ItemParticipant(
              id: member.userId,
              name: member.displayName,
              avatarUrl: member.avatarUrl,
            ),
          )
          .toList();

      final result = await Navigator.push<ItemizedSplitResult>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ItemizedSplitScreen(initialParticipants: participants),
        ),
      );
      if (!context.mounted || result == null) return;

      await _saveItemizedSplit(context, ref, groupId, result);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open bill upload: $e')));
    }
  }

  Future<void> _saveItemizedSplit(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    ItemizedSplitResult result,
  ) async {
    final summary = result.summary;
    final totalAmountCents = summary.values.fold<int>(
      0,
      (sum, amount) => sum + amount,
    );
    if (summary.isEmpty || totalAmountCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No split amounts found in this bill')),
      );
      return;
    }

    final payerId = summary.keys.first;
    final itemizedItems = _buildItemizedInputs(result, totalAmountCents);

    final saveResult = await ref
        .read(addSplitUseCaseProvider)
        .execute(
          AddSplitParams(
            groupId: groupId,
            description: result.description,
            totalAmountCents: totalAmountCents,
            currencyCode: ref.read(currencyFormatterProvider).currency.code,
            paidByUserId: payerId,
            splitType: SplitType.itemized,
            participantIds: summary.keys.toList(growable: false),
            itemizedItems: itemizedItems,
          ),
        );

    if (!context.mounted) return;
    if (saveResult.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(saveResult.error!)));
      return;
    }

    ref.invalidate(groupExpensesProvider(groupId));
    ref.invalidate(groupBalanceSummaryProvider(groupId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Itemized bill saved to Coins')),
    );
  }

  List<ItemizedSplitInput> _buildItemizedInputs(
    ItemizedSplitResult result,
    int totalAmountCents,
  ) {
    final inputs = <ItemizedSplitInput>[];
    final itemOnlyTotals = <String, int>{
      for (final id in result.summary.keys) id: 0,
    };

    for (var i = 0; i < result.itemizedDetails.length; i++) {
      final item = result.itemizedDetails[i];
      final itemId = 'item_${i}_${_slugForItemId(item.name)}';
      inputs.add(
        ItemizedSplitInput(
          itemId: itemId,
          name: item.name,
          amountCents: item.pricePaise,
          participantIds: item.participantIds.toList(growable: false),
        ),
      );

      final participantIds = item.participantIds.toList(growable: false);
      if (participantIds.isEmpty) continue;
      final share = item.pricePaise ~/ participantIds.length;
      final remainder = item.pricePaise % participantIds.length;
      for (var index = 0; index < participantIds.length; index++) {
        itemOnlyTotals[participantIds[index]] =
            (itemOnlyTotals[participantIds[index]] ?? 0) +
            share +
            (index < remainder ? 1 : 0);
      }
    }

    var currentTotal = inputs.fold<int>(
      0,
      (sum, item) => sum + item.amountCents,
    );
    if (currentTotal < totalAmountCents) {
      for (final entry in result.summary.entries) {
        final adjustment = entry.value - (itemOnlyTotals[entry.key] ?? 0);
        if (adjustment <= 0) continue;
        inputs.add(
          ItemizedSplitInput(
            itemId: 'fees_${entry.key}',
            name: 'Fees and adjustments',
            amountCents: adjustment,
            participantIds: [entry.key],
          ),
        );
        currentTotal += adjustment;
      }
    }

    return inputs;
  }

  String _slugForItemId(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return slug.isEmpty ? 'line' : slug;
  }

  void _showAddMemberDialog(
    BuildContext context,
    WidgetRef ref,
    String groupId,
  ) {
    final nameController = TextEditingController();
    final dialog = showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Member'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Member name',
            hintText: 'Rahul',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(addMemberProvider.notifier)
                  .addMemberFromInput(
                    groupId: groupId,
                    displayName: nameController.text,
                  );
              if (!context.mounted || !dialogContext.mounted) return;
              final state = ref.read(addMemberProvider);
              state.whenOrNull(
                data: (_) => Navigator.pop(dialogContext),
                error: (error, _) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                },
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    dialog.whenComplete(nameController.dispose);
  }
}

class _ExpensesTab extends ConsumerWidget {
  final String groupId;
  const _ExpensesTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(groupExpensesProvider(groupId));

    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (expenses) {
        if (expenses.isEmpty) {
          return const Center(
            child: Text('No expenses yet.\nAdd your first expense!'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final expense = expenses[index];
            return _ExpenseListTile(expense: expense);
          },
        );
      },
    );
  }
}

class _ExpenseListTile extends ConsumerWidget {
  final SharedExpense expense;
  const _ExpenseListTile({required this.expense});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = ref.watch(currencyFormatterProvider);
    return ListTile(
      leading: CircleAvatar(
        child: Text(expense.description.substring(0, 1).toUpperCase()),
      ),
      title: Text(expense.description),
      subtitle: Text('Paid by ${expense.paidByUserId}'),
      trailing: Text(
        formatter.formatCents(expense.totalAmountCents),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: () {
        // TODO: Show expense details
      },
    );
  }
}

class _BalancesTab extends ConsumerWidget {
  final String groupId;
  const _BalancesTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(groupBalanceSummaryProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final formatter = ref.watch(currencyFormatterProvider);

    return balancesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (summary) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Group Summary',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total expenses: ${formatter.formatCents(summary.totalExpensesCents)}',
                    ),
                    Text(
                      'Total settled: ${formatter.formatCents(summary.totalSettlementsCents)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Simplified Debts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            membersAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (error, _) => Text('Error loading members: $error'),
              data: (members) {
                if (summary.simplifiedDebts.isEmpty) {
                  return const Text('All debts settled!');
                }
                final namesByUserId = {
                  for (final member in members)
                    member.userId: member.displayName,
                };
                return Column(
                  children: summary.simplifiedDebts
                      .map(
                        (debt) => _DebtTile(
                          groupId: groupId,
                          fromName:
                              namesByUserId[debt.fromUserId] ?? debt.fromUserId,
                          toName: namesByUserId[debt.toUserId] ?? debt.toUserId,
                          fromUserId: debt.fromUserId,
                          toUserId: debt.toUserId,
                          amountCents: debt.amountCents,
                          currencyCode: debt.currencyCode,
                          amountLabel: formatter.formatCents(debt.amountCents),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _DebtTile extends ConsumerWidget {
  final String groupId;
  final String fromName;
  final String toName;
  final String fromUserId;
  final String toUserId;
  final int amountCents;
  final String currencyCode;
  final String amountLabel;

  const _DebtTile({
    required this.groupId,
    required this.fromName,
    required this.toName,
    required this.fromUserId,
    required this.toUserId,
    required this.amountCents,
    required this.currencyCode,
    required this.amountLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('$fromName owes $toName'),
      subtitle: Text(amountLabel),
      trailing: FilledButton(
        onPressed: () async {
          final now = DateTime.now();
          await ref
              .read(recordSettlementProvider.notifier)
              .recordSettlement(
                Settlement(
                  id: 'settlement_${now.microsecondsSinceEpoch}',
                  groupId: groupId,
                  fromUserId: fromUserId,
                  toUserId: toUserId,
                  amountCents: amountCents,
                  currencyCode: currencyCode,
                  status: SettlementStatus.completed,
                  settlementDate: now,
                  createdAt: now,
                ),
              );
          if (!context.mounted) return;
          final state = ref.read(recordSettlementProvider);
          if (state.hasError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.error.toString())));
            return;
          }
          ref.invalidate(groupSettlementsProvider(groupId));
          ref.invalidate(groupBalanceSummaryProvider(groupId));
        },
        child: const Text('Settle'),
      ),
    );
  }
}

class _MembersTab extends ConsumerWidget {
  final String groupId;
  const _MembersTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(groupMembersProvider(groupId));

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (members) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: member.avatarUrl != null
                    ? NetworkImage(member.avatarUrl!)
                    : null,
                child: member.avatarUrl == null
                    ? Text(member.displayName.substring(0, 1).toUpperCase())
                    : null,
              ),
              title: Text(member.displayName),
              subtitle: Text(member.role.name),
              trailing: member.role.name == 'admin'
                  ? const Chip(label: Text('Admin'))
                  : null,
            );
          },
        );
      },
    );
  }
}
