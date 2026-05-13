import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/locale_settings.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/entities/shared_expense.dart';
import '../../application/providers/group_providers.dart';
import '../../application/providers/settlement_providers.dart';
import '../../application/services/coins_platform_support.dart';
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddSplitExpenseScreen(groupId: groupId),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            ),
          ),
        );
      },
    );
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
