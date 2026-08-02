import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// NOTE (CV unified-browse Task 5): the first six members below (`coins`
/// through `quest`) are the pre-existing super-app domains and are
/// UNCHANGED — same labels (`stream`'s rename to `live` aside), same paths,
/// same ordinal position, so every existing branch in `app_router.dart` and
/// every index-based reference (`AppNavigationTab.beats.index`, etc.) keeps
/// working exactly as before.
///
/// `home` is new: it backs the phone bottom nav that mirrors the TV sidebar
/// (`tv_shell.dart`) — see `appNavigationPolicy.compactPrimaryTabs` below.
/// Guide, Favorites, and Settings are IPTV-internal / profile-reachable only
/// (see `IptvNavigationDrawer` and `ProfileScreen`'s Settings entry) — they
/// are not top-level nav destinations.
/// `home` renders the same IPTVScreen as `live` (unified-browse Task 6):
/// the source design's sidebar calls the identical `goToBrowse` handler for
/// its Home and Live TV items, so they're the same destination here too;
/// see task-5-report.md and task-6-report.md for the full route-name
/// decision log.
enum AppNavigationTab {
  coins(
    label: 'Coins',
    path: '/money',
    icon: Icons.monetization_on_outlined,
    selectedIcon: Icons.monetization_on,
  ),
  assistant(
    label: 'Assistant',
    path: '/assistant',
    icon: Icons.psychology_outlined,
    selectedIcon: Icons.psychology,
  ),
  beats(
    label: 'Beats',
    path: '/music',
    icon: Icons.subscriptions_outlined,
    selectedIcon: Icons.subscriptions,
  ),
  live(
    label: 'Live',
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
  ),
  home(
    label: 'Home',
    path: '/home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
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
/// Declaration/branch order: Coins | Mind | Beats | Live | Arena | Quest |
/// Home
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
    required this.widePrimaryTabs,
    required this.overflowTabs,
    this.compactWidthBreakpoint = 600,
    this.overflow = const AppNavigationOverflowConfig(),
  });

  final List<AppNavigationTab> compactPrimaryTabs;
  final List<AppNavigationTab> widePrimaryTabs;
  final List<AppNavigationTab> overflowTabs;
  final double compactWidthBreakpoint;
  final AppNavigationOverflowConfig overflow;

  AppNavigationLayoutConfig layoutForWidth(double width) {
    if (width >= compactWidthBreakpoint) {
      return AppNavigationLayoutConfig(
        persistentTabs: widePrimaryTabs,
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

/// Phone bottom nav keeps Airo's four primary super-app domains visible and
/// exposes every remaining branch through a shared overflow destination.
/// Airo TV owns its separate navigation policy in `tv_shell.dart`.
///
/// Wide (tablet/desktop) layouts get a *different* curated set, not the
/// full seven-tab list: just the six super-app domains (Coins, Mind, Beats,
/// Live, Arena, Quest). `home` is deliberately left out here — it's a
/// phone-only placeholder for the unified browse entry point (see the enum
/// doc above), and `mind` already covers that ground on wide layouts, so
/// including both reads as a confusing duplicate. Guide, Favorites, and
/// Settings are never top-level tabs on any width: Guide/Favorites live
/// inside the IPTV section's own drawer (`IptvNavigationDrawer`), and
/// Settings stays reachable via the profile menu (`AppShell.onProfileTap`
/// -> `ProfileScreen`'s "Settings" entry).
const appNavigationPolicy = AppNavigationPolicy(
  compactPrimaryTabs: [
    AppNavigationTab.coins,
    AppNavigationTab.assistant,
    AppNavigationTab.beats,
    AppNavigationTab.live,
  ],
  widePrimaryTabs: [
    AppNavigationTab.coins,
    AppNavigationTab.assistant,
    AppNavigationTab.beats,
    AppNavigationTab.live,
    AppNavigationTab.arena,
    AppNavigationTab.quest,
  ],
  overflowTabs: [
    AppNavigationTab.arena,
    AppNavigationTab.quest,
    AppNavigationTab.home,
  ],
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
    // The legacy dashboard alias renders the same Coins root content. Keep
    // both entry points under the super-app header so Coins gets the single
    // global notification action instead of owning duplicate local chrome.
    '/money/dashboard',
    '/assistant',
    '/assistant/chat',
    '/assistant/models',
    '/games',
    '/home',
  };
  if (shellOwnedExactLocations.contains(normalizedLocation)) {
    return AppShellHeaderMode.shell;
  }

  const routeOwnedPrefixes = [
    '/money/',
    '/assistant/',
    '/music',
    '/iptv',
    '/games/',
    '/quest',
    // SettingsHubScreen renders its own Scaffold + AppBar (see
    // settings_hub_screen.dart) — shell chrome must stay hidden here or the
    // "Settings" title renders twice.
    '/settings',
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
      showIptvPlayer: currentIndex == AppNavigationTab.live.index,
    );
  },
);
