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
  beats(
    label: 'Beats',
    path: '/beats',
    icon: Icons.music_note_outlined,
    selectedIcon: Icons.music_note,
  ),
  stream(
    label: 'Stream',
    path: '/stream',
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
  (ref) => AppNavigationTab.mind.index,
);

final appNavigationTabsProvider = Provider<List<AppNavigationTab>>(
  (ref) => AppNavigationTab.values,
);
