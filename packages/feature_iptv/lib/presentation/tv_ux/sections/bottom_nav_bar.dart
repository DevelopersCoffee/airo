import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Phone explorer destinations shown in [IptvBottomNavBar].
/// Search lives on the filter toolbar; My Aika stays a sheet, not a tab.
enum IptvPhoneNavDestination { home, browse, favorites }

/// Phone/tablet-only floating bottom nav — replaces the hamburger drawer
/// and AppBar icon row. Styled as a premium floating pill, not the flat
/// Material default (there is no existing shared nav component to defer
/// to — verified `AdaptiveNavigation` does not exist in this repo).
class IptvBottomNavBar extends StatelessWidget {
  const IptvBottomNavBar({
    super.key,
    required this.selected,
    required this.onHome,
    required this.onBrowse,
    required this.onFavorites,
    required this.onMyAika,
  });

  final IptvPhoneNavDestination selected;
  final VoidCallback onHome;
  final VoidCallback onBrowse;
  final VoidCallback onFavorites;
  final VoidCallback onMyAika;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF020419).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Destination(
              icon: selected == IptvPhoneNavDestination.home
                  ? Icons.home
                  : Icons.home_outlined,
              label: 'Home',
              selected: selected == IptvPhoneNavDestination.home,
              onTap: onHome,
            ),
            _Destination(
              icon: selected == IptvPhoneNavDestination.browse
                  ? Icons.explore
                  : Icons.explore_outlined,
              label: 'Browse',
              selected: selected == IptvPhoneNavDestination.browse,
              onTap: onBrowse,
            ),
            _Destination(
              icon: selected == IptvPhoneNavDestination.favorites
                  ? Icons.favorite
                  : Icons.favorite_border,
              label: 'Fav',
              selected: selected == IptvPhoneNavDestination.favorites,
              onTap: onFavorites,
            ),
            _Destination(
              icon: Icons.auto_awesome_outlined,
              label: 'My Aika',
              onTap: onMyAika,
            ),
          ],
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
    );
  }
}
