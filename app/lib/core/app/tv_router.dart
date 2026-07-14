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
            return _AdaptiveTvShell(child: child);
          },
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
              builder: (context, state) {
                return const _AdaptiveLiveTvScreen();
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
