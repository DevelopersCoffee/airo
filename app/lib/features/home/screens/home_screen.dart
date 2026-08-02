import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/route_names.dart';

/// Airo's data-honest "Now" surface.
///
/// The dashboard presents continuation points without inventing balances,
/// playback state, or AI activity when those domains have no shared snapshot.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AiroResponsiveScaffold(
      maxWidth: 1200,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: AiroPageHeader(
              eyebrow: 'Now',
              title: 'Your day, in one place',
              subtitle:
                  'Continue where you left off or move between Airo spaces.',
              actions: [
                FilledButton.tonalIcon(
                  onPressed: () => context.go('/assistant/chat'),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Ask Airo'),
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          SliverToBoxAdapter(
            child: Text(
              'Continue',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          SliverToBoxAdapter(
            child: _AdaptiveDestinationGrid(
              destinations: [
                _HomeDestination(
                  title: 'Assistant',
                  description: 'Think, write, and work with your local AI.',
                  icon: Icons.psychology_outlined,
                  route: '/assistant',
                ),
                _HomeDestination(
                  title: 'Coins',
                  description: 'Expenses, budgets & secure vault.',
                  icon: Icons.account_balance_wallet_outlined,
                  route: '/money',
                ),
                _HomeDestination(
                  title: 'Live',
                  description: 'Return to channels, guide, and favorites.',
                  icon: Icons.live_tv_outlined,
                  route: '/iptv',
                ),
                _HomeDestination(
                  title: 'Beats',
                  description: 'Music, listening, and your player.',
                  icon: Icons.graphic_eq,
                  route: '/music',
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          SliverToBoxAdapter(
            child: Text(
              'Your spaces',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          SliverToBoxAdapter(
            child: _AdaptiveDestinationGrid(
              destinations: [
                _HomeDestination(
                  title: 'Arena',
                  description: 'Play focused games at your pace.',
                  icon: Icons.sports_esports_outlined,
                  route: '/games',
                ),
                _HomeDestination(
                  title: 'Quest',
                  description: 'Turn material into guided progress.',
                  icon: Icons.route_outlined,
                  route: '/quest',
                ),
                _HomeDestination(
                  title: 'Settings',
                  description:
                      'Control models, audio, privacy, and appearance.',
                  icon: Icons.tune,
                  route: RouteNames.settings,
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }
}

class _AdaptiveDestinationGrid extends StatelessWidget {
  const _AdaptiveDestinationGrid({required this.destinations});

  final List<_HomeDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              for (var index = 0; index < destinations.length; index++) ...[
                _DestinationCard(destination: destinations[index]),
                if (index != destinations.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var index = 0; index < destinations.length; index += 2) {
          final secondIndex = index + 1;
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DestinationCard(destination: destinations[index]),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: secondIndex < destinations.length
                      ? _DestinationCard(destination: destinations[secondIndex])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
          if (secondIndex < destinations.length - 1) {
            rows.add(const SizedBox(height: AppSpacing.md));
          }
        }
        return Column(children: rows);
      },
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.destination});

  final _HomeDestination destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final domain = AiroDomainTokens.of(context);

    return AiroSurface(
      level: AiroSurfaceLevel.raised,
      onTap: () => context.go(destination.route),
      semanticLabel: 'Open ${destination.title}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: domain.accent.withValues(alpha: 0.12),
              borderRadius: AiroVisualTokens.of(context).smallRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
              child: Icon(destination.icon, color: domain.accent),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(destination.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  destination.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.arrow_forward_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _HomeDestination {
  const _HomeDestination({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
  });

  final String title;
  final String description;
  final IconData icon;
  final String route;
}
