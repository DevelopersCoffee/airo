/// TV Shell with sidebar navigation for Android TV / Fire TV
///
/// Provides a sidebar navigation pattern optimized for D-pad control.
/// No bottom navigation - uses left-side rail navigation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_icon_placeholder.dart';
import '../tv/tv.dart';
import 'tv_router.dart';

/// Provider for current TV navigation index
final tvNavigationIndexProvider = StateProvider<int>((ref) => 0);

/// TV Shell with sidebar navigation
class TvShell extends ConsumerWidget {
  final Widget child;

  const TvShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(tvNavigationIndexProvider);

    return Scaffold(
      body: Row(
        children: [
          // Sidebar navigation rail
          _TvNavigationRail(
            currentIndex: currentIndex,
            onDestinationSelected: (index) {
              ref.read(tvNavigationIndexProvider.notifier).state = index;
              _navigateToIndex(context, index);
            },
          ),
          // Vertical divider
          const VerticalDivider(width: 1, thickness: 1),
          // Main content
          Expanded(child: child),
        ],
      ),
    );
  }

  void _navigateToIndex(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(TvRouteNames.live);
        break;
      case 1:
        context.go(TvRouteNames.settings);
        break;
    }
  }
}

/// TV Navigation Rail with D-pad focus support
class _TvNavigationRail extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  const _TvNavigationRail({
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: _buildLogo(context),
      ),
      destinations: [
        NavigationRailDestination(
          icon: TvFocusable(
            onSelect: () => onDestinationSelected(0),
            child: Icon(
              Icons.live_tv,
              color: currentIndex == 0 ? theme.colorScheme.primary : null,
            ),
          ),
          selectedIcon: const Icon(Icons.live_tv),
          label: const Text('Live TV'),
        ),
        NavigationRailDestination(
          icon: TvFocusable(
            onSelect: () => onDestinationSelected(1),
            child: Icon(
              Icons.settings_outlined,
              color: currentIndex == 1 ? theme.colorScheme.primary : null,
            ),
          ),
          selectedIcon: const Icon(Icons.settings),
          label: const Text('Settings'),
        ),
      ],
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIconPlaceholder(
          size: 48,
          errorBuilder: (_, _, _) => const Icon(Icons.tv, size: 48),
        ),
        const SizedBox(height: 8),
        Text('Airo TV', style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}
