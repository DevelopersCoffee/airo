import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:go_router/go_router.dart';

/// Shell adapter for the shared IPTV feature package.
///
/// The module is available to both the mobile super-app and focused TV app.
/// Each host owns its shell chrome while this adapter preserves IPTV's stable
/// route identities.
class IptvFeatureModule extends AppModule {
  @override
  String get id => 'iptv';

  @override
  Set<ShellId> get supportedShells => {ShellId.mobile, ShellId.tv};

  @override
  List<RouteBase> routesFor(ShellId shell) => [
    GoRoute(
      path: '/iptv',
      name: 'iptv',
      builder: (context, state) => const IPTVScreen(),
    ),
    GoRoute(
      path: '/iptv/player',
      name: 'iptv_player',
      builder: (context, state) {
        final channelId = state.uri.queryParameters['channelId'];
        return IPTVScreen(
          key: channelId != null ? ValueKey<String>(channelId) : null,
        );
      },
    ),
  ];
}
