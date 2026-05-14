import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core_ui/core_ui.dart';
import '../auth/auth_service.dart';
import '../auth/google_auth_service.dart';
import '../providers/bedtime_mode_provider.dart';
import '../providers/navigation_provider.dart';
import '../routing/route_names.dart';
import '../../features/music/presentation/widgets/mini_player.dart';
import '../../features/iptv/presentation/widgets/iptv_mini_player.dart';
import '../../features/iptv/application/providers/iptv_providers.dart'
    hide currentNavigationTabProvider;

/// Get initials from a name (e.g., "Uday Chauhan" -> "UC", "Uday" -> "U")
String _getInitials(String name) {
  final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'U';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

/// App shell with bottom navigation for the six primary feature tabs.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleepTimer = ref.watch(sleepTimerProvider);
    final isFullscreen = ref.watch(isFullscreenModeProvider);
    final user = AuthService.instance.currentUser;

    // In fullscreen mode, return just the navigation shell content without app bar or bottom nav
    if (isFullscreen) {
      return Scaffold(body: navigationShell);
    }

    final navigationTabs = ref.watch(appNavigationTabsProvider);
    final currentPageName = navigationTabs[navigationShell.currentIndex].label;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _AiroShellBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 760;
              final pagePadding = isCompact ? 12.0 : 32.0;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1600),
                  child: Padding(
                    padding: EdgeInsets.all(pagePadding),
                    child: Column(
                      children: [
                        _HermesHeaderGrid(
                          currentPageName: currentPageName,
                          user: user,
                          onHome: () => _selectTab(ref, 0),
                          onProfile: () => context.push('/agent/profile'),
                          onLogout: () async {
                            if (user?.isGoogleUser == true) {
                              await GoogleAuthService.instance.signOut();
                            }
                            await AuthService.instance.logout();
                            if (context.mounted) {
                              context.go(RouteNames.login);
                            }
                          },
                        ),
                        Expanded(
                          child: _ContextAwareMiniPlayers(
                            currentIndex: navigationShell.currentIndex,
                            child: navigationShell,
                          ),
                        ),
                        _HermesFooterNavigation(
                          navigationTabs: navigationTabs,
                          selectedIndex: navigationShell.currentIndex,
                          onSelected: (index) {
                            if (ref.read(isFullscreenModeProvider)) {
                              ref
                                      .read(isFullscreenModeProvider.notifier)
                                      .state =
                                  false;
                              SystemChrome.setEnabledSystemUIMode(
                                SystemUiMode.edgeToEdge,
                              );
                              SystemChrome.setPreferredOrientations([
                                DeviceOrientation.portraitUp,
                              ]);
                            }
                            _selectTab(ref, index);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: sleepTimer > 0
          ? FloatingActionButton.extended(
              onPressed: () {
                ref.read(sleepTimerProvider.notifier).cancelSleepTimer();
              },
              label: Text('Sleep in $sleepTimer min'),
              icon: const Icon(Icons.timer),
            )
          : null,
    );
  }

  void _selectTab(WidgetRef ref, int index) {
    ref.read(currentNavigationTabProvider.notifier).state = index;
    navigationShell.goBranch(index);
  }
}

class _HermesHeaderGrid extends StatelessWidget {
  const _HermesHeaderGrid({
    required this.currentPageName,
    required this.user,
    required this.onHome,
    required this.onProfile,
    required this.onLogout,
  });

  final String currentPageName;
  final dynamic user;
  final VoidCallback onHome;
  final VoidCallback onProfile;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final titleStyle = const TextStyle(
      fontFamily: 'AiroCollapse',
      fontSize: 42,
      height: 0.94,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );
    final labelStyle = theme.textTheme.labelLarge;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
          left: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: SizedBox(
        height: 112,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: _HermesCellButton(
                onTap: onHome,
                alignment: Alignment.topLeft,
                child: Text('AIRO\nAPP', style: titleStyle),
              ),
            ),
            Expanded(
              flex: 2,
              child: _HermesGridCell(
                alignment: Alignment.topLeft,
                child: Text(currentPageName.toUpperCase(), style: labelStyle),
              ),
            ),
            if (MediaQuery.sizeOf(context).width >= 720)
              Expanded(
                flex: 2,
                child: _HermesGridCell(
                  alignment: Alignment.topLeft,
                  child: Text('WORKFLOW', style: labelStyle),
                ),
              ),
            Expanded(
              flex: 2,
              child: PopupMenuButton<String>(
                color: colorScheme.surface,
                surfaceTintColor: Colors.transparent,
                shape: const RoundedRectangleBorder(),
                onSelected: (value) async {
                  if (value == 'profile') {
                    onProfile();
                  } else if (value == 'logout') {
                    await onLogout();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        const Icon(Icons.person),
                        const SizedBox(width: 8),
                        Text(user?.username ?? 'Guest'),
                        if (user?.isGoogleUser == true) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
                child: _HermesGridCell(
                  alignment: Alignment.topLeft,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PROFILE', style: labelStyle),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: colorScheme.primary.withValues(
                          alpha: 0.08,
                        ),
                        child: Text(
                          _getInitials(user?.username ?? 'U'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _HermesGridCell(
                alignment: Alignment.topLeft,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('THEME', style: labelStyle),
                    Container(
                      width: 44,
                      height: 24,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HermesFooterNavigation extends StatelessWidget {
  const _HermesFooterNavigation({
    required this.navigationTabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<dynamic> navigationTabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
          left: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: SizedBox(
        height: 64,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < navigationTabs.length; i++)
              Expanded(
                child: _HermesCellButton(
                  onTap: () => onSelected(i),
                  selected: i == selectedIndex,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        i == selectedIndex
                            ? navigationTabs[i].selectedIcon
                            : navigationTabs[i].icon,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          navigationTabs[i].label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HermesGridCell extends StatelessWidget {
  const _HermesGridCell({
    required this.child,
    this.alignment = Alignment.center,
    this.selected = false,
  });

  final Widget child;
  final AlignmentGeometry alignment;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        border: Border(
          right: BorderSide(color: colorScheme.outlineVariant),
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: alignment,
          child: DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.primary.withValues(alpha: 0.72),
            ),
            child: IconTheme.merge(
              data: IconThemeData(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.primary.withValues(alpha: 0.72),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _HermesCellButton extends StatelessWidget {
  const _HermesCellButton({
    required this.child,
    required this.onTap,
    this.alignment = Alignment.center,
    this.selected = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final AlignmentGeometry alignment;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.05),
        splashColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.08),
        child: _HermesGridCell(
          alignment: alignment,
          selected: selected,
          child: child,
        ),
      ),
    );
  }
}

class _AiroShellBackdrop extends StatelessWidget {
  const _AiroShellBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AiroThemeTokens>();
    if (tokens == null) {
      return child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        Image.asset(
          'assets/hermes/images/filler-bg0.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.topLeft,
          opacity: const AlwaysStoppedAnimation(0.2),
          color: Theme.of(context).scaffoldBackgroundColor,
          colorBlendMode: BlendMode.multiply,
        ),
        CustomPaint(painter: _AiroGridPainter(tokens.gridLine)),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.4,
                colors: [
                  Colors.transparent,
                  tokens.glow.withValues(alpha: 0.22),
                ],
                stops: const [0.58, 1],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AiroGridPainter extends CustomPainter {
  const _AiroGridPainter(this.gridLine);

  final Color gridLine;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridLine
      ..strokeWidth = 1;

    const spacing = 32.0;
    for (var x = 0.0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final noisePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.015)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 7) {
      final y = (x * 13) % size.height;
      canvas.drawPoints(PointMode.points, [Offset(x, y)], noisePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AiroGridPainter oldDelegate) {
    return oldDelegate.gridLine != gridLine;
  }
}

/// Context-aware mini players that hide on their owning media tabs.
class _ContextAwareMiniPlayers extends ConsumerWidget {
  final int currentIndex;
  final Widget child;

  const _ContextAwareMiniPlayers({
    required this.currentIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibility = ref.watch(miniPlayerVisibilityProvider(currentIndex));

    return Column(
      children: [
        Expanded(child: child),
        if (visibility.showMusicPlayer) const MiniPlayer(),
        if (visibility.showIptvPlayer) const IPTVMiniPlayer(),
      ],
    );
  }
}
