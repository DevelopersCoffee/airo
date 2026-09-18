/// TV Shell with sidebar navigation for Android TV / Fire TV
///
/// Provides a sidebar navigation pattern optimized for D-pad control.
/// No bottom navigation - uses left-side rail navigation.
library;

import 'dart:async';

import 'package:core_product_shell/core_product_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'tv_route_names.dart';

/// Provider for current TV navigation index
final tvNavigationIndexProvider = StateProvider<int>((ref) => 0);

/// Collapsed rail: icons only. `xxxl` (64) + `md` (16) = 80.
const _tvRailCollapsedWidth = AiroSpacing.xxxl + AiroSpacing.md;

/// Expanded rail: brand + destination labels. `tvChannelCardW` (200) + `xl` (32) = 240.
const _tvRailExpandedWidth = AiroSpacing.tvChannelCardW + AiroSpacing.xl;

/// Coalesces [VideoPlayerStreamingService.stop] for one Watch session so
/// the awaited leave path and dispose's safety net share a single call.
final _tvWatchStop = Expando<Future<void>>();

Future<void> awaitTvWatchStop(VideoPlayerStreamingService service) {
  return _tvWatchStop[service] ??= service.stop();
}

void resetTvWatchStop(VideoPlayerStreamingService service) {
  _tvWatchStop[service] = null;
}

bool isTvWatchRoute(String location) {
  return location == TvRouteNames.player ||
      location == TvRouteNames.live ||
      location == '/iptv' ||
      location == '/airo/iptv';
}

/// Fraction of each edge a TV may crop. Televisions with overscan enabled
/// discard roughly the outer 5%, which is why the Android TV guidance puts a
/// 5% title-safe margin around anything the user has to see or reach.
///
/// Measured on the rig Fire TV Stick at 1920x1080 before this existed: the
/// sidebar's leftmost pixel sat at x=32 against a 96px safe inset, so the whole
/// navigation rail — and the cast/favourite actions on the right — were inside
/// the croppable band (#1429).
@visibleForTesting
const tvTitleSafeFraction = 0.05;

/// The inset the shell reserves on every edge.
@visibleForTesting
EdgeInsets tvTitleSafeInsets(Size size) => EdgeInsets.symmetric(
  horizontal: size.width * tvTitleSafeFraction,
  vertical: size.height * tvTitleSafeFraction,
);

/// TV Shell with sidebar navigation
class TvShell extends ConsumerStatefulWidget {
  final Widget child;

  const TvShell({super.key, required this.child});

  @override
  ConsumerState<TvShell> createState() => _TvShellState();
}

class _TvShellState extends ConsumerState<TvShell> {
  late final List<FocusNode> _railFocusNodes = List.generate(
    _tvNavDestinations.length,
    (index) => FocusNode(
      debugLabel: 'TV rail ${_tvNavDestinations[index].labelFor(ShellId.tv)}',
    ),
  );
  final FocusNode _logoFocusNode = FocusNode(debugLabel: 'TV rail logo');
  FocusNode? _lastContentFocus;
  bool _railFocused = false;

  double get _railWidth =>
      _railFocused ? _tvRailExpandedWidth : _tvRailCollapsedWidth;

  @override
  void initState() {
    super.initState();
    _logoFocusNode.addListener(_syncRailFocus);
    for (final node in _railFocusNodes) {
      node.addListener(_syncRailFocus);
    }
  }

  @override
  void dispose() {
    _logoFocusNode.removeListener(_syncRailFocus);
    _logoFocusNode.dispose();
    for (final node in _railFocusNodes) {
      node.removeListener(_syncRailFocus);
      node.dispose();
    }
    super.dispose();
  }

