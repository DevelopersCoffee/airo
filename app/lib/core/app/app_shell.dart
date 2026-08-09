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
import '../theme/airo_domain_resolver.dart';
import 'app_shell_chrome.dart';
import '../../features/music/presentation/widgets/mini_player.dart';
import 'package:feature_iptv/feature_iptv.dart';

/// Airo super-app shell with destinations that vary by layout width.
///
/// Compact layouts keep four primary domains visible and put all other Airo
/// branches behind More. Tablet/desktop shows a curated 8-destination set.
/// Airo TV uses its own shell and navigation policy.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.currentLocation,
  });

  final StatefulNavigationShell navigationShell;
  final String currentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBedtimeMode = ref.watch(bedtimeModeProvider);
    final sleepTimer = ref.watch(sleepTimerProvider);
    final isFullscreen = ref.watch(isFullscreenModeProvider);
    final user = AuthService.instance.currentUser;
    final domain = airoDomainForLocation(currentLocation);

    Widget applyShellTheme(Widget child) {
      final theme = isBedtimeMode
          ? BedtimeTheme.bedtimeTheme
          : Theme.of(context);
      return Theme(
        data: theme,
        child: isBedtimeMode
            ? child
            : AiroDomainTheme(domain: domain, child: child),
      );
    }

    // In fullscreen mode, return just the navigation shell content without app bar or bottom nav
    if (isFullscreen) {
      return applyShellTheme(
        Scaffold(body: AiroAmbientBackground(child: navigationShell)),
      );
    }

    final navigationTabs = ref.watch(appNavigationTabsProvider);
    final navigationPolicy = ref.watch(appNavigationPolicyProvider);
    final chromeConfig = ref.watch(appNavigationChromeConfigProvider);
    final headerMode = ref.watch(appShellHeaderModeProvider(currentLocation));
    final currentPageName = navigationTabs[navigationShell.currentIndex].label;
    final width = MediaQuery.sizeOf(context).width;
    final navigationLayout = navigationPolicy.layoutForWidth(width);
    final currentTab = navigationTabs[navigationShell.currentIndex];
    final selectedNavIndex = _selectedNavigationIndexForTab(
      currentTab,
      navigationLayout,
    );

    return applyShellTheme(
      Scaffold(
        appBar: headerMode == AppShellHeaderMode.shell
            ? AppShellChrome(
                title: Text(currentPageName),
                user: user,
                config: chromeConfig,
                onHomeTap: () {
                  ref.read(currentNavigationTabProvider.notifier).state =
                      AppNavigationTab.home.index;
                  navigationShell.goBranch(AppNavigationTab.home.index);
                },
                onNotificationsTap: () =>
                    context.push('/assistant/notifications'),
                onProfileTap: () => context.push('/assistant/profile'),
                onLogoutTap: () async {
                  if (user?.isGoogleUser == true) {
                    await GoogleAuthService.instance.signOut();
                  }
                  await AuthService.instance.logout();
                  if (context.mounted) {
                    context.go(RouteNames.login);
                  }
                },
              )
            : null,
        body: AiroAmbientBackground(
          child: _ContextAwareMiniPlayers(
            currentIndex: navigationShell.currentIndex,
            child: navigationShell,
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedNavIndex,
          onDestinationSelected: (index) {
            if (navigationLayout.usesOverflow &&
                index == navigationLayout.persistentTabs.length) {
              _showOverflowDestinations(
                context,
                ref,
                navigationShell,
                navigationLayout,
                navigationTabs,
              );
              return;
            }

            final selectedTab = navigationLayout.persistentTabs[index];
            _goToTab(ref, navigationShell, selectedTab.index);
          },
          destinations: [
            for (final tab in navigationLayout.persistentTabs)
              NavigationDestination(
                key: ValueKey('app_nav_${tab.name}'),
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.selectedIcon),
                label: tab.label,
              ),
            if (navigationLayout.usesOverflow)
              NavigationDestination(
                key: const ValueKey('app_nav_overflow'),
                icon: Icon(navigationLayout.overflow.icon),
                selectedIcon: Icon(navigationLayout.overflow.selectedIcon),
                label: navigationLayout.overflow.label,
              ),
          ],
        ),
        // Sleep timer overlay
        floatingActionButton: sleepTimer > 0
            ? FloatingActionButton.extended(
                onPressed: () {
                  ref.read(sleepTimerProvider.notifier).cancelSleepTimer();
                },
                label: Text('Sleep in $sleepTimer min'),
                icon: const Icon(Icons.timer),
              )
            : null,
      ),
    );
  }

  int _selectedNavigationIndexForTab(
    AppNavigationTab currentTab,
    AppNavigationLayoutConfig layout,
  ) {
    final directIndex = layout.persistentTabs.indexOf(currentTab);
    if (directIndex != -1) {
      return directIndex;
    }
    // Overflow destination sits right after persistentTabs — only valid when
    // the layout actually renders one. Wide layout has no overflow slot and
    // no Home destination, so a tab absent from persistentTabs there has no
    // representable selection; clamp to the first destination instead of
    // indexing past the end of NavigationBar's destinations list.
    return layout.usesOverflow ? layout.persistentTabs.length : 0;
  }

  Future<void> _showOverflowDestinations(
    BuildContext context,
    WidgetRef ref,
    StatefulNavigationShell navigationShell,
    AppNavigationLayoutConfig layout,
    List<AppNavigationTab> navigationTabs,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final currentTab = navigationTabs[navigationShell.currentIndex];

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final tab in layout.overflowTabs)
                ListTile(
                  key: ValueKey('app_nav_overflow_entry_${tab.name}'),
                  leading: Icon(tab.icon),
                  title: Text(tab.label),
                  selected: currentTab == tab,
                  onTap: () {
                    Navigator.of(context).pop();
                    _goToTab(ref, navigationShell, tab.index);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _goToTab(
    WidgetRef ref,
    StatefulNavigationShell navigationShell,
    int index,
  ) {
    // Reset fullscreen mode and orientation when changing tabs.
    if (ref.read(isFullscreenModeProvider)) {
      ref.read(isFullscreenModeProvider.notifier).state = false;
      restoreChromeAfterFullscreen();
    }

    ref.read(currentNavigationTabProvider.notifier).state = index;
    navigationShell.goBranch(index);
  }
}

/// Restores shell chrome after a fullscreen surface (player, game) is left.
///
/// Orientation goes back to the system default rather than forced portrait:
/// tablets and foldables already using landscape as their default layout must
/// not be rotated out of it. `packages/feature_iptv` restores the same way on
/// fullscreen exit, so both paths agree.
@visibleForTesting
void restoreChromeAfterFullscreen() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations(const []);
}

/// Context-aware mini players shown only on their owning media tabs.
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
