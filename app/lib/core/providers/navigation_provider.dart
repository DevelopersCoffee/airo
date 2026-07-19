import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../routing/route_names.dart';

/// NOTE (CV unified-browse Task 5): the first six members below (`coins`
/// through `quest`) are the pre-existing super-app domains and are
/// UNCHANGED — same labels (`stream`'s rename to `live` aside), same paths,
/// same ordinal position, so every existing branch in `app_router.dart` and
/// every index-based reference (`AppNavigationTab.beats.index`, etc.) keeps
/// working exactly as before.
///
/// `home`, `guide`, `favorites`, and `settings` are new: they back the
/// 5-destination phone bottom nav that mirrors the TV sidebar
/// (`tv_shell.dart`) — see `appNavigationPolicy.compactPrimaryTabs` below.
/// `home` is a placeholder that reuses the existing Mind/agent screen until
/// a later task (unified-browse Task 6, "Mobile BrowseScreen with rails")
/// delivers the real rail-based Home; see task-5-report.md for the full
/// route-name decision log.
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
  ),
  guide(
    label: 'Guide',
    path: '/guide',
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view,
  ),
  favorites(
    label: 'Favorites',
    path: '/favorites',
    icon: Icons.favorite_border,
    selectedIcon: Icons.favorite,
  ),
  settings(
    label: 'Settings',
    path: RouteNames.settings,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
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
/// Home | Guide | Favorites | Settings
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

/// Phone bottom nav: exactly 5 destinations, matching the TV sidebar
/// (`tv_shell.dart`) one-for-one — Home, Live, Guide, Favorites, Settings.
/// All 5 fit persistently, so no overflow is needed on phone.
///
/// Wide (tablet/desktop) layouts get a *different* curated set, not the
/// full ten-tab list: the original six super-app domains (Coins, Mind,
/// Beats, Live, Arena, Quest) plus the two new IPTV-adjacent destinations
/// worth persistent nav real estate on larger screens (Guide, Favorites).
/// `home` is deliberately left out here — it's a phone-only placeholder for
/// the unified browse entry point (see the enum doc above), and `mind`
/// already covers that ground on wide layouts, so including both reads as
/// a confusing duplicate. `settings` is left out too, matching the
/// pre-unified-browse convention: it has never had a persistent nav slot
/// and stays reachable via the profile menu (`AppShell.onProfileTap` ->
/// `ProfileScreen`'s "Settings" entry) regardless of screen width.
const appNavigationPolicy = AppNavigationPolicy(
  compactPrimaryTabs: [
    AppNavigationTab.home,
    AppNavigationTab.live,
    AppNavigationTab.guide,
    AppNavigationTab.favorites,
    AppNavigationTab.settings,
  ],
  widePrimaryTabs: [
    AppNavigationTab.coins,
    AppNavigationTab.mind,
    AppNavigationTab.beats,
    AppNavigationTab.live,
    AppNavigationTab.arena,
    AppNavigationTab.quest,
    AppNavigationTab.guide,
    AppNavigationTab.favorites,
  ],
  overflowTabs: [],
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
