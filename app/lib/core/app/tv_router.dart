/// TV-specific router for Android TV / Fire TV
///
/// Provides simplified navigation for TV with only IPTV-related routes.
/// No bottom navigation - uses grid/sidebar navigation patterns.
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:feature_iptv/feature_iptv.dart';
import '../../features/settings/presentation/screens/settings_hub_screen.dart';
import '../../features/settings/presentation/tv/tv_settings_screen.dart';
import 'tv_shell.dart';

/// TV-specific routes
class TvRouteNames {
  TvRouteNames._();

  static const String home = '/';
  static const String live = '/live';
  static const String player = '/player';
  static const String guide = '/guide';
  static const String vod = '/vod';
  static const String favorites = '/favorites';
  static const String settings = '/settings';
  static const String legacyLogin = '/login';
}

/// Router for TV app
class TvRouter {
  TvRouter._();

  static final GoRouter router = createRouter();

  @visibleForTesting
  static GoRouter createRouter({String initialLocation = TvRouteNames.live}) {
    return GoRouter(
      initialLocation: initialLocation,
      redirect: (context, state) {
        final location = state.matchedLocation;
        if (location == TvRouteNames.home ||
            location == TvRouteNames.legacyLogin) {
          return TvRouteNames.live;
        }

        return null;
      },
      routes: [
        // Redirect root to live TV
        GoRoute(
          path: TvRouteNames.home,
          redirect: (context, state) => TvRouteNames.live,
        ),
        // Preserve old links but keep the TV release auth-free.
        GoRoute(
          path: TvRouteNames.legacyLogin,
          redirect: (context, state) => TvRouteNames.live,
        ),
        // Main TV shell with sidebar navigation
        ShellRoute(
          builder: (context, state, child) => _AdaptiveTvShell(child: child),
          routes: [
            // Live TV / IPTV (main screen)
            GoRoute(
              path: TvRouteNames.live,
              name: 'tv_live',
              builder: (context, state) => const _AdaptiveLiveTvScreen(),
            ),
            // Player route for fullscreen playback
            GoRoute(
              path: TvRouteNames.player,
              name: 'tv_player',
              builder: (context, state) => const _AdaptiveLiveTvScreen(),
            ),
            // Guide route
            GoRoute(
              path: TvRouteNames.guide,
              name: 'tv_guide',
              builder: (context, state) => IptvGuideScreen(
                overrideFormFactor: AiroFormFactor.tv,
                onChannelSelected: () => context.go(TvRouteNames.live),
              ),
            ),
            // VOD (movies/shows) route
            GoRoute(
              path: TvRouteNames.vod,
              name: 'tv_vod',
              builder: (context, state) => const VodTvScreen(),
            ),
            // Favorites route
            GoRoute(
              path: TvRouteNames.favorites,
              name: 'tv_favorites',
              builder: (context, state) => const TvFavoritesScreen(),
            ),
            // Settings route
            GoRoute(
              path: TvRouteNames.settings,
              name: 'tv_settings',
              builder: (context, state) => const AdaptiveTvSettingsScreen(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Phones running the TV build get the mobile settings hub (theme picker,
/// audio/playback links); the two-pane [TvSettingsScreen] needs 10-foot
/// width and clips on compact portrait layouts.
class AdaptiveTvSettingsScreen extends StatelessWidget {
  const AdaptiveTvSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (_usesCompactPhoneLayout(context)) {
      return const SettingsHubScreen();
    }

    return const TvSettingsScreen();
  }
}

class _AdaptiveTvShell extends StatelessWidget {
  const _AdaptiveTvShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (_usesCompactPhoneLayout(context)) {
      return child;
    }

    return TvShell(child: child);
  }
}

class _AdaptiveLiveTvScreen extends StatelessWidget {
  const _AdaptiveLiveTvScreen();

  @override
  Widget build(BuildContext context) {
    if (_usesCompactPhoneLayout(context)) {
      return const IPTVScreen();
    }

    return const IptvTvScreen();
  }
}

bool _usesCompactPhoneLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width < 900 || size.height < 600;
}
