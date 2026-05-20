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
    path: '/agent',
    icon: Icons.smart_toy_outlined,
    selectedIcon: Icons.smart_toy,
  ),
  media(
    label: 'Media',
    path: '/media',
    icon: Icons.video_library_outlined,
    selectedIcon: Icons.video_library,
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
/// Order: Coins | Mind | Media | Arena | Quest
final currentNavigationTabProvider = StateProvider<int>(
  (ref) => AppNavigationTab.mind.index,
);

final appNavigationTabsProvider = Provider<List<AppNavigationTab>>(
  (ref) => AppNavigationTab.values,
);

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
    return const MiniPlayerVisibility(
      showMusicPlayer: false,
      showIptvPlayer: false,
    );
  },
);
