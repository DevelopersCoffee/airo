import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter/material.dart';

/// Canonical IPTV navigation destinations (SSOT).
///
/// Both the mobile hamburger drawer
/// (`presentation/widgets/iptv_navigation_drawer.dart`) and the Airo TV
/// sidebar rail (`app/lib/core/app/tv_shell.dart`) render from this single
/// list instead of each hardcoding its own destination set. See ADR-0011 and
/// `tasks/ssot_airo_airo_tv_architecture_blueprint.md` ("IPTV nav items").
///
/// This is a contract for *what* destinations exist, their order, icons, and
/// labels — not for *how* a shell renders them (drawer vs. rail, D-pad focus
/// vs. touch) or which destinations a given shell chooses to show (that
/// remains shell-specific wiring, driven by each shell's own callbacks and
/// visibility rules).
enum IptvDestinationId { home, guide, vod, favorites, settings }

/// One IPTV navigation destination, shared across shells.
///
/// [label] and [icon]/[selectedIcon] are the canonical values. A destination
/// may specify a small number of per-shell overrides
/// ([shellLabelOverrides]) where the shells have historically shown slightly
/// different copy for the same destination (for example the TV rail's
/// shorter "Movies" vs. the mobile drawer's "Movies & Shows") — this
/// preserves each shell's existing visible text while keeping one
/// authoritative destination list.
@immutable
class IptvNavigationDestination {
  const IptvNavigationDestination({
    required this.id,
    required this.label,
    required this.semanticLabel,
    required this.icon,
    required this.selectedIcon,
    this.shellLabelOverrides = const {},
  });

  final IptvDestinationId id;
  final String label;
  final String semanticLabel;
  final IconData icon;
  final IconData selectedIcon;
  final Map<ShellId, String> shellLabelOverrides;

  /// The label to render for [shell] — the override if one exists for that
  /// shell, otherwise the canonical [label].
  String labelFor(ShellId shell) => shellLabelOverrides[shell] ?? label;
}

/// The single source of truth for IPTV navigation destinations, in display
/// order: Home, Guide, Movies/VOD, Favorites, Settings.
///
/// Not `const`: [ShellId] overrides `==`/`hashCode` for value equality, and
/// Dart's const-evaluation only permits identity-based types as const
/// map/set keys — so the [IptvNavigationDestination.shellLabelOverrides]
/// entries below must be built at load time instead. The list is still a
/// `final` top-level constant in the ordinary sense: one instance, built
/// once, never mutated.
final List<IptvNavigationDestination> iptvNavigationDestinations = [
  IptvNavigationDestination(
    id: IptvDestinationId.home,
    label: 'Home',
    semanticLabel: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  IptvNavigationDestination(
    id: IptvDestinationId.guide,
    label: 'Guide',
    semanticLabel: 'TV Guide',
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view,
  ),
  IptvNavigationDestination(
    id: IptvDestinationId.vod,
    label: 'Movies & Shows',
    semanticLabel: 'Movies & Shows',
    icon: Icons.movie_outlined,
    selectedIcon: Icons.movie,
    shellLabelOverrides: {ShellId.tv: 'Movies'},
  ),
  IptvNavigationDestination(
    id: IptvDestinationId.favorites,
    label: 'Favorites',
    semanticLabel: 'Favorites',
    icon: Icons.favorite_border,
    selectedIcon: Icons.favorite,
  ),
  IptvNavigationDestination(
    id: IptvDestinationId.settings,
    label: 'Settings',
    semanticLabel: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
];
