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
    final currentPageName = navigationTabs[navigationShell.currentIndex].label;

    return Theme(
      data: isBedtimeMode ? BedtimeTheme.bedtimeTheme : Theme.of(context),
      child: Scaffold(
        appBar: AppBar(
          // Airo logo/title on left - clickable to go to default page
          leading: InkWell(
            onTap: () {
              // Go to first tab (Coins) as default/home
              ref.read(currentNavigationTabProvider.notifier).state = 0;
              navigationShell.goBranch(0);
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 32,
                height: 32,
                errorBuilder: (_, _, _) => const Icon(Icons.home),
              ),
            ),
          ),
          // Current page name in center
          title: Text(currentPageName),
          centerTitle: true,
          actions: [
            // User profile avatar with menu
            PopupMenuButton<String>(
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: user?.photoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          user!.photoUrl!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Text(
                            _getInitials(user.username),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        _getInitials(user?.username ?? 'U'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
              ),
              onSelected: (value) async {
                if (value == 'logout') {
                  if (user?.isGoogleUser == true) {
                    await GoogleAuthService.instance.signOut();
                  }
                  await AuthService.instance.logout();
                  if (context.mounted) {
                    context.go(RouteNames.login);
                  }
                } else if (value == 'profile') {
                  context.push('/agent/profile');
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
                          color: Theme.of(context).colorScheme.primary,
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
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
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
