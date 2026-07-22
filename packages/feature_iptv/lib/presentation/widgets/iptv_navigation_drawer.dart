import 'package:flutter/material.dart';

/// Mobile hamburger-menu drawer for the IPTV screen, mirroring the
/// destinations already reachable from the Android TV navigation rail
/// (`_TvNavigationRail` in `app/lib/core/app/tv_shell.dart`): Home, Guide,
/// Movies & Shows, Favorites, and Settings.
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

  /// CV-033 debug entry point: streams a phone-local file to a receiver.
  /// Left unwired (null) unless the app build supplies a picker, since the
  /// end-user surface for this flow is still undecided.
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
            ListTile(
              key: const ValueKey('iptv-drawer-home'),
              leading: const Icon(Icons.home_outlined),
              title: const Text('Home'),
              onTap: () => _select(context, onHome),
            ),
            ListTile(
              key: const ValueKey('iptv-drawer-guide'),
              leading: const Icon(Icons.grid_view_outlined),
              title: const Text('Guide'),
              onTap: () => _select(context, onGuide),
            ),
            if (showMovies)
              ListTile(
                key: const ValueKey('iptv-drawer-movies'),
                leading: const Icon(Icons.movie_outlined),
                title: const Text('Movies & Shows'),
                onTap: () => _select(context, onMovies),
              ),
            ListTile(
              key: const ValueKey('iptv-drawer-favorites'),
              leading: const Icon(Icons.favorite_border),
              title: const Text('Favorites'),
              onTap: () => _select(context, onFavorites),
            ),
            if (onSettings case final onSettings?)
              ListTile(
                key: const ValueKey('iptv-drawer-settings'),
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () => _select(context, onSettings),
              ),
            if (onPlayLocalFileOnTv case final onPlayLocalFileOnTv?)
              ListTile(
                key: const ValueKey('iptv-drawer-play-on-tv'),
                leading: const Icon(Icons.cast_outlined),
                title: const Text('Play file on TV (debug)'),
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
}
