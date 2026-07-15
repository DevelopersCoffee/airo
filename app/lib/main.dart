import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app/airo_app.dart';
import 'core/auth/auth_service.dart';
import 'core/error/global_error_handler.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'features/music/application/providers/beats_audio_provider.dart';
import 'firebase_options.dart';

/// Global flag to track if Firebase is available
bool isFirebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mobile ImageCache budgets: generous for phones/tablets with more RAM.
  // 100 MB / 500 images covers IPTV channel logos + other app images.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 500;

  GlobalErrorHandler.initialize();

  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
    debugPrint('🔧 Semantics enabled for web testing');
  }

  // Firebase + SharedPreferences in parallel; AuthService reuses cached prefs.
  final (prefs, _) = await (
    SharedPreferences.getInstance(),
    _initFirebase(),
  ).wait;

  await AuthService.instance.initialize();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const AiroApp(),
    ),
  );

  _scheduleAudioServiceInitialization();
}

Future<void> _initFirebase() async {
  try {
    if (kIsWeb) {
      if (Firebase.apps.isNotEmpty) {
        isFirebaseInitialized = true;
        debugPrint('✅ Firebase already initialized (from index.html)');
      } else {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        isFirebaseInitialized = true;
        debugPrint('✅ Firebase initialized successfully (web)');
      }
    } else if (!DefaultFirebaseOptions.isCurrentPlatformConfigured) {
      isFirebaseInitialized = false;
      debugPrint('⚠️ Firebase not configured for this platform; skipping init');
      debugPrint(
        '📝 Demo login (admin/admin) available. Google Sign-In needs Firebase.',
      );
    } else {
      final options = DefaultFirebaseOptions.currentPlatform;
      if (DefaultFirebaseOptions.isConfigured(options)) {
        await Firebase.initializeApp(options: options);
        isFirebaseInitialized = true;
        debugPrint('✅ Firebase initialized successfully');
      } else {
        isFirebaseInitialized = false;
        debugPrint('⚠️ Firebase skipped: platform options are placeholders.');
      }
    }
  } catch (e) {
    if (kIsWeb && Firebase.apps.isNotEmpty) {
      isFirebaseInitialized = true;
      debugPrint('✅ Firebase available (initialized from index.html)');
    } else {
      isFirebaseInitialized = false;
      debugPrint('⚠️ Firebase initialization failed: $e');
      debugPrint(
        '📝 Demo login (admin/admin) available. Google Sign-In needs Firebase.',
      );
    }
  }
}

void _scheduleAudioServiceInitialization() {
  if (kIsWeb) return;

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
