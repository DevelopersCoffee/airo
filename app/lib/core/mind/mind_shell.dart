import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The Airo Mind shell's navigation chrome.
///
/// Destinations: Scribe, Assistant, Intelligence, Wellbeing. Layout follows
/// width: a [NavigationRail] at [railBreakpoint] and a [NavigationBar] below.
class MindShell extends StatelessWidget {
  const MindShell({required this.navigationShell, super.key});

  /// Width at which the shell switches from a bottom bar to a left rail.
  static const double railBreakpoint = 900;

  /// The branch stack built by `StatefulShellRoute.indexedStack`. Branch order
  /// is scribe, assistant, intelligence, wellbeing — the same order as
  /// [destinations].
  final StatefulNavigationShell navigationShell;

  /// The shell's destinations, in branch order.
  ///
  /// Public so a test can assert the nav surface without reaching into the
  /// widget tree for labels.
  static const List<MindDestination> destinations = <MindDestination>[
    MindDestination(
      label: 'Scribe',
      icon: Icons.mic_none_outlined,
      selectedIcon: Icons.mic,
    ),
    MindDestination(
      label: 'Assistant',
      icon: Icons.psychology_outlined,
      selectedIcon: Icons.psychology,
    ),
    MindDestination(
      label: 'Intelligence',
      icon: Icons.memory_outlined,
      selectedIcon: Icons.memory,
    ),
    MindDestination(
      label: 'Wellbeing',
      icon: Icons.self_improvement_outlined,
      selectedIcon: Icons.self_improvement,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= railBreakpoint;
    final destinations = [
      for (final destination in MindShell.destinations)
        NavigationDestination(
          key: ValueKey('mind_nav_${destination.label.toLowerCase()}'),
          icon: Icon(destination.icon),
          selectedIcon: Icon(destination.selectedIcon),
          label: destination.label,
        ),
    ];

    void onSelected(int index) => navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: onSelected,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final destination in MindShell.destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: onSelected,
        destinations: destinations,
      ),
    );
  }
}

/// One entry in the Airo Mind navigation.
@immutable
class MindDestination {
  const MindDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
