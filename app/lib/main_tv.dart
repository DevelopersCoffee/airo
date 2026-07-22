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

import 'dart:io';

import 'package:airo_pro_bootstrap/airo_pro_bootstrap.dart'
    as airo_pro_bootstrap;
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app/airo_tv_app.dart';
import 'core/audio/tv_audio_service.dart';
import 'core/config/platform_features.dart';
import 'core/error/global_error_handler.dart';
import 'core/features/feature_registry.dart';
import 'core/platform/device_form_factor.dart';
import 'core/providers/app_theme_provider.dart';
import 'core/startup/deferred_startup_task.dart';
import 'package:feature_iptv/application/airo_tv_bootstrap.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'features/iptv/iptv_cast_provider_override.dart';
import 'features/iptv/iptv_feature_module.dart';
import 'firebase_options.dart';

/// Global flag to track if Firebase is available
bool isFirebaseInitialized = false;
typedef TvFirebaseInitializer = Future<void> Function();

const _debugDefaultPlaylistUrl = String.fromEnvironment(
  'DEBUG_IPTV_PLAYLIST_URL',
);
const _debugDefaultEpgUrl = String.fromEnvironment('DEBUG_IPTV_EPG_URL');

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

  // Initialize SharedPreferences for IPTV caching
  final prefs = await SharedPreferences.getInstance();
  final shouldWarmDebugPlaylist = await seedTvDebugDefaultPlaylist(prefs);
  final mutableXmltvRepository = MutableXmltvCompactEpgRepository();
  final compactEpgRepository = createTvCompactEpgRepository(
    fallback: mutableXmltvRepository,
  );

  // Initialize feature registry with TV-specific features
  FeatureRegistry.register(IptvFeatureModule());

  debugPrint(
    '📦 Registered features: ${FeatureRegistry.featureNames.join(', ')}',
  );

  // Initialize the OS media session (media notification + lock-screen
  // controls) on Android, where audio_service's foreground service is what
  // keeps live audio alive — and controllable — after a Home press (#980).
  // Skipped elsewhere: web has no audio_service host, and desktop dev
  // builds don't run the Android foreground service.
  //
  // Bounded: a misbehaving OS media service must never block app startup —
  // on a timeout/failure the app boots normally without media-session
  // controls (the pre-#980 behavior).
  TvAudioHandler? tvAudioHandler;
  if (!kIsWeb && Platform.isAndroid) {
    try {
      tvAudioHandler = await initTvAudioService().timeout(
        const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('📺 TV audio service init skipped: $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: buildTvProviderOverrides(
        prefs: prefs,
        compactEpgRepository: compactEpgRepository,
        mutableXmltvRepository: mutableXmltvRepository,
        tvAudioHandler: tvAudioHandler,
      ),
      child: const AiroTvApp(),
    ),
  );

  scheduleTvFirebaseInitialization();
  scheduleTvFeatureInitialization();
  scheduleTvProModuleInitialization();
  if (shouldWarmDebugPlaylist) {
    scheduleTvDebugDefaultPlaylistWarmup(prefs);
  }
  scheduleTvDebugDefaultEpgWarmup(
    prefs,
    repository: compactEpgRepository,
    windowRepository: mutableXmltvRepository,
  );
  scheduleTvXmltvSourceRefresh(prefs, repository: mutableXmltvRepository);
}

