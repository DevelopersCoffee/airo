import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The Airo Mind shell's navigation chrome.
///
/// The standalone shell mounts three destinations — the scribe at `/`, the
/// assistant hub at `/mind`, and Wellbeing at `/wellbeing` — but
/// `packages/feature_mind` does not link them to each other: the scribe's home
/// screen renders only the scribe journey, and the assistant hub links to
/// Wellbeing but never back to the recorder. Navigation between shell
/// destinations is a shell concern (issue #1555), so it lives here rather than
/// inside the package.
///
/// A [NavigationBar] fed by [StatefulNavigationShell], matching the super
/// app's `AppShell`: same Material 3 component, same outlined/filled icon
/// pairing, same `goBranch` semantics. Unlike `AppShell` there is no
/// width-dependent overflow policy — three destinations fit every layout — and
/// no shell app bar, because each destination screen ships its own.
class MindShell extends StatelessWidget {
  const MindShell({required this.navigationShell, super.key});

  /// The branch stack built by `StatefulShellRoute.indexedStack`. Branch order
  /// is scribe, assistant, wellbeing — the same order as [destinations].
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
      label: 'Wellbeing',
      icon: Icons.self_improvement_outlined,
      selectedIcon: Icons.self_improvement,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        // `initialLocation: true` only when re-tapping the current branch, so
        // tapping an already-selected tab pops back to its root instead of
        // being a no-op — go_router's documented reset gesture.
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              key: ValueKey('mind_nav_${destination.label.toLowerCase()}'),
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

/// One entry in the Airo Mind bottom navigation.
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
