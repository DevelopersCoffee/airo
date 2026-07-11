/// Entrypoint for Mobile Streaming builds
///
/// This entrypoint initializes an app with Music + IPTV functionality.
/// Target APK size: <150MB
///
/// Build command:
/// ```bash
/// flutter build apk --release \
///   --target=lib/main_mobile_streaming.dart \
///   --dart-define=APP_VARIANT=streaming \
///   --dart-define=APP_PLATFORM=mobileStreaming \
///   --split-per-abi
/// ```
library;

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app/airo_app.dart';
import 'core/auth/auth_service.dart';
import 'core/config/platform_features.dart';
import 'core/error/global_error_handler.dart';
import 'core/features/feature_registry.dart';
import "package:feature_iptv/feature_iptv.dart";
import "features/iptv/iptv_feature_module.dart";
import 'features/music/application/providers/beats_audio_provider.dart';
import 'features/music/music_feature_module.dart';
import 'firebase_options.dart';

/// Global flag to track if Firebase is available
bool isFirebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize global error handler for unhandled exceptions
  GlobalErrorHandler.initialize();

  debugPrint('🎵 Starting Airo Streaming (${PlatformFeatures.platformName})');
  debugPrint(
    '📱 Features: ${PlatformFeatures.enabledFeatures.map((f) => f.name).join(', ')}',
  );

  // Initialize Firebase with streaming variant configuration
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
        '✅ Firebase initialized (Streaming variant: ${DefaultFirebaseOptions.currentVariant.name})',
      );
    }
  } catch (e) {
    isFirebaseInitialized = false;
    debugPrint('⚠️ Firebase initialization failed: $e');
  }

  // Initialize AuthService
  await AuthService.instance.initialize();

  // Initialize SharedPreferences for caching
  final prefs = await SharedPreferences.getInstance();

  // Initialize feature registry with streaming features
  FeatureRegistry.register(IptvFeatureModule());
  FeatureRegistry.register(MusicFeatureModule());
  await FeatureRegistry.initializeAll();

  debugPrint(
    '📦 Registered features: ${FeatureRegistry.featureNames.join(', ')}',
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...FeatureRegistry.allProviderOverrides,
      ],
      child: const AiroApp(),
    ),
  );

  _scheduleAudioServiceInitialization();
}

void _scheduleAudioServiceInitialization() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(() async {
      try {
        await initAudioService();
        debugPrint('✅ Audio service initialized for background playback');
      } catch (e) {
        debugPrint('⚠️ Audio service initialization failed: $e');
        debugPrint('📝 Background music playback may not work');
      }
    }());
  });
}
