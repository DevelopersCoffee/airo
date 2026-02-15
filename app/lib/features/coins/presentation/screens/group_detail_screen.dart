import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/shared_expense.dart';
import '../../application/providers/group_providers.dart';
import '../../application/providers/settlement_providers.dart';

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
    final groupAsync = ref.watch(groupByIdProvider(groupId));
    final expensesAsync = ref.watch(groupExpensesProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));

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
                    // TODO: Add member / share invite
                  },
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'settings',
                      child: Text('Group Settings'),
                    ),
                    const PopupMenuItem(
                      value: 'export',
                      child: Text('Export'),
                    ),
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
                // TODO: Navigate to add shared expense
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            ),
          ),
        );
      },
    );
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

class _ExpenseListTile extends StatelessWidget {
  final SharedExpense expense;
  const _ExpenseListTile({required this.expense});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(expense.description.substring(0, 1).toUpperCase()),
      ),
      title: Text(expense.description),
      subtitle: Text('Paid by ${expense.paidByUserId}'),
      trailing: Text(
        '₹${(expense.totalAmountCents / 100).toStringAsFixed(2)}',
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
                    Text('Group Summary', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Total expenses: ₹${(summary.totalExpensesCents / 100).toStringAsFixed(2)}'),
                    Text('Total settled: ₹${(summary.totalSettlementsCents / 100).toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Simplified Debts', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            // TODO: Show simplified debts list
            const Text('All debts settled!'),
          ],
        );
      },
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

