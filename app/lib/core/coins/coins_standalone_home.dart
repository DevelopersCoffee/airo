import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/coins/application/services/coins_platform_support.dart';

/// Home hub for the standalone Airo Coin shell.
///
/// Priority surfaces: Splitwise-style shared expenses (groups, add/split,
/// balances, settle-up) and the encrypted document vault — all on-device.
class CoinsStandaloneHome extends ConsumerWidget {
  const CoinsStandaloneHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitsAvailable = CoinsPlatformSupport.groupsAvailable();
    return Scaffold(
      appBar: AppBar(title: const Text('Airo Coin')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Local-first money',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Split shared expenses and store sensitive documents on this '
            'device — no account required.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _HubEntryCard(
            icon: Icons.groups_outlined,
            title: 'Shared expenses',
            subtitle: splitsAvailable
                ? 'Groups, balances, and settle-up — works offline.'
                : 'Available on Android and desktop builds (SQLite required).',
            onTap: splitsAvailable
                ? () => context.push('/groups')
                : () => _showSplitsUnavailable(context),
          ),
          const SizedBox(height: 12),
          _HubEntryCard(
            icon: Icons.lock_outline,
            title: 'Secure vault',
            subtitle:
                'Bank accounts, cards, insurance, and tax documents — '
                'encrypted on device.',
            onTap: () => context.push('/money/vault'),
          ),
        ],
      ),
    );
  }

  void _showSplitsUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Shared expenses need native storage. Use the Airo Coin Android '
          'app or a desktop build.',
        ),
      ),
    );
  }
}

class _HubEntryCard extends StatelessWidget {
  const _HubEntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: scheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
