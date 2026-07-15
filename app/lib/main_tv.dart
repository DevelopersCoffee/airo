/// Entrypoint for Android TV / Fire TV builds
///
/// This entrypoint initializes a minimal app with only IPTV functionality.
/// Target APK size: <120MB
///
/// Build command:
/// ```bash
/// flutter build apk --release \
///   --target=lib/main_tv.dart \
///   --dart-define=APP_VARIANT=tv \
///   --dart-define=APP_PLATFORM=androidTv \
///   --split-per-abi
/// ```
library;

import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app/airo_tv_app.dart';
import 'core/config/platform_features.dart';
import 'core/error/global_error_handler.dart';
import 'core/features/feature_registry.dart';
import 'core/platform/device_form_factor.dart';
import 'core/startup/deferred_startup_task.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'features/iptv/iptv_cast_provider_override.dart';
import 'features/iptv/iptv_feature_module.dart';
import 'firebase_options.dart';

/// Global flag to track if Firebase is available
bool isFirebaseInitialized = false;

const _debugDefaultPlaylistUrl = String.fromEnvironment(
  'DEBUG_IPTV_PLAYLIST_URL',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AiroImageCacheBudget.configureAndroidTv();

  // Initialize global error handler for unhandled exceptions
  GlobalErrorHandler.initialize();

  // Enable semantics for browser release-audit automation and accessibility
  // inspection. This mirrors the main web entrypoint behavior.
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
    debugPrint('Semantics enabled for Airo TV web testing');
  }

  await configureTvSystemChrome();

  debugPrint('🖥️ Starting Airo TV (${PlatformFeatures.platformName})');
  debugPrint(
    '📺 Features: ${PlatformFeatures.enabledFeatures.map((f) => f.name).join(', ')}',
  );

  // Initialize Firebase with TV variant configuration
  try {
    if (!DefaultFirebaseOptions.isCurrentPlatformConfigured) {
      isFirebaseInitialized = false;
      debugPrint('⚠️ Firebase not configured for this platform; skipping init');
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      isFirebaseInitialized = true;
      debugPrint(
        '✅ Firebase initialized (TV variant: ${DefaultFirebaseOptions.currentVariant.name})',
      );
    }
  } catch (e) {
    isFirebaseInitialized = false;
    debugPrint('⚠️ Firebase initialization failed: $e');
  }

  // Initialize SharedPreferences for IPTV caching
  final prefs = await SharedPreferences.getInstance();
  final shouldWarmDebugPlaylist = await seedTvDebugDefaultPlaylist(prefs);

  // Initialize feature registry with TV-specific features
  FeatureRegistry.register(IptvFeatureModule());
  await FeatureRegistry.initializeAll();

  debugPrint(
    '📦 Registered features: ${FeatureRegistry.featureNames.join(', ')}',
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        realIptvCastControllerOverride(),
        ...FeatureRegistry.allProviderOverrides,
      ],
      child: const AiroTvApp(),
    ),
  );

  if (shouldWarmDebugPlaylist) {
    scheduleTvDebugDefaultPlaylistWarmup(prefs);
  }
}

@visibleForTesting
Future<void> configureTvSystemChrome({
  Future<DeviceFormFactor> Function()? detectFormFactor,
  Future<void> Function(List<DeviceOrientation> orientations)?
  setPreferredOrientations,
  Future<void> Function(SystemUiMode mode, {List<SystemUiOverlay>? overlays})?
  setEnabledSystemUIMode,
}) async {
  final formFactor =
      await (detectFormFactor ??
          () {
            return DeviceFormFactorDetector.detect(null);
          })();
  final applyOrientations =
      setPreferredOrientations ?? SystemChrome.setPreferredOrientations;
  final applySystemUiMode =
      setEnabledSystemUIMode ?? SystemChrome.setEnabledSystemUIMode;

  if (formFactor == DeviceFormFactor.tv) {
    await applyOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await applySystemUiMode(SystemUiMode.immersiveSticky, overlays: []);
    return;
  }

  await applyOrientations([]);
  await applySystemUiMode(SystemUiMode.edgeToEdge);
}

@visibleForTesting
Future<bool> seedTvDebugDefaultPlaylist(
  SharedPreferences prefs, {
  String playlistUrl = _debugDefaultPlaylistUrl,
  M3UParserService? parser,
}) async {
  if (playlistUrl.isEmpty) return false;

  final parserService = parser ?? M3UParserService(dio: Dio(), prefs: prefs);
  if (parserService.getPlaylistUrl() != null) return false;

  await parserService.setPlaylistUrl(playlistUrl);
  return true;
}

@visibleForTesting
void scheduleTvDebugDefaultPlaylistWarmup(
  SharedPreferences prefs, {
  String debugName = 'tv_debug_playlist_warmup',
  String playlistUrl = _debugDefaultPlaylistUrl,
  M3UParserService? parser,
  WidgetsBinding? binding,
  void Function(DeferredStartupFrameCallback callback)? addPostFrameCallback,
  void Function(String message)? log,
}) {
  if (playlistUrl.isEmpty) return;

  scheduleDeferredStartupTask(
    debugName: debugName,
    binding: binding,
    addPostFrameCallback: addPostFrameCallback,
    log: log,
    task: () => warmTvDebugDefaultPlaylistCache(
      prefs,
      playlistUrl: playlistUrl,
      parser: parser,
    ),
  );
}

@visibleForTesting
Future<void> warmTvDebugDefaultPlaylistCache(
  SharedPreferences prefs, {
  String playlistUrl = _debugDefaultPlaylistUrl,
  M3UParserService? parser,
}) async {
  if (playlistUrl.isEmpty) return;

  final parserService = parser ?? M3UParserService(dio: Dio(), prefs: prefs);
  if (parserService.getPlaylistUrl() != playlistUrl) return;

  await parserService.fetchPlaylist(forceRefresh: true);
}
