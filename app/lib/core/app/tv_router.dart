/// TV-specific router for Android TV / Fire TV
///
/// Provides simplified navigation for TV with only IPTV-related routes.
/// No bottom navigation - uses grid/sidebar navigation patterns.
library;

import 'dart:async';

import 'package:core_product_shell/core_product_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/iptv/phone_media_local_picker.dart';
import '../../features/settings/presentation/screens/settings_hub_screen.dart';
import '../../features/settings/presentation/tv/tv_settings_screen.dart';
import '../platform/device_form_factor.dart';
import 'tv_route_names.dart';
import 'tv_shell.dart';

export 'tv_route_names.dart';

/// Router for TV app
class TvRouter {
  TvRouter._();

  static final GoRouter router = createRouter();

  @visibleForTesting
  static GoRouter createRouter({String initialLocation = TvRouteNames.home}) {
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
      routes: [
        // Preserve old links but keep the TV release auth-free.
        GoRoute(
          path: TvRouteNames.legacyLogin,
          redirect: (context, state) => TvRouteNames.home,
        ),
        // Main TV shell with sidebar navigation
        ShellRoute(
          builder: (context, state, child) => _AdaptiveTvShell(child: child),
          routes: [
            GoRoute(
              path: TvRouteNames.home,
              name: 'tv_home',
              builder: (context, state) => const _AdaptiveHomeScreen(),
            ),
            // One Watch session for /live, /player, and the IPTV deep-link
            // aliases. Moving between those URLs must not remount (and
            // stop) playback; leaving the group to Home/Guide/Settings
            // still disposes the scope.
            ShellRoute(
              builder: (context, state, child) =>
                  _WatchPlaybackScope(child: child),
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
                // Kept for deep links and tests. Watch itself is `/player`.
                GoRoute(
                  path: TvRouteNames.live,
                  name: 'tv_live',
                  builder: (context, state) => const _AdaptiveLiveTvScreen(),
                ),
                GoRoute(
                  path: TvRouteNames.player,
                  name: 'tv_player',
                  builder: (context, state) => const _AdaptiveLiveTvScreen(),
                ),
              ],
            ),
            GoRoute(
              path: TvRouteNames.guide,
              name: 'tv_guide',
              builder: (context, state) => IptvGuideScreen(
                overrideFormFactor: AiroFormFactor.tv,
                onChannelSelected: () => context.go(TvRouteNames.player),
              ),
            ),
            GoRoute(
              path: TvRouteNames.vod,
              name: 'tv_vod',
              builder: (context, state) => VodTvScreen(
                onItemSelected: () => context.go(TvRouteNames.player),
              ),
            ),
            GoRoute(
              path: TvRouteNames.favorites,
              name: 'tv_favorites',
              builder: (context, state) => TvFavoritesScreen(
                onChannelSelected: () => context.go(TvRouteNames.player),
              ),
            ),
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

/// Compact (Pixel 9 / phone) Home is the existing IPTV explorer. 10-foot
/// Home stays the silent stub until Task 4's QR dashboard.
class _AdaptiveHomeScreen extends StatelessWidget {
  const _AdaptiveHomeScreen();

  @override
  Widget build(BuildContext context) {
    if (_usesCompactPhoneLayout(context)) {
      return const _AdaptiveLiveTvScreen();
    }
    return const _TvHomePlaceholder();
  }
}

/// Silent Home stub. Task 4 replaces this with QR landing + dashboard rails.
class _TvHomePlaceholder extends StatelessWidget {
  const _TvHomePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(child: Text('Your media. Your player.')),
    );
  }
}

/// Owns the live playback session for `/player` and leftover `/live`.
/// Unmounting this scope (rail `go`, Back, or any other leave) calls
/// [VideoPlayerStreamingService.stop] so audio focus and the media session
/// are released. [IPTVScreen.dispose] does not.
class _WatchPlaybackScope extends ConsumerWidget {
  const _WatchPlaybackScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamingService = ref.watch(iptvStreamingServiceProvider);
    final isFullscreen = ref.watch(isFullscreenModeProvider);
    return _WatchSession(
      streamingService: streamingService,
      isFullscreen: isFullscreen,
      onLeaveWatch: () async {
        await awaitTvWatchStop(streamingService);
        if (!context.mounted) return;
        ref.read(tvNavigationIndexProvider.notifier).state = 0;
        context.go(TvRouteNames.home);
      },
      child: child,
    );
  }
}

class _WatchSession extends StatefulWidget {
  const _WatchSession({
    required this.streamingService,
    required this.isFullscreen,
    required this.onLeaveWatch,
    required this.child,
  });

  final VideoPlayerStreamingService streamingService;
  final bool isFullscreen;
  final Future<void> Function() onLeaveWatch;
  final Widget child;

  @override
  State<_WatchSession> createState() => _WatchSessionState();
}

class _WatchSessionState extends State<_WatchSession> {
  @override
  void initState() {
    super.initState();
    resetTvWatchStop(widget.streamingService);
  }

  @override
  void dispose() {
    unawaited(awaitTvWatchStop(widget.streamingService));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Fullscreen Back must reach IPTVScreen.didPopRoute ("exit
      // fullscreen"), not pop Watch. A true canPop here made the last
      // shell page poppable and dumped the live session.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || widget.isFullscreen) return;
        await widget.onLeaveWatch();
      },
      child: widget.child,
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
                  onSelect: () => context.go(TvRouteNames.home),
                  semanticLabel: 'Go to Home',
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
                      'Go to Home',
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
        onRootBack: () => context.go(TvRouteNames.home),
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
        // push (not go): settings needs a real Navigator entry so
        // PopScope's canPop is true and the system back gesture
        // (edge-swipe / predictive back) can pop it directly instead of
        // relying on the onRootBack fallback, which only the hardware/
        // AppBar back path exercised.
        onSettings: () => context.push(TvRouteNames.settings),
        onPickLocalMediaForTv: isGoogleCastSenderPlatform
            ? pickPhoneLocalMediaForTv
            : null,
        deepLinkIntent: deepLinkIntent,
      );
    }

    // A wide window on non-TV hardware only means a real remote-first
    // session when the OS is actually giving it a fixed fullscreen surface.
    // Android's Desktop Windowing (and classic split-screen) instead hands
    // this TV build a resizable, mouse/keyboard-driven window on a phone or
    // tablet -- forcing the 10-foot layout there hid the video preview
    // behind a bare remote-first grid with no visible player (#reported:
    // "desktop mode" screenshot from a Pixel 9 on an external monitor).
    if (DeviceFormFactorDetector.isDesktopWindowedSync()) {
      return IPTVScreen(
        onSettings: () => context.push(TvRouteNames.settings),
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
