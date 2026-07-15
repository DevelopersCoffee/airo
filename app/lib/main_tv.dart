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

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app/airo_tv_app.dart';
import 'core/auth/auth_service.dart';
import 'core/config/platform_features.dart';
import 'core/error/global_error_handler.dart';
import 'core/features/feature_registry.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'features/iptv/iptv_feature_module.dart';
import 'firebase_options.dart';

/// Global flag to track if Firebase is available
bool isFirebaseInitialized = false;

Future<void> configureTvSystemChrome() async {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TV ImageCache budgets: smaller than mobile because TV devices have
  // limited RAM. 50 MB / 200 images keeps memory predictable for 10k+
  // channel playlists where logos are decoded at display size.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 200;

  GlobalErrorHandler.initialize();

  if (kIsWeb) {
    WidgetsBinding.instance.ensureSemantics();
    debugPrint('Semantics enabled for Airo TV web testing');
  }

  await configureTvSystemChrome();

  debugPrint('🖥️ Starting Airo TV (${PlatformFeatures.platformName})');
  debugPrint(
    '📺 Features: ${PlatformFeatures.enabledFeatures.map((f) => f.name).join(', ')}',
  );

  FeatureRegistry.register(IptvFeatureModule());

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
        ...FeatureRegistry.allProviderOverrides,
      ],
      child: const AiroTvApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(FeatureRegistry.initializeAll());
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
