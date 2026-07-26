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

import '../../features/settings/presentation/tv/tv_settings_screen.dart';

/// Provider for current TV navigation index
final tvNavigationIndexProvider = StateProvider<int>((ref) => 0);

/// Non-live destinations the sidebar can show. Rendered as an overlay on
/// top of [TvShell.child] instead of being routed to — routing away would
/// unmount whatever live playback [child] holds (AiroTV D-pad design:
/// "VIDEO LAYER always present, never destroyed" / "Playback never
/// stops"). Only index 0 (Home) ever calls [GoRouter.go]: it's the one
/// case where returning to the live route is actually correct even if it
/// means building a fresh live screen (e.g. after a deep link landed the
/// shell on a non-live route).
enum _TvOverlayScreen { guide, vod, favorites, settings }

/// TV Shell with sidebar navigation
class TvShell extends ConsumerStatefulWidget {
  final Widget child;

  const TvShell({super.key, required this.child});

  @override
  ConsumerState<TvShell> createState() => _TvShellState();
}

class _TvShellState extends ConsumerState<TvShell> {
  _TvOverlayScreen? _overlay;

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(tvNavigationIndexProvider);

    return Scaffold(
      body: Stack(
        children: [
          // The routed content (the live TV screen on the common path).
          // Never removed from the tree by a sidebar tap — only a direct
          // deep link to a different route replaces it.
          Positioned.fill(child: widget.child),
          if (_overlay != null)
            Positioned.fill(
              // The rail stays visible (painted after this, so on top) and
              // isn't docked in a layout row anymore, so it no longer
              // reserves space of its own — give overlay screens the same
              // left inset the old Row gave them, so their content doesn't
              // render underneath the now-floating rail.
              child: Padding(
                padding: const EdgeInsets.only(left: 88),
                child: _buildOverlay(_overlay!),
              ),
            ),
          // The rail is painted on top instead of docked in a Row, so it
          // never claims layout width from the content beneath it.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _TvNavigationRail(
              currentIndex: currentIndex,
              onDestinationSelected: (index) =>
                  _selectDestination(context, index),
            ),
          ),
        ],
      ),
    );
  }

  void _selectDestination(BuildContext context, int index) {
    ref.read(tvNavigationIndexProvider.notifier).state = index;
    if (index == 0) {
      setState(() => _overlay = null);
      GoRouter.of(context).go('/live');
      return;
    }
    setState(() {
      _overlay = switch (index) {
        1 => _TvOverlayScreen.guide,
        2 => _TvOverlayScreen.vod,
        3 => _TvOverlayScreen.favorites,
        _ => _TvOverlayScreen.settings,
      };
    });
  }

  void _closeOverlay() {
    ref.read(tvNavigationIndexProvider.notifier).state = 0;
    setState(() => _overlay = null);
  }

  Widget _buildOverlay(_TvOverlayScreen overlay) {
    return switch (overlay) {
      _TvOverlayScreen.guide => IptvGuideScreen(
        overrideFormFactor: AiroFormFactor.tv,
        onChannelSelected: _closeOverlay,
      ),
      _TvOverlayScreen.vod => const VodTvScreen(),
      _TvOverlayScreen.favorites => const TvFavoritesScreen(),
      _TvOverlayScreen.settings => const TvSettingsScreen(),
    };
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
