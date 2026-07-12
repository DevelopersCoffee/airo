import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:feature_iptv/feature_iptv.dart';

import '../../core/config/platform_features.dart';
import '../../core/features/feature_registry.dart';

class IptvFeatureModule extends AppFeatureModule {
  @override
  String get name => 'iptv';

  @override
  AppFeature get featureType => AppFeature.iptv;

  @override
  List<RouteBase> get routes => [
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

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}
}
