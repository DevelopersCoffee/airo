/// TV-specific router for Android TV / Fire TV
///
/// Provides simplified navigation for TV with only IPTV-related routes.
/// No bottom navigation - uses grid/sidebar navigation patterns.
library;

import 'package:core_product_shell/core_product_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/iptv/phone_media_local_picker.dart';
import '../../features/settings/presentation/screens/settings_hub_screen.dart';
import '../../features/settings/presentation/tv/tv_settings_screen.dart';
import '../platform/device_form_factor.dart';
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
      // The canonical deep link is registered with `android:pathPrefix`, so
      // Android hands this router any deeper path under `/airo/iptv` — but
      // `IptvDeepLinkIntent.tryParse` only accepts the exact path (all of its
      // payload rides in query parameters), and no route matches the rest.
      // Without this those links landed on go_router's default red error
      // page, which has no way out on a remote: it is outside the shell, so
      // there is no navigation rail, and BACK closes the app.
      errorBuilder: (context, state) =>
          _TvRouteNotFoundScreen(location: state.uri.toString()),
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
            GoRoute(
              path: '/airo/iptv',
              builder: (context, state) => _AdaptiveLiveTvScreen(
                deepLinkIntent: IptvDeepLinkIntent.tryParse(state.uri),
              ),
            ),
            GoRoute(
              path: '/iptv',
              builder: (context, state) => _AdaptiveLiveTvScreen(
                deepLinkIntent: IptvDeepLinkIntent.tryParse(state.uri),
              ),
            ),
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

/// Shown when no route matches — most often a deep link under the
/// `/airo/iptv` prefix that carries a path segment the canonical link shape
/// does not use. Replaces go_router's default error page, which on a remote
/// is a dead end: it renders outside [TvShell], so there is no navigation
/// rail to escape through, and BACK leaves the app.
class _TvRouteNotFoundScreen extends StatelessWidget {
  const _TvRouteNotFoundScreen({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_off, size: 56, color: colors.onSurfaceVariant),
                const SizedBox(height: 20),
                Text(
                  'That link could not be opened',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  location,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                TvFocusable(
                  autofocus: true,
                  onSelect: () => context.go(TvRouteNames.live),
                  semanticLabel: 'Go to Live TV',
                  semanticButton: true,
                  borderRadius: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Go to Live TV',
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
      return SettingsHubScreen(
        onRootBack: () => context.go(TvRouteNames.live),
        shellId: ShellId.tv,
      );
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
  const _AdaptiveLiveTvScreen({this.deepLinkIntent});

  final IptvDeepLinkIntent? deepLinkIntent;

  @override
  Widget build(BuildContext context) {
    if (_usesCompactPhoneLayout(context)) {
      return IPTVScreen(
        onSettings: () => context.go(TvRouteNames.settings),
        onPickLocalMediaForTv: isGoogleCastSenderPlatform
            ? pickPhoneLocalMediaForTv
            : null,
        deepLinkIntent: deepLinkIntent,
      );
    }

    // Wide layouts get the 10-foot AiroTvShell path with phone chrome
    // (app bar, drawer, cast entry) suppressed — the TvShell sidebar owns
    // navigation.
    return IPTVScreen(tenFootMode: true, deepLinkIntent: deepLinkIntent);
  }
}

bool _usesCompactPhoneLayout(BuildContext context) {
  // A detected TV always gets the 10-foot layout. TV sticks commonly render
  // 1080p at density 2.0, so their *logical* viewport (960x540) is smaller
  // than a phone's — the size heuristic alone would misclassify every one
  // of them (seen on Fire TV Stick: phone drawer + cast chrome on a TV).
  // Detection is warmed at startup by configureTvSystemChrome(), so the
  // synchronous cached read is populated before the router ever builds.
  if (DeviceFormFactorDetector.detectSync(context) == DeviceFormFactor.tv) {
    return false;
  }
  final size = MediaQuery.sizeOf(context);
  return size.width < 900 || size.height < 600;
}
