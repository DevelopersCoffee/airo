import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_service.dart';
import '../auth/google_auth_service.dart';
import '../providers/bedtime_mode_provider.dart';
import '../routing/route_names.dart';
import '../theme/bedtime_theme.dart';
import '../../features/music/presentation/widgets/mini_player.dart';
import '../../features/iptv/presentation/widgets/iptv_mini_player.dart';
import '../../features/iptv/application/providers/iptv_providers.dart';
import '../../features/live/presentation/screens/live_screen.dart';

/// Get initials from a name (e.g., "Uday Chauhan" -> "UC", "Uday" -> "U")
String _getInitials(String name) {
  final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'U';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

/// App shell with bottom navigation for 5 feature tabs (Live combines Music & TV)
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

    // Get current page name based on navigation index
    final pageNames = ['Coins', 'Mind', 'Live', 'Arena', 'Tales'];
    final currentPageName = pageNames[navigationShell.currentIndex];

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
                errorBuilder: (_, __, ___) => const Icon(Icons.home),
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
                          errorBuilder: (_, __, ___) => Text(
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
            NavigationDestination(
              icon: Image.asset(
                'assets/airo_icon.png',
                width: 24,
                height: 24,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Image.asset(
                'assets/airo_icon.png',
                width: 24,
                height: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'Coins',
            ),
            const NavigationDestination(
              icon: Icon(Icons.smart_toy),
              selectedIcon: Icon(Icons.smart_toy),
              label: 'Mind',
            ),
            const NavigationDestination(
              icon: Icon(Icons.play_circle),
              selectedIcon: Icon(Icons.play_circle_filled),
              label: 'Live',
            ),
            const NavigationDestination(
              icon: Icon(Icons.sports_esports),
              selectedIcon: Icon(Icons.sports_esports),
              label: 'Arena',
            ),
            const NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Tales',
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

/// Context-aware mini players that show based on current mode
/// - Music mini player: Shows when NOT on Live tab in TV mode
/// - IPTV mini player: Shows when NOT on Live tab in Music mode
class _ContextAwareMiniPlayers extends ConsumerWidget {
  final int currentIndex;
  final Widget child;

  const _ContextAwareMiniPlayers({
    required this.currentIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveMode = ref.watch(liveModeProvider);
    final isOnLiveTab = currentIndex == 2; // Live tab is at index 2

    return Column(
      children: [
        Expanded(child: child),
        // Show music mini player only when:
        // - Not on Live tab, OR
        // - On Live tab but in TV mode (so music plays in background)
        if (!isOnLiveTab || liveMode == LiveMode.tv) const MiniPlayer(),
        // Show IPTV mini player only when:
        // - Not on Live tab, OR
        // - On Live tab but in Music mode (so TV plays in background)
        if (!isOnLiveTab || liveMode == LiveMode.music) const IPTVMiniPlayer(),
      ],
    );
  }
}
