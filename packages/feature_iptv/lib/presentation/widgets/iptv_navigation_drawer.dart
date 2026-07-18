import 'package:flutter/material.dart';

/// Mobile hamburger-menu drawer for the IPTV screen, mirroring the
/// destinations already reachable from the Android TV navigation rail
/// (`_TvNavigationRail` in `app/lib/core/app/tv_shell.dart`): Home, Guide,
/// and Movies & Shows. TV's remaining rail destinations (Favorites,
/// Settings) have no mobile-usable screen yet and are intentionally left out
/// rather than wired to a placeholder.
class IptvNavigationDrawer extends StatelessWidget {
  const IptvNavigationDrawer({
    super.key,
    required this.onHome,
    required this.onGuide,
    required this.onMovies,
    this.showMovies = true,
  });

  final VoidCallback onHome;
  final VoidCallback onGuide;
  final VoidCallback onMovies;
  final bool showMovies;

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
