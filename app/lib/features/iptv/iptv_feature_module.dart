/// IPTV Feature Module for modular registration
///
/// This module provides IPTV streaming functionality that can be
/// conditionally included based on platform requirements.
///
/// Features:
/// - YouTube-quality adaptive streaming
/// - D-pad navigation for TV platforms
/// - Background audio for music channels
/// - Mini player for mobile
///
/// Usage:
/// ```dart
/// // In main_tv.dart or main_mobile_streaming.dart
/// FeatureRegistry.register(IptvFeatureModule());
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/platform_features.dart';
import '../../core/features/feature_registry.dart';
import 'presentation/screens/iptv_screen.dart';

/// IPTV Feature Module
///
/// Provides IPTV streaming routes and services.
/// Automatically enabled for platforms that support IPTV
/// (androidTv, mobileStreaming, mobileFull).
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
  Future<void> initialize() async {
    // IPTV initialization is handled by providers
    // The streaming service is lazily initialized when first accessed
  }

  @override
  Future<void> dispose() async {
    // Cleanup handled by Riverpod's ref.onDispose
  }
}
