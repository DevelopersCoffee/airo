import 'package:firebase_core/firebase_core.dart';
import 'package:core_data/core_data.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app/airo_app.dart';
import 'core/app/main_provider_overrides.dart';
import 'core/coins/coin_vault_module.dart';
import 'core/config/firebase_status.dart';
import 'core/error/global_error_handler.dart';
import 'core/routing/app_router.dart';
import 'core/startup/app_startup_tasks.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'features/iptv/epg_reminder_notification_gateway.dart';
import 'features/iptv/iptv_feature_module.dart';
import 'features/music/application/providers/beats_audio_provider.dart';
import 'firebase_options.dart';

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
    } else if (!DefaultFirebaseOptions.isCurrentPlatformConfigured) {
      isFirebaseInitialized = false;
      debugPrint('⚠️ Firebase not configured for this platform; skipping init');
      debugPrint(
        '📝 Demo login (admin/admin) available. Google Sign-In needs Firebase.',
      );
    } else {
      // Native platforms
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

  // Initialize SharedPreferences for IPTV caching
  final prefs = await SharedPreferences.getInstance();
  final epgReminderGateway = FlutterLocalNotificationsEpgReminderGateway(
    onNotificationRoute: AppRouter.router.go,
  );
  await epgReminderGateway.initialize();
  final moduleRegistry = buildMainModuleRegistry();

  runApp(
    ProviderScope(
      overrides: buildMainProviderOverrides(
        prefs: prefs,
        epgReminderGateway: epgReminderGateway,
        moduleRegistry: moduleRegistry,
      ),
      child: const AiroApp(),
    ),
  );

  AppLifecycleListener(
    onResume: () async {
      try {
        await EpgReminderScheduler(
          store: EpgReminderStore(PreferencesStore(prefs)),
          gateway: epgReminderGateway,
        ).pruneElapsed();
      } catch (error) {
        debugPrint('[EpgReminderGateway] pruneElapsed failed: $error');
      }
    },
  );

  scheduleDeferredAuthInitialization();
  scheduleDeferredFeatureInitialization(
    initializeFeatures: moduleRegistry.initializeAll,
  );
  scheduleDeferredProBootstrap();
  scheduleDeferredAudioInitialization(
    initializeAudio: initAudioService,
    skipOnWeb: true,
  );
}

/// Builds the modules composed into the phone/tablet super-app.
///
/// The router currently supplies shell-specific navigation chrome, while the
/// registry owns module inclusion, lifecycle, and provider overrides. Route
/// extraction into shell adapters remains additive so existing deep links are
/// preserved during the migration.
@visibleForTesting
ModuleRegistry buildMainModuleRegistry() {
  return ModuleRegistry(shell: ShellId.mobile)
    ..register(CoinVaultModule())
    ..register(IptvFeatureModule());
}
