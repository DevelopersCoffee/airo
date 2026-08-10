import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter/material.dart';

/// Canonical IPTV settings-section descriptors (SSOT).
///
/// The mobile settings hub
/// (`app/lib/features/settings/presentation/screens/settings_hub_screen.dart`)
/// and the Airo TV settings screen
/// (`app/lib/features/settings/presentation/tv/tv_settings_screen.dart`) both
/// resolve their section labels/icons/visibility from this one list instead
/// of each hardcoding its own. See ADR-0011 and
/// `tasks/ssot_airo_airo_tv_architecture_blueprint.md` ("IPTV settings
/// sections").
///
/// This intentionally mirrors today's real composition, not an idealized
/// one: mobile currently exposes `playlistSource` and `epgGuideSource` as two
/// separate entries, while TV exposes one combined `sources` entry; mobile
/// exposes `country` and `audio`, which TV does not yet expose at all; TV
/// exposes an `accessibility` stub, which mobile does not yet show. Declaring
/// each of those as its own descriptor with an explicit
/// [IptvSettingsSectionDescriptor.visibleForShells] set records the real gaps
/// from `tasks/ssot_airo_airo_tv_gap_analysis.md` as data, so a future pass
/// can close them by editing `visibleForShells` in one place — without
/// forcing identical UI today.
enum IptvSettingsSectionId {
  theme,
  playback,
  sources,
  playlistSource,
  epgGuideSource,
  country,
  audio,
  accessibility,
  privacy,
}

/// One IPTV settings-section descriptor, shared across shells.
///
/// [shellLabelOverrides]/[shellIconOverrides] preserve each shell's existing
/// visible copy/iconography where it has historically diverged (for example
/// mobile's "Appearance" header vs. TV's "Theme" rail entry for the same
/// section) while keeping one authoritative descriptor list.
@immutable
class IptvSettingsSectionDescriptor {
  const IptvSettingsSectionDescriptor({
    required this.id,
    required this.label,
    required this.icon,
    required this.visibleForShells,
    this.shellLabelOverrides = const {},
    this.shellIconOverrides = const {},
  });

  final IptvSettingsSectionId id;
  final String label;
  final IconData icon;
  final Set<ShellId> visibleForShells;
  final Map<ShellId, String> shellLabelOverrides;
  final Map<ShellId, IconData> shellIconOverrides;

  /// Whether this section should be shown on [shell].
  bool isVisibleFor(ShellId shell) => visibleForShells.contains(shell);

  /// The label to render for [shell].
  String labelFor(ShellId shell) => shellLabelOverrides[shell] ?? label;

  /// The icon to render for [shell].
  IconData iconFor(ShellId shell) => shellIconOverrides[shell] ?? icon;
}

/// The single source of truth for IPTV settings sections.
///
/// Not `const` — see the equivalent note on `iptvNavigationDestinations` in
/// `iptv_navigation_manifest.dart`: [ShellId]'s value-equality `==` means its
/// use as a set/map key can't be const-evaluated, so this list is built once
/// at load time instead.
final List<IptvSettingsSectionDescriptor> iptvSettingsSections = [
  IptvSettingsSectionDescriptor(
    id: IptvSettingsSectionId.theme,
    label: 'Appearance',
    icon: Icons.palette_outlined,
    visibleForShells: {ShellId.mobile, ShellId.tv},
    shellLabelOverrides: {ShellId.tv: 'Theme'},
  ),
  IptvSettingsSectionDescriptor(
    id: IptvSettingsSectionId.playback,
    label: 'Playback',
    icon: Icons.play_circle_outline,
    visibleForShells: {ShellId.mobile, ShellId.tv},
    shellLabelOverrides: {ShellId.mobile: 'Playback Settings'},
    shellIconOverrides: {ShellId.mobile: Icons.aspect_ratio},
  ),
  IptvSettingsSectionDescriptor(
    id: IptvSettingsSectionId.sources,
    label: 'Sources',
    icon: Icons.dns_outlined,
    visibleForShells: {ShellId.tv},
  ),
  IptvSettingsSectionDescriptor(
    id: IptvSettingsSectionId.playlistSource,
    label: 'Playlist Source',
    icon: Icons.dns_outlined,
    visibleForShells: {ShellId.mobile},
  ),
  IptvSettingsSectionDescriptor(
    id: IptvSettingsSectionId.epgGuideSource,
    label: 'EPG Guide Source',
    icon: Icons.calendar_month_outlined,
    visibleForShells: {ShellId.mobile},
  ),
  IptvSettingsSectionDescriptor(
    id: IptvSettingsSectionId.country,
    label: 'Country',
    icon: Icons.flag_outlined,
    visibleForShells: {ShellId.mobile},
  ),
  IptvSettingsSectionDescriptor(
    id: IptvSettingsSectionId.audio,
    label: 'Audio Settings',
    icon: Icons.settings_voice,
    visibleForShells: {ShellId.mobile},
  ),
  IptvSettingsSectionDescriptor(
    id: IptvSettingsSectionId.accessibility,
    label: 'Accessibility',
    icon: Icons.accessibility_new_outlined,
    visibleForShells: {ShellId.tv},
  ),
  // Phase 1 streaming telemetry consent (F7.5, tv-zero-copy-cast-phase1
  // Task 7). TV-only for now: only main_tv.dart bootstraps
  // AppLogger.setAnalyticsService today, so a mobile toggle would
  // persist a preference with no live service to apply it to. Widen
  // visibleForShells once the phone entrypoint gets the same bootstrap.
  IptvSettingsSectionDescriptor(
    id: IptvSettingsSectionId.privacy,
    label: 'Privacy',
    icon: Icons.privacy_tip_outlined,
    visibleForShells: {ShellId.tv},
  ),
];
