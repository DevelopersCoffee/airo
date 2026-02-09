import 'package:flutter/material.dart';
import 'responsive_center.dart';

/// Adaptive navigation that switches between bottom navigation bar (mobile)
/// and navigation rail (tablet/desktop) based on screen size
class AdaptiveNavigation extends StatelessWidget {
  const AdaptiveNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.child,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveNavigationDestination> destinations;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = ResponsiveBreakpoints.isDesktop(context);
        
        if (isDesktop) {
          // Desktop: Use NavigationRail
          return Row(
            children: [
              NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                labelType: NavigationRailLabelType.all,
                destinations: destinations
                    .map(
                      (dest) => NavigationRailDestination(
                        icon: dest.icon,
                        selectedIcon: dest.selectedIcon ?? dest.icon,
                        label: Text(dest.label),
                      ),
                    )
                    .toList(),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: child),
            ],
          );
        } else {
          // Mobile/Tablet: Use bottom NavigationBar
          return Scaffold(
            body: child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: destinations
                  .map(
                    (dest) => NavigationDestination(
                      icon: dest.icon,
                      selectedIcon: dest.selectedIcon ?? dest.icon,
                      label: dest.label,
                    ),
                  )
                  .toList(),
            ),
          );
        }
      },
    );
  }
}

/// Navigation destination for adaptive navigation
class AdaptiveNavigationDestination {
  const AdaptiveNavigationDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });

  final Widget icon;
  final Widget? selectedIcon;
  final String label;
}

