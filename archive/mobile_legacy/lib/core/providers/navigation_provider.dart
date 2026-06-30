import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppNavigationTab {
  coins(
    label: 'Coins',
    path: '/money',
    icon: Icons.monetization_on_outlined,
    selectedIcon: Icons.monetization_on,
  ),
  mind(
    label: 'Mind',
    path: '/mind',
    icon: Icons.psychology_outlined,
    selectedIcon: Icons.psychology,
  ),
  beats(
    label: 'Beats',
    path: '/music',
    icon: Icons.subscriptions_outlined,
    selectedIcon: Icons.subscriptions,
  ),
  stream(
    label: 'Stream',
    path: '/iptv',
    icon: Icons.live_tv_outlined,
    selectedIcon: Icons.live_tv,
  ),
  arena(
    label: 'Arena',
    path: '/games',
    icon: Icons.sports_esports_outlined,
    selectedIcon: Icons.sports_esports,
  ),
  quest(
    label: 'Quest',
    path: '/quest',
    icon: Icons.workspace_premium_outlined,
    selectedIcon: Icons.workspace_premium,
  );

  const AppNavigationTab({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

/// Current navigation tab index.
///
/// Order: Coins | Mind | Beats | Stream | Arena | Quest
final currentNavigationTabProvider = StateProvider<int>(
  (ref) => AppNavigationTab.coins.index,
);

final appNavigationTabsProvider = Provider<List<AppNavigationTab>>(
  (ref) => AppNavigationTab.values,
);

class AppNavigationOverflowConfig {
  const AppNavigationOverflowConfig({
    this.label = 'More',
    this.icon = Icons.menu,
    this.selectedIcon = Icons.menu_open,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class AppNavigationLayoutConfig {
  const AppNavigationLayoutConfig({
    required this.persistentTabs,
    required this.overflowTabs,
    required this.overflow,
  });

  final List<AppNavigationTab> persistentTabs;
  final List<AppNavigationTab> overflowTabs;
  final AppNavigationOverflowConfig overflow;

  bool get usesOverflow => overflowTabs.isNotEmpty;
}

class AppNavigationPolicy {
  const AppNavigationPolicy({
    required this.compactPrimaryTabs,
    required this.overflowTabs,
    this.compactWidthBreakpoint = 600,
    this.overflow = const AppNavigationOverflowConfig(),
  });

  final List<AppNavigationTab> compactPrimaryTabs;
  final List<AppNavigationTab> overflowTabs;
  final double compactWidthBreakpoint;
  final AppNavigationOverflowConfig overflow;

  AppNavigationLayoutConfig layoutForWidth(double width) {
    if (width >= compactWidthBreakpoint) {
      return AppNavigationLayoutConfig(
        persistentTabs: AppNavigationTab.values,
        overflowTabs: const [],
        overflow: overflow,
      );
    }

    return AppNavigationLayoutConfig(
      persistentTabs: compactPrimaryTabs,
      overflowTabs: overflowTabs,
      overflow: overflow,
    );
  }
}

const appNavigationPolicy = AppNavigationPolicy(
  compactPrimaryTabs: [
    AppNavigationTab.coins,
    AppNavigationTab.mind,
    AppNavigationTab.beats,
    AppNavigationTab.stream,
  ],
  overflowTabs: [AppNavigationTab.arena, AppNavigationTab.quest],
);

final appNavigationPolicyProvider = Provider<AppNavigationPolicy>(
  (ref) => appNavigationPolicy,
);

enum AppShellAction { notifications, profileMenu }

class AppNavigationChromeConfig {
  const AppNavigationChromeConfig({
    required this.enabledActions,
    this.compactWidthBreakpoint = 600,
  });

  final List<AppShellAction> enabledActions;
  final double compactWidthBreakpoint;
}

final appNavigationChromeConfigProvider = Provider<AppNavigationChromeConfig>(
  (ref) => const AppNavigationChromeConfig(
    enabledActions: [AppShellAction.notifications, AppShellAction.profileMenu],
  ),
);

enum AppShellHeaderMode { shell, route }

AppShellHeaderMode appShellHeaderModeForLocation(String location) {
  final normalizedLocation = Uri.parse(location).path;

  const shellOwnedExactLocations = {
    '/money',
    '/mind',
    '/mind/chat',
    '/mind/models',
    '/games',
  };
  if (shellOwnedExactLocations.contains(normalizedLocation)) {
    return AppShellHeaderMode.shell;
  }

  const routeOwnedPrefixes = [
    '/money/',
    '/mind/',
    '/music',
    '/iptv',
    '/games/',
    '/quest',
  ];
  for (final prefix in routeOwnedPrefixes) {
    if (normalizedLocation == prefix || normalizedLocation.startsWith(prefix)) {
      return AppShellHeaderMode.route;
    }
  }

  return AppShellHeaderMode.shell;
}

final appShellHeaderModeProvider = Provider.family<AppShellHeaderMode, String>((
  ref,
  location,
) {
  return appShellHeaderModeForLocation(location);
});

class MiniPlayerVisibility {
  const MiniPlayerVisibility({
    required this.showMusicPlayer,
    required this.showIptvPlayer,
  });

  final bool showMusicPlayer;
  final bool showIptvPlayer;
}

final miniPlayerVisibilityProvider = Provider.family<MiniPlayerVisibility, int>(
  (ref, currentIndex) {
    return MiniPlayerVisibility(
      showMusicPlayer: currentIndex == AppNavigationTab.beats.index,
      showIptvPlayer: currentIndex == AppNavigationTab.stream.index,
    );
  },
);
