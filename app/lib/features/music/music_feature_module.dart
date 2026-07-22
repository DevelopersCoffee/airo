/// Music Feature Module for modular registration
///
/// This module provides music/audio streaming functionality that can be
/// conditionally included based on platform requirements.
///
/// Features:
/// - Background audio playback via audio_service
/// - Notification controls (play/pause/skip)
/// - Queue management
/// - Mini player widget
///
/// Usage:
/// ```dart
/// // In the full Airo entrypoint.
/// FeatureRegistry.register(MusicFeatureModule());
/// ```
///
/// Note: Audio initialization is scheduled by startup orchestration.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/platform_features.dart';
import '../../core/features/feature_registry.dart';
import 'application/providers/beats_audio_provider.dart';
import 'presentation/screens/music_screen.dart';

/// Music Feature Module
///
/// Provides music streaming routes and services.
/// Automatically enabled for platforms that support music
/// (mobileFull and iPad).
class MusicFeatureModule extends AppFeatureModule {
  bool _audioInitialized = false;

  @override
  String get name => 'music';

  @override
  AppFeature get featureType => AppFeature.music;

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/music',
      name: 'music',
      builder: (context, state) => const MusicScreen(),
    ),
    GoRoute(
      path: '/music/player',
      name: 'music_player',
      builder: (context, state) {
        final trackId = state.uri.queryParameters['trackId'];
        return MusicScreen(
          key: trackId != null ? ValueKey<String>(trackId) : null,
        );
      },
    ),
  ];

  @override
  List<Override> get providerOverrides => [];

  @override
  Future<void> initialize() async {
    // Initialize audio service for background playback
    // This is critical for music streaming to work properly
    try {
      await initAudioService();
      _audioInitialized = true;
    } catch (e) {
      // Audio service might already be initialized
      // or might fail on unsupported platforms
      _audioInitialized = false;
      // ignore: avoid_print
      print('Music feature: Audio service initialization warning: $e');
    }
  }

  @override
  Future<void> dispose() async {
    // Audio service lifecycle is managed by the system
    // We don't dispose it here as other features might use it
  }

  /// Check if audio service is ready
  bool get isAudioReady => _audioInitialized;
}
