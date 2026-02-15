import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app/airo_app.dart';
import 'core/auth/auth_service.dart';
import 'core/error/global_error_handler.dart';
import 'features/iptv/application/providers/iptv_providers.dart';
import 'features/music/application/providers/beats_audio_provider.dart';
import 'firebase_options.dart';

/// Global flag to track if Firebase is available
bool isFirebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize global error handler for unhandled exceptions
  GlobalErrorHandler.initialize();

  // Enable semantics for web testing (Playwright/Selenium/accessibility)
  // This creates DOM elements from Flutter's semantic tree
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
    debugPrint('🔧 Semantics enabled for web testing');
  }

  // Initialize Firebase with platform-specific options
  try {
    if (kIsWeb) {
      // On web, check if Firebase is already initialized from index.html
      if (Firebase.apps.isNotEmpty) {
        isFirebaseInitialized = true;
        debugPrint('✅ Firebase already initialized (from index.html)');
      } else {
        // Try to initialize if not already done
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        isFirebaseInitialized = true;
        debugPrint('✅ Firebase initialized successfully (web)');
      }
    } else {
      // Native platforms
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      isFirebaseInitialized = true;
      debugPrint('✅ Firebase initialized successfully');
    }
  } catch (e) {
    // On web, Firebase might already be initialized from index.html
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

  // Initialize AuthService
  await AuthService.instance.initialize();

  // Initialize audio service for background music playback
  // This must be done before runApp() for audio_service to work properly
  if (!kIsWeb) {
    try {
      await initAudioService();
      debugPrint('✅ Audio service initialized for background playback');
    } catch (e) {
      debugPrint('⚠️ Audio service initialization failed: $e');
      debugPrint('📝 Background music playback may not work');
    }
  }

  // Initialize SharedPreferences for IPTV caching
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const AiroApp(),
    ),
  );
}
