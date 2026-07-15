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

import 'dart:async';

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

  GlobalErrorHandler.initialize();

  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
    debugPrint('Semantics enabled for Airo TV web testing');
  }

  // First-frame critical: UI mode must be set before runApp.
  await configureTvSystemChrome();

  debugPrint('🖥️ Starting Airo TV (${PlatformFeatures.platformName})');
  debugPrint(
    '📺 Features: ${PlatformFeatures.enabledFeatures.map((f) => f.name).join(', ')}',
  );

  // Register features synchronously — providerOverrides available immediately.
  FeatureRegistry.register(IptvFeatureModule());

  // Firebase + SharedPreferences in parallel.
  final (prefs, _) = await (
    SharedPreferences.getInstance(),
    _initFirebase(),
  ).wait;

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

  // Defer post-frame: feature init (currently no-op) + debug network seed.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(FeatureRegistry.initializeAll());
    unawaited(seedTvDebugDefaultPlaylist(prefs));
  });
}

Future<void> _initFirebase() async {
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
Future<void> seedTvDebugDefaultPlaylist(
  SharedPreferences prefs, {
  String playlistUrl = _debugDefaultPlaylistUrl,
  M3UParserService? parser,
}) async {
  if (playlistUrl.isEmpty) return;

  final parserService = parser ?? M3UParserService(dio: Dio(), prefs: prefs);
  if (parserService.getPlaylistUrl() != null) return;

  await parserService.setPlaylistUrl(playlistUrl);
  await parserService.fetchPlaylist(forceRefresh: true);
}
