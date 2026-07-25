/// TV Shell with sidebar navigation for Android TV / Fire TV
///
/// Provides a sidebar navigation pattern optimized for D-pad control.
/// No bottom navigation - uses left-side rail navigation.
library;

import 'package:core_product_shell/core_product_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

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
        context.go(TvRouteNames.guide);
        break;
      case 2:
        context.go(TvRouteNames.vod);
        break;
      case 3:
        context.go(TvRouteNames.favorites);
        break;
      case 4:
        context.go(TvRouteNames.settings);
        break;
    }
  }
}

/// The TV rail renders the shared [iptvNavigationDestinations] manifest —
/// the same single source of truth the mobile drawer
/// (`IptvNavigationDrawer` in
/// `packages/feature_iptv/lib/presentation/widgets/iptv_navigation_drawer.dart`)
/// renders. Order, icons, and per-shell label ("Movies" here vs. "Movies &
/// Shows" on mobile) all come from that one list; only the rail's own visual
/// chrome (D-pad focus, left accent bar, width) stays TV-specific here.
final _tvNavDestinations = iptvNavigationDestinations;

/// TV navigation sidebar with D-pad focus support, matching the Airo TV
/// design handoff's rail: a green square logo mark up top, then icon+label
/// stacks with a left accent bar on the active destination.
class _TvNavigationRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  const _TvNavigationRail({
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final chromeSurface =
        theme.extension<AiroThemeTokens>()?.chromeSurface ?? colors.surface;

    return Container(
      key: const Key('tv-sidebar-nav'),
      width: 88,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: chromeSurface,
        border: Border(right: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        children: [
          _TvSidebarLogo(onSelect: () => onDestinationSelected(0)),
          const SizedBox(height: 28),
          for (var i = 0; i < _tvNavDestinations.length; i++)
            _TvNavItem(
              destination: _tvNavDestinations[i],
              selected: currentIndex == i,
              onSelect: () => onDestinationSelected(i),
            ),
        ],
      ),
    );
  }
}

class _TvSidebarLogo extends StatelessWidget {
  const _TvSidebarLogo({required this.onSelect});

  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TvFocusable(
      onSelect: onSelect,
      semanticLabel: 'Airo TV home',
      semanticButton: true,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.4),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Text(
              'A',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: colors.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'AIRO TV',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TvNavItem extends StatefulWidget {
  const _TvNavItem({
    required this.destination,
    required this.selected,
    required this.onSelect,
  });

  final IptvNavigationDestination destination;
  final bool selected;
  final VoidCallback onSelect;

  @override
  State<_TvNavItem> createState() => _TvNavItemState();
}

class _TvNavItemState extends State<_TvNavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = widget.selected;
    final iconColor = active
        ? colors.primary
        : colors.onSurfaceVariant.withValues(alpha: 0.85);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 7),
      child: TvFocusable(
        onSelect: widget.onSelect,
        onFocus: () => setState(() => _focused = true),
        onUnfocus: () => setState(() => _focused = false),
        semanticLabel: widget.destination.semanticLabel,
        semanticButton: true,
        borderRadius: 12,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (active)
              Positioned(
                left: -7,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: _focused ? colors.surfaceContainerHighest : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    active
                        ? widget.destination.selectedIcon
                        : widget.destination.icon,
                    size: 19,
                    color: iconColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.destination.labelFor(ShellId.tv),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                      color: iconColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
