import 'package:core_data/core_data.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app/airo_app.dart';
import 'core/app/main_provider_overrides.dart';
import 'core/config/firebase_status.dart';
import 'core/error/global_error_handler.dart';
// Stub-by-default: dart.library.html is false under dart2wasm, so keying the
// stub off html would link the real Mind module into a wasm web build — an
// R05 violation the gate cannot see (the compiler resolves this condition).
// Keying the REAL module off dart.library.io makes every non-native target
// fall back to the stub.
import 'core/mind/mind_registration_stub.dart'
    if (dart.library.io) 'core/mind/mind_registration.dart';
import 'core/routing/app_router.dart';
import 'core/startup/app_startup_tasks.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'features/iptv/epg_reminder_notification_gateway.dart';
import 'features/iptv/iptv_feature_module.dart';
import 'features/music/application/providers/beats_audio_provider.dart';
import 'firebase_options.dart';
import 'package:feature_coin/feature_coin.dart';

Future<void> main() {
  late SharedPreferences prefs;
  late ModuleRegistry moduleRegistry;
  late GoRouter router;
  late FlutterLocalNotificationsEpgReminderGateway epgReminderGateway;

  return AiroBootstrap.run(
    shell: ShellId.mobile,
    errorHandler: ErrorHandlerPolicy.enabled(GlobalErrorHandler.initialize),
    firebase: FirebasePolicy.blocking(
      options: DefaultFirebaseOptions.currentPlatform,
      // Web trusts index.html's own config (or the amnesty branch below) and
      // never gates on the generated placeholder check; native platforms do.
      isConfigured:
          kIsWeb ||
          (DefaultFirebaseOptions.isCurrentPlatformConfigured &&
              DefaultFirebaseOptions.isConfigured(
                DefaultFirebaseOptions.currentPlatform,
              )),
      onResult: (initialized) => isFirebaseInitialized = initialized,
    ),
    composeApp: () async {
      prefs = await SharedPreferences.getInstance();
      moduleRegistry = buildMainModuleRegistry();
      router = AppRouter.createRouter(moduleRegistry: moduleRegistry);
      epgReminderGateway = FlutterLocalNotificationsEpgReminderGateway(
        onNotificationRoute: router.go,
      );
      await epgReminderGateway.initialize();

      return ProviderScope(
        overrides: buildMainProviderOverrides(
          prefs: prefs,
          epgReminderGateway: epgReminderGateway,
          moduleRegistry: moduleRegistry,
        ),
        child: AiroApp(router: router),
      );
    },
    afterRunApp: () {
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
    },
  );
}

/// Builds the modules composed into the phone/tablet super-app.
///
/// Shell-specific navigation chrome remains in [AppRouter], while the registry
/// owns module inclusion, routes, lifecycle, and provider overrides.
@visibleForTesting
ModuleRegistry buildMainModuleRegistry() {
  final registry = ModuleRegistry(shell: ShellId.mobile)
    ..register(CoinVaultModule());
  registerMind(registry);
  registry.register(IptvFeatureModule());
  return registry;
}
