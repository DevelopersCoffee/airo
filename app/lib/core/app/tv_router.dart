/// TV-specific router for Android TV / Fire TV
///
/// Provides simplified navigation for TV with only IPTV-related routes.
/// No bottom navigation - uses grid/sidebar navigation patterns.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:feature_iptv/feature_iptv.dart';
import 'tv_shell.dart';

/// TV-specific routes
class TvRouteNames {
  TvRouteNames._();

  static const String home = '/';
  static const String live = '/live';
  static const String player = '/player';
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
          builder: (context, state, child) {
            return TvShell(child: child);
          },
          routes: [
            // Live TV / IPTV (main screen)
            GoRoute(
              path: TvRouteNames.live,
              name: 'tv_live',
              builder: (context, state) => const IPTVScreen(),
            ),
            // Player route for fullscreen playback
            GoRoute(
              path: TvRouteNames.player,
              name: 'tv_player',
              builder: (context, state) {
                // Get channel from query params
                final channelId = state.uri.queryParameters['channelId'];
                return IPTVScreen(
                  // Pass channel ID if provided
                  key: channelId != null ? ValueKey<String>(channelId) : null,
                );
              },
            ),
            // Settings route
            GoRoute(
              path: TvRouteNames.settings,
              name: 'tv_settings',
              builder: (context, state) => const _TvSettingsPlaceholder(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Placeholder for TV settings screen
class _TvSettingsPlaceholder extends StatelessWidget {
  const _TvSettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Settings', style: TextStyle(fontSize: 24)),
    );
  }
}