@visibleForTesting
List<Override> buildTvProviderOverrides({
  required SharedPreferences prefs,
  required CompactEpgRepository compactEpgRepository,
  required MutableXmltvCompactEpgRepository mutableXmltvRepository,
  TvAudioHandler? tvAudioHandler,
}) {
  final handler = tvAudioHandler;
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    // Airo TV defaults to the design handoff's dedicated theme unless
    // the user has explicitly picked a different one in Settings.
    appThemeProvider.overrideWith(
      (ref) => AppThemeNotifier(defaultThemeId: AppThemeId.airoTv),
    ),
    compactEpgRepositoryProvider.overrideWithValue(compactEpgRepository),
    mutableXmltvCompactEpgRepositoryProvider.overrideWithValue(
      mutableXmltvRepository,
    ),
    secureStoreProvider.overrideWithValue(SecureStoreFactory.createSecure()),
    // Phones running the TV build fall back to the mobile IPTV screen
    // (tv_router.dart compact layout), whose cast UI needs the real
    // controller — without this override casting silently no-ops.
    realIptvCastControllerOverride(),
    // #980: publish playback state to the OS media session and route
    // notification buttons back into the streaming service. The delegate
    // reporting direction flows through tvIptvIntegrationProvider; the
    // user-intent callbacks below are the control direction.
    if (handler != null)
      tvMediaSessionDelegateProvider.overrideWith((ref) {
        handler.onUserPauseRequested = () =>
            ref.read(iptvStreamingServiceProvider).pause();
        handler.onUserPlayRequested = () =>
            ref.read(iptvStreamingServiceProvider).resume();
        handler.onUserStopRequested = () =>
            ref.read(iptvStreamingServiceProvider).stop();
        return handler;
      }),
    ...FeatureRegistry.allProviderOverrides,
  ];
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
void scheduleTvFirebaseInitialization({
  void Function(DeferredStartupFrameCallback callback)? addPostFrameCallback,
  void Function(String message)? log,
  TvFirebaseInitializer? initializeApp,
  bool? isConfigured,
  String variantName = '',
}) {
  scheduleDeferredStartupTask(
    debugName: 'tv_firebase_initialization',
    addPostFrameCallback: addPostFrameCallback,
    log: log,
    task: () => initializeTvFirebase(
      initializeApp: initializeApp,
      isConfigured: isConfigured,
      variantName: variantName.isEmpty
          ? DefaultFirebaseOptions.currentVariant.name
          : variantName,
      log: log,
    ),
  );
}

@visibleForTesting
Future<bool> initializeTvFirebase({
  TvFirebaseInitializer? initializeApp,
  bool? isConfigured,
  String variantName = '',
  void Function(String message)? log,
}) async {
  final logger = log ?? debugPrint;
  final configured =
      isConfigured ?? DefaultFirebaseOptions.isCurrentPlatformConfigured;
  try {
    if (!configured) {
      isFirebaseInitialized = false;
      logger('⚠️ Firebase not configured for this platform; skipping init');
      return false;
    }

    await (initializeApp ??
        () {
          return Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        })();
    isFirebaseInitialized = true;
    logger('✅ Firebase initialized (TV variant: $variantName)');
    return true;
  } catch (e) {
    isFirebaseInitialized = false;
    logger('⚠️ Firebase initialization failed: $e');
    return false;
  }
}

@visibleForTesting
void scheduleTvFeatureInitialization({
  void Function(DeferredStartupFrameCallback callback)? addPostFrameCallback,
  void Function(String message)? log,
}) {
  scheduleDeferredStartupTask(
    debugName: 'tv_feature_initialization',
    addPostFrameCallback: addPostFrameCallback,
    log: log,
    task: () async {
      await FeatureRegistry.initializeAll();
      (log ?? debugPrint)(
        '📦 Initialized features: ${FeatureRegistry.featureNames.join(', ')}',
      );
    },
  );
}

@visibleForTesting
void scheduleTvProModuleInitialization({
  void Function(DeferredStartupFrameCallback callback)? addPostFrameCallback,
  void Function(String message)? log,
  Future<List<String>> Function()? initializeProModules,
}) {
  scheduleDeferredStartupTask(
    debugName: 'tv_pro_module_initialization',
    addPostFrameCallback: addPostFrameCallback,
    log: log,
    task: () async {
      final initialized =
          await (initializeProModules ??
              airo_pro_bootstrap.initializeProModules)();
      (log ?? debugPrint)(
        '📦 Initialized pro modules: ${initialized.join(', ')}',
      );
    },
  );
}

@visibleForTesting
Future<bool> seedTvDebugDefaultPlaylist(
  SharedPreferences prefs, {
  String playlistUrl = _debugDefaultPlaylistUrl,
  M3UParserService? parser,
}) async {
  return seedAiroTvDebugDefaultPlaylist(
    prefs,
    playlistUrl: playlistUrl,
    parser: parser,
  );
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
  return warmAiroTvDebugDefaultPlaylistCache(
    prefs,
    playlistUrl: playlistUrl,
    parser: parser,
  );
}

