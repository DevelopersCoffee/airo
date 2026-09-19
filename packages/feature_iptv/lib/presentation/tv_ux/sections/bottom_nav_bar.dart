import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Phone explorer destinations shown in [IptvBottomNavBar].
/// Search and My Aika are sheets; Home is the library.
enum IptvPhoneNavDestination { home, search, myAika }

/// Height of the floating pill itself, excluding the home-indicator inset.
/// Phone lists add this plus [MediaQuery.padding.bottom] as *scroll*
/// clearance so the last tile can move above the bar without reserving a
/// blank slab in the layout.
const kIptvPhoneFloatingNavExtent = 64.0;

/// Phone/tablet-only floating pill. Overlay it in a [Stack] — never in
/// [Scaffold.bottomNavigationBar], which reserves a full-width black slab
/// around the pill.
class IptvBottomNavBar extends StatelessWidget {
  const IptvBottomNavBar({
    super.key,
    required this.onHome,
    required this.onSearch,
    required this.onMyAika,
    this.selected = IptvPhoneNavDestination.home,
  });

  final VoidCallback onHome;
  final VoidCallback onSearch;
  final VoidCallback onMyAika;
  final IptvPhoneNavDestination selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF020419).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Destination(
                  key: const ValueKey('iptv-phone-nav-home'),
                  icon: selected == IptvPhoneNavDestination.home
                      ? Icons.home
                      : Icons.home_outlined,
                  label: 'Home',
                  selected: selected == IptvPhoneNavDestination.home,
                  onTap: onHome,
                ),
                _Destination(
                  key: const ValueKey('iptv-phone-nav-search'),
                  icon: selected == IptvPhoneNavDestination.search
                      ? Icons.search
                      : Icons.search_outlined,
                  label: 'Search',
                  selected: selected == IptvPhoneNavDestination.search,
                  onTap: onSearch,
                ),
                _Destination(
                  key: const ValueKey('iptv-my-aika'),
                  icon: Icons.auto_awesome_outlined,
                  label: 'My Aika',
                  selected: selected == IptvPhoneNavDestination.myAika,
                  onTap: onMyAika,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Colors.white;
    return TvFocusable(
      semanticLabel: label,
      onSelect: onTap,
      borderRadius: 20,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
