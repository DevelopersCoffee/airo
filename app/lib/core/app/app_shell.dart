import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_service.dart';
import '../auth/google_auth_service.dart';
import '../providers/bedtime_mode_provider.dart';
import '../providers/navigation_provider.dart';
import '../routing/route_names.dart';
import '../theme/bedtime_theme.dart';
import 'app_shell_chrome.dart';
import '../../features/music/presentation/widgets/mini_player.dart';
import '../../features/iptv/presentation/widgets/iptv_mini_player.dart';
import '../../features/iptv/application/providers/iptv_providers.dart'
    hide currentNavigationTabProvider;

/// App shell with bottom navigation for the six primary feature tabs.
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

    // In fullscreen mode, return just the navigation shell content without app bar or bottom nav
    if (isFullscreen) {
      return Theme(
        data: isBedtimeMode ? BedtimeTheme.bedtimeTheme : Theme.of(context),
        child: Scaffold(body: navigationShell),
      );
    }

    final navigationTabs = ref.watch(appNavigationTabsProvider);
    final chromeConfig = ref.watch(appNavigationChromeConfigProvider);
    final headerMode = ref.watch(appShellHeaderModeProvider(currentLocation));
    final currentPageName = navigationTabs[navigationShell.currentIndex].label;

    return Theme(
      data: isBedtimeMode ? BedtimeTheme.bedtimeTheme : Theme.of(context),
      child: Scaffold(
        appBar: headerMode == AppShellHeaderMode.shell
            ? AppShellChrome(
                title: Text(currentPageName),
                user: user,
                config: chromeConfig,
                onHomeTap: () {
                  ref.read(currentNavigationTabProvider.notifier).state = 0;
                  navigationShell.goBranch(0);
                },
                onNotificationsTap: () => context.push('/mind/notifications'),
                onProfileTap: () => context.push('/mind/profile'),
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
        body: _ContextAwareMiniPlayers(
          currentIndex: navigationShell.currentIndex,
          child: navigationShell,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            // Reset fullscreen mode and orientation when changing tabs
            if (ref.read(isFullscreenModeProvider)) {
              ref.read(isFullscreenModeProvider.notifier).state = false;
              // Restore normal UI and portrait orientation
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
              ]);
            }
            // Update the navigation tab provider for mini player visibility
            ref.read(currentNavigationTabProvider.notifier).state = index;
            navigationShell.goBranch(index);
          },
          destinations: [
            for (final tab in navigationTabs)
              NavigationDestination(
                key: ValueKey('app_nav_${tab.name}'),
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.selectedIcon),
                label: tab.label,
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
