import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_service.dart';
import '../auth/google_auth_service.dart';
import '../providers/bedtime_mode_provider.dart';
import '../routing/route_names.dart';
import '../theme/bedtime_theme.dart';
import '../../features/music/presentation/widgets/mini_player.dart';
import '../../features/quest/presentation/widgets/device_compatibility_banner.dart';

/// Get initials from a name (e.g., "Uday Chauhan" -> "UC", "Uday" -> "U")
String _getInitials(String name) {
  final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'U';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

/// App shell with bottom navigation for 6 feature tabs
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBedtimeMode = ref.watch(bedtimeModeProvider);
    final sleepTimer = ref.watch(sleepTimerProvider);
    final user = AuthService.instance.currentUser;

    return Theme(
      data: isBedtimeMode ? BedtimeTheme.bedtimeTheme : Theme.of(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Airo'),
          actions: [
            // User menu with logout
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
          ],
        ),
        body: DeviceCompatibilityBanner(
          showBanner:
              navigationShell.currentIndex == 1, // Show only on Quest tab
          child: Column(
            children: [
              Expanded(child: navigationShell),
              const MiniPlayer(),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: navigationShell.goBranch,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Coins',
            ),
            NavigationDestination(
              icon: Icon(Icons.smart_toy_outlined),
              selectedIcon: Icon(Icons.smart_toy),
              label: 'Quest',
            ),
            NavigationDestination(
              icon: Icon(Icons.music_note_outlined),
              selectedIcon: Icon(Icons.music_note),
              label: 'Beats',
            ),
            NavigationDestination(
              icon: Icon(Icons.sports_esports_outlined),
              selectedIcon: Icon(Icons.sports_esports),
              label: 'Arena',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_offer_outlined),
              selectedIcon: Icon(Icons.local_offer),
              label: 'Loot',
            ),
            NavigationDestination(
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
