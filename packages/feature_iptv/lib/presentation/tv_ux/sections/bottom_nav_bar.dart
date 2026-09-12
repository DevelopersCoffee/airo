import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Phone/tablet-only floating bottom nav — replaces the hamburger drawer
/// and AppBar icon row. Styled as a premium floating pill, not the flat
/// Material default (there is no existing shared nav component to defer
/// to — verified `AdaptiveNavigation` does not exist in this repo).
class IptvBottomNavBar extends StatelessWidget {
  const IptvBottomNavBar({
    super.key,
    required this.onHome,
    required this.onSearch,
    required this.onMyAika,
  });

  final VoidCallback onHome;
  final VoidCallback onSearch;
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
              icon: Icons.home_outlined,
              label: 'Home',
              onTap: onHome,
            ),
            _Destination(icon: Icons.search, label: 'Search', onTap: onSearch),
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      semanticLabel: label,
      onSelect: onTap,
      borderRadius: 20,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
