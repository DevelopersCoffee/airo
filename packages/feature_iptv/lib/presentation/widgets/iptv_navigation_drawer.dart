import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter/material.dart';

import '../../domain/iptv_navigation_manifest.dart';

/// Mobile hamburger-menu drawer for the IPTV screen, rendering the shared
/// [iptvNavigationDestinations] manifest — the same single source of truth
/// consumed by the Android TV navigation rail (`_TvNavigationRail` in
/// `app/lib/core/app/tv_shell.dart`): Home, Guide, Movies & Shows, Favorites,
/// and Settings. Only this widget decides *whether* a destination is shown
/// here (via [showMovies] and the nullable [onSettings]) and which callback
/// it triggers — the manifest owns labels, icons, and destination identity.
class IptvNavigationDrawer extends StatelessWidget {
  const IptvNavigationDrawer({
    super.key,
    required this.onHome,
    required this.onGuide,
    required this.onMovies,
    required this.onFavorites,
    this.onSettings,
    this.showMovies = true,
    this.onPlayLocalFileOnTv,
  });

  final VoidCallback onHome;
  final VoidCallback onGuide;
  final VoidCallback onMovies;
  final VoidCallback onFavorites;
  final VoidCallback? onSettings;
  final bool showMovies;

  /// Streams a phone-local file to a receiver.
  /// Left unwired (null) unless the host app supplies a picker callback.
  final VoidCallback? onPlayLocalFileOnTv;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text('Menu', style: TextStyle(fontSize: 20)),
              ),
            ),
            for (final destination in iptvNavigationDestinations)
              if (_isVisible(destination.id))
                ListTile(
                  key: ValueKey('iptv-drawer-${_keySuffix(destination.id)}'),
                  leading: Icon(destination.icon),
                  title: Text(destination.labelFor(ShellId.mobile)),
                  onTap: () =>
                      _select(context, _actionFor(destination.id)!),
                ),
            if (onPlayLocalFileOnTv case final onPlayLocalFileOnTv?)
              ListTile(
                key: const ValueKey('iptv-drawer-play-on-tv'),
                leading: const Icon(Icons.cast_outlined),
                title: const Text('Play file on TV'),
                onTap: () => _select(context, onPlayLocalFileOnTv),
              ),
          ],
        ),
      ),
    );
  }

  void _select(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  /// Whether [id] should be shown in this drawer instance. Visibility here
  /// is per-drawer-instance state (a movies toggle, an optional settings
  /// callback), not manifest truth — the manifest declares the destination
  /// set, this widget decides which of those it currently renders.
  bool _isVisible(IptvDestinationId id) {
    switch (id) {
      case IptvDestinationId.vod:
        return showMovies;
      case IptvDestinationId.settings:
        return onSettings != null;
      case IptvDestinationId.home:
      case IptvDestinationId.guide:
      case IptvDestinationId.favorites:
        return true;
    }
  }

  /// The callback this drawer wires to [id]. Only called for ids that
  /// [_isVisible] already confirmed have a non-null callback.
  VoidCallback? _actionFor(IptvDestinationId id) {
    switch (id) {
      case IptvDestinationId.home:
        return onHome;
      case IptvDestinationId.guide:
        return onGuide;
      case IptvDestinationId.vod:
        return onMovies;
      case IptvDestinationId.favorites:
        return onFavorites;
      case IptvDestinationId.settings:
        return onSettings;
    }
  }

  /// Stable widget-key suffix per destination, preserving the exact keys
  /// ('iptv-drawer-home', ..., 'iptv-drawer-movies') this drawer used before
  /// it started rendering from the shared manifest.
  String _keySuffix(IptvDestinationId id) {
    switch (id) {
      case IptvDestinationId.home:
        return 'home';
      case IptvDestinationId.guide:
        return 'guide';
      case IptvDestinationId.vod:
        return 'movies';
      case IptvDestinationId.favorites:
        return 'favorites';
      case IptvDestinationId.settings:
        return 'settings';
    }
  }
}
