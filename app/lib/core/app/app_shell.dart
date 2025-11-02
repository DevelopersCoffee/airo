import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/bedtime_mode_provider.dart';
import '../theme/bedtime_theme.dart';
import '../../features/music/presentation/widgets/mini_player.dart';
import '../../features/quest/presentation/widgets/device_compatibility_banner.dart';

/// App shell with bottom navigation for 6 feature tabs
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBedtimeMode = ref.watch(bedtimeModeProvider);
    final sleepTimer = ref.watch(sleepTimerProvider);

    return Theme(
      data: isBedtimeMode ? BedtimeTheme.bedtimeTheme : Theme.of(context),
      child: Scaffold(
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