  void _syncRailFocus() {
    final focused =
        _logoFocusNode.hasFocus || _railFocusNodes.any((node) => node.hasFocus);
    if (!mounted || focused == _railFocused) return;
    setState(() => _railFocused = focused);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(tvNavigationIndexProvider);
    // Zen mode: once the player goes fullscreen, no shell chrome at all —
    // the sidebar was painted on top of the video and also stole D-pad
    // focus that should land on the player's own transport controls.
    final isPlayerFullscreen = ref.watch(isFullscreenModeProvider);
    final router = GoRouter.maybeOf(context);
    final location = router == null
        ? TvRouteNames.home
        : GoRouterState.of(context).matchedLocation;
    // Sibling shell routes have canPop == false. Without consuming BACK,
    // Android finishes the activity (store-rejecting). Watch owns its own
    // PopScope so stop() still runs; fullscreen Back exits zen mode.
    final consumeBack =
        router != null &&
        location != TvRouteNames.home &&
        !isPlayerFullscreen &&
        !isTvWatchRoute(location);

    // Hold the chrome inside the title-safe band so an overscanning TV cannot
    // crop the navigation rail or the top-right actions. Fullscreen playback is
    // deliberately exempt: video should fill the panel edge to edge, and losing
    // a few pixels of picture to overscan is normal, whereas losing the only
    // way to navigate is not.
    final body = Stack(
      children: [
        Positioned.fill(
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: _handleContentKeyEvent,
            child: Padding(
              padding: EdgeInsets.only(
                left: isPlayerFullscreen ? 0 : _railWidth,
              ),
              child: widget.child,
            ),
          ),
        ),
        if (!isPlayerFullscreen)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Focus(
              canRequestFocus: false,
              onKeyEvent: _handleRailKeyEvent,
              child: _TvNavigationRail(
                width: _railWidth,
                expanded: _railFocused,
                currentIndex: currentIndex,
                logoFocusNode: _logoFocusNode,
                focusNodes: _railFocusNodes,
                onDestinationSelected: (index) =>
                    _selectDestination(context, index),
              ),
            ),
          ),
      ],
    );

    final scaffold = Scaffold(
      body: isPlayerFullscreen
          ? body
          : Padding(
              key: const Key('tv-title-safe-inset'),
              padding: tvTitleSafeInsets(MediaQuery.sizeOf(context)),
              child: body,
            ),
    );

    if (!consumeBack) return scaffold;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(tvNavigationIndexProvider.notifier).state = 0;
        context.go(TvRouteNames.home);
      },
      child: scaffold,
    );
  }

  KeyEventResult _handleContentKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowLeft ||
        ref.read(isFullscreenModeProvider)) {
      return KeyEventResult.ignored;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || !_isLeadingEdgeFocus(primary)) {
      return KeyEventResult.ignored;
    }
    final currentIndex = ref.read(tvNavigationIndexProvider);
    final target =
        _railFocusNodes[currentIndex.clamp(0, _railFocusNodes.length - 1)];
    if (!target.canRequestFocus) return KeyEventResult.ignored;
    _lastContentFocus = primary;
    target.requestFocus();
    return KeyEventResult.handled;
  }

  KeyEventResult _handleRailKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }
    final last = _lastContentFocus;
    if (last == null || !last.canRequestFocus) {
      return KeyEventResult.ignored;
    }
    last.requestFocus();
    return KeyEventResult.handled;
  }

  /// Flutter's spatial traversal does not cross reliably from a focus scope
  /// painted in the shell body into a sibling rail painted later in a Stack
  /// on Fire OS. Detect the visual leading edge and provide that one explicit
  /// bridge, while preserving LEFT traversal between controls within a row.
  bool _isLeadingEdgeFocus(FocusNode primary) {
    final primaryRect = _focusRect(primary);
    if (primaryRect == null) return false;
    final contentLeft = _contentLeftInset();
    for (final candidate in FocusManager.instance.rootScope.descendants) {
      if (identical(candidate, primary) ||
          !candidate.canRequestFocus ||
          _isRailFocus(candidate)) {
        continue;
      }
      final candidateRect = _focusRect(candidate);
      if (candidateRect == null ||
          candidateRect.center.dx < contentLeft ||
          candidateRect.center.dx >= primaryRect.center.dx - 1) {
        continue;
      }
      final overlapsVerticalBeam =
          candidateRect.bottom > primaryRect.top &&
          candidateRect.top < primaryRect.bottom;
      if (overlapsVerticalBeam) return false;
    }
    return true;
  }

  /// Global x of the content region's left edge: title-safe inset plus the
  /// current (collapsed or expanded) rail width. Leading-edge LEFT ignores
  /// focusables inside the rail so the bridge still fires after expand.
  double _contentLeftInset() {
    return tvTitleSafeInsets(MediaQuery.sizeOf(context)).left + _railWidth;
  }

  bool _isRailFocus(FocusNode node) {
    if (_railFocusNodes.contains(node) || identical(node, _logoFocusNode)) {
      return true;
    }
    final context = node.context;
    if (context == null) return false;
    var inRail = false;
    context.visitAncestorElements((element) {
      if (element.widget.key == const Key('tv-sidebar-nav')) {
        inRail = true;
        return false;
      }
      return true;
    });
    return inRail;
  }

  Rect? _focusRect(FocusNode node) {
    final renderObject = node.context?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize ||
        renderObject.size.isEmpty) {
      return null;
    }
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  void _selectDestination(BuildContext context, int index) {
    ref.read(tvNavigationIndexProvider.notifier).state = index;
    final destination = switch (index) {
      0 => TvRouteNames.home,
      1 => TvRouteNames.guide,
      2 => TvRouteNames.vod,
      3 => TvRouteNames.favorites,
      _ => TvRouteNames.settings,
    };
    unawaited(_goToDestination(context, destination));
  }

  Future<void> _goToDestination(
    BuildContext context,
    String destination,
  ) async {
    final location = GoRouterState.of(context).matchedLocation;
    if (isTvWatchRoute(location)) {
      await awaitTvWatchStop(ref.read(iptvStreamingServiceProvider));
    }
    if (!context.mounted) return;
    GoRouter.of(context).go(destination);
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

/// TV navigation sidebar with D-pad focus support: collapsed icons, expanded
/// icon+label with a left accent bar on the active destination.
class _TvNavigationRail extends StatelessWidget {
  final double width;
  final bool expanded;
  final int currentIndex;
  final FocusNode logoFocusNode;
  final List<FocusNode> focusNodes;
  final ValueChanged<int> onDestinationSelected;

  const _TvNavigationRail({
    required this.width,
    required this.expanded,
    required this.currentIndex,
    required this.logoFocusNode,
    required this.focusNodes,
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
      width: width,
      padding: const EdgeInsets.symmetric(vertical: AiroSpacing.lg),
      decoration: BoxDecoration(
        color: chromeSurface,
        border: Border(right: BorderSide(color: colors.outlineVariant)),
      ),
      // Scrollable so the rail survives a shorter viewport -- the title-safe
      // band takes 10% of the height, and a sixth destination would overflow a
      // fixed column just as readily. Flutter scrolls the focused item into
      // view, so D-pad traversal is unaffected.
      child: SingleChildScrollView(
        child: Column(
          children: [
            _TvSidebarLogo(
              expanded: expanded,
              focusNode: logoFocusNode,
              onSelect: () => onDestinationSelected(0),
            ),
            const SizedBox(height: AiroSpacing.lg + AiroSpacing.xs),
            for (var i = 0; i < _tvNavDestinations.length; i++)
              _TvNavItem(
                destination: _tvNavDestinations[i],
                focusNode: focusNodes[i],
                selected: currentIndex == i,
                expanded: expanded,
                onSelect: () => onDestinationSelected(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _TvSidebarLogo extends StatelessWidget {
  const _TvSidebarLogo({
    required this.expanded,
    required this.focusNode,
    required this.onSelect,
  });

  final bool expanded;
  final FocusNode focusNode;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: colors.primary,
    );

    return TvFocusable(
      focusNode: focusNode,
      onSelect: onSelect,
      semanticLabel: '${TvStoreProduct.displayName} home',
      semanticButton: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? AiroSpacing.sm : AiroSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: expanded
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Container(
              width: AiroSpacing.tvMinTarget,
              height: AiroSpacing.tvMinTarget,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(AiroSpacing.radiusMd + 3),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.4),
                    blurRadius: AiroSpacing.lg,
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
            if (expanded) ...[
              const SizedBox(width: AiroSpacing.sm),
              Text(
                TvStoreProduct.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TvNavItem extends StatefulWidget {
  const _TvNavItem({
    required this.destination,
    required this.focusNode,
    required this.selected,
    required this.expanded,
    required this.onSelect,
  });

  final IptvNavigationDestination destination;
  final FocusNode focusNode;
  final bool selected;
  final bool expanded;
  final VoidCallback onSelect;

  @override
  State<_TvNavItem> createState() => _TvNavItemState();
}

class _TvNavItemState extends State<_TvNavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final active = widget.selected;
    final iconColor = active
        ? colors.primary
        : colors.onSurfaceVariant.withValues(alpha: 0.85);
    final icon = Icon(
      active ? widget.destination.selectedIcon : widget.destination.icon,
      size: 24,
      color: iconColor,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: AiroSpacing.sm,
        horizontal: widget.expanded ? AiroSpacing.sm : AiroSpacing.xs,
      ),
      child: Align(
        alignment: widget.expanded ? Alignment.centerLeft : Alignment.center,
        child: TvFocusable(
          focusNode: widget.focusNode,
          onSelect: widget.onSelect,
          onFocus: () => setState(() => _focused = true),
          onUnfocus: () => setState(() => _focused = false),
          semanticLabel: widget.destination.semanticLabel,
          semanticButton: true,
          borderRadius: AiroSpacing.radiusMd,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (active)
                Positioned(
                  left: widget.expanded ? -AiroSpacing.sm : -AiroSpacing.xs,
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
                padding: EdgeInsets.symmetric(
                  vertical: AiroSpacing.sm + AiroSpacing.xxs,
                  horizontal: AiroSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: _focused ? colors.surfaceContainerHighest : null,
                  borderRadius: BorderRadius.circular(AiroSpacing.radiusMd),
                ),
                child: widget.expanded
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          icon,
                          const SizedBox(width: AiroSpacing.sm),
                          Text(
                            widget.destination.labelFor(ShellId.tv),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: iconColor,
                            ),
                          ),
                        ],
                      )
                    : icon,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
