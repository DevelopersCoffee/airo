/// TV-specific router for Android TV / Fire TV
///
/// Provides simplified navigation for TV with only IPTV-related routes.
/// No bottom navigation - uses grid/sidebar navigation patterns.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import "package:feature_iptv/feature_iptv.dart";
import '../auth/auth_service.dart';
import '../routing/route_names.dart';
import 'tv_shell.dart';

/// TV-specific routes
class TvRouteNames {
  TvRouteNames._();

  static const String home = '/';
  static const String live = '/live';
  static const String player = '/player';
  static const String settings = '/settings';
  static const String login = RouteNames.login;
}

/// Router for TV app
class TvRouter {
  TvRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: TvRouteNames.live,
    redirect: (context, state) async {
      // Initialize auth service if not already done
      await AuthService.instance.initialize();

      final isLoggedIn = AuthService.instance.isLoggedIn;
      final isLoginRoute = state.matchedLocation == TvRouteNames.login;

      // If not logged in and not on login page, redirect to login
      if (!isLoggedIn && !isLoginRoute) {
        return TvRouteNames.login;
      }

      // If logged in and on login page, redirect to live TV
      if (isLoggedIn && isLoginRoute) {
        return TvRouteNames.live;
      }

      return null; // No redirect needed
    },
    routes: [
      // Redirect root to live TV
      GoRoute(path: '/', redirect: (context, state) => TvRouteNames.live),
      // Login route (reuse mobile login for now)
      GoRoute(
        path: TvRouteNames.login,
        name: 'tv_login',
        builder: (context, state) => const LoginScreen(),
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