@visibleForTesting
SnapshotBackedCompactEpgRepository createTvCompactEpgRepository({
  Future<Directory> Function()? supportDirectoryProvider,
  CompactEpgRepository? fallback,
}) {
  return createAiroTvCompactEpgRepository(
    supportDirectoryProvider: supportDirectoryProvider,
    fallback: fallback,
  );
}

@visibleForTesting
void scheduleTvDebugDefaultEpgWarmup(
  SharedPreferences prefs, {
  required SnapshotBackedCompactEpgRepository repository,
  MutableXmltvCompactEpgRepository? windowRepository,
  String debugName = 'tv_debug_epg_warmup',
  String epgUrl = _debugDefaultEpgUrl,
  M3UParserService? parser,
  Dio? dio,
  Future<Directory> Function()? epgDownloadDirectoryProvider,
  DateTime Function()? clock,
  WidgetsBinding? binding,
  void Function(DeferredStartupFrameCallback callback)? addPostFrameCallback,
  void Function(String message)? log,
}) {
  if (epgUrl.isEmpty) return;

  scheduleDeferredStartupTask(
    debugName: debugName,
    binding: binding,
    addPostFrameCallback: addPostFrameCallback,
    log: log,
    task: () => warmTvDebugDefaultEpgCache(
      prefs,
      repository: repository,
      windowRepository: windowRepository,
      epgUrl: epgUrl,
      parser: parser,
      dio: dio,
      epgDownloadDirectoryProvider: epgDownloadDirectoryProvider,
      clock: clock,
    ),
  );
}

@visibleForTesting
Future<Duration?> warmTvDebugDefaultEpgCache(
  SharedPreferences prefs, {
  required SnapshotBackedCompactEpgRepository repository,
  MutableXmltvCompactEpgRepository? windowRepository,
  String epgUrl = _debugDefaultEpgUrl,
  M3UParserService? parser,
  Dio? dio,
  Future<Directory> Function()? epgDownloadDirectoryProvider,
  DateTime Function()? clock,
}) async {
  return warmAiroTvDebugDefaultEpgCache(
    prefs,
    repository: repository,
    windowRepository: windowRepository,
    epgUrl: epgUrl,
    parser: parser,
    dio: dio,
    epgDownloadDirectoryProvider: epgDownloadDirectoryProvider,
    clock: clock,
  );
}

/// Refreshes whatever XMLTV source the user has previously configured (a
/// no-op if none has been), updating [repository] in place — the
/// auto-refresh-on-launch counterpart to the guide screen's manual
/// "Save & Refresh" action.
@visibleForTesting
Future<void> refreshTvConfiguredXmltvSource(
  SharedPreferences prefs, {
  required MutableXmltvCompactEpgRepository repository,
  Dio? dio,
  XmltvSourceStore? sourceStore,
  Future<Directory> Function()? downloadDirectoryProvider,
}) async {
  return refreshAiroTvConfiguredXmltvSource(
    prefs,
    repository: repository,
    dio: dio,
    sourceStore: sourceStore,
    downloadDirectoryProvider: downloadDirectoryProvider,
  );
}

@visibleForTesting
void scheduleTvXmltvSourceRefresh(
  SharedPreferences prefs, {
  required MutableXmltvCompactEpgRepository repository,
  String debugName = 'xmltv_configured_source_refresh',
  Dio? dio,
  XmltvSourceStore? sourceStore,
  Future<Directory> Function()? downloadDirectoryProvider,
  WidgetsBinding? binding,
  void Function(DeferredStartupFrameCallback callback)? addPostFrameCallback,
  void Function(String message)? log,
}) {
  scheduleDeferredStartupTask(
    debugName: debugName,
    binding: binding,
    addPostFrameCallback: addPostFrameCallback,
    log: log,
    task: () => refreshTvConfiguredXmltvSource(
      prefs,
      repository: repository,
      dio: dio,
      sourceStore: sourceStore,
      downloadDirectoryProvider: downloadDirectoryProvider,
    ),
  );
}
