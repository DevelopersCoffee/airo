import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/dashboard_providers.dart';

/// Coins Dashboard Screen
///
/// Main screen for the Coins feature showing:
/// - Safe-to-spend amount
/// - Quick stats (today's spending, pending settlements)
/// - Recent transactions
/// - Budget overview
/// - Quick action buttons
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/UI_WIREFRAMES.md (Screen 1)
class CoinsDashboardScreen extends ConsumerWidget {
  const CoinsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coins'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Navigate to notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading dashboard: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(dashboardDataProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardRefreshProvider.future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Safe to Spend Card
                  _SafeToSpendCard(data: data),
                  const SizedBox(height: 16),

                  // Quick Actions
                  _QuickActionsRow(),
                  const SizedBox(height: 24),

                  // Today's Summary
                  _TodaySummarySection(data: data),
                  const SizedBox(height: 24),

                  // Recent Transactions
                  _RecentTransactionsSection(
                    transactions: data.recentExpenses,
                  ),
                  const SizedBox(height: 24),

                  // Budget Overview
                  _BudgetOverviewSection(
                    budgetStatuses: data.budgetStatuses,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to add expense screen
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
}

// TODO: Implement these widget classes in separate files
class _SafeToSpendCard extends StatelessWidget {
  final DashboardData data;
  const _SafeToSpendCard({required this.data});

  @override
  Widget build(BuildContext context) {
    // TODO: Implement safe-to-spend card UI
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Text('Safe to Spend Today'),
            SizedBox(height: 8),
            Text('₹0', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: Implement quick actions (Add, Split, Transfer, Scan)
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _QuickActionButton(icon: Icons.add, label: 'Add'),
        _QuickActionButton(icon: Icons.call_split, label: 'Split'),
        _QuickActionButton(icon: Icons.swap_horiz, label: 'Transfer'),
        _QuickActionButton(icon: Icons.camera_alt, label: 'Scan'),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _QuickActionButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(child: Icon(icon)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _TodaySummarySection extends StatelessWidget {
  final DashboardData data;
  const _TodaySummarySection({required this.data});

  @override
  Widget build(BuildContext context) {
    // TODO: Implement today's summary UI
    return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Today\'s Summary')));
  }
}

class _RecentTransactionsSection extends StatelessWidget {
  final List transactions;
  const _RecentTransactionsSection({required this.transactions});

  @override
  Widget build(BuildContext context) {
    // TODO: Implement recent transactions list
    return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Recent Transactions')));
  }
}

class _BudgetOverviewSection extends StatelessWidget {
  final List budgetStatuses;
  const _BudgetOverviewSection({required this.budgetStatuses});

  @override
  Widget build(BuildContext context) {
    // TODO: Implement budget overview
    return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Budget Overview')));
  }
}

