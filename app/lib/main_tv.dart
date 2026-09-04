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

import 'package:airo_pro_bootstrap/airo_pro_bootstrap.dart' as pro_bootstrap;
import 'package:core_analytics/core_analytics.dart';
import 'package:core_data/core_data.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app/airo_tv_app.dart';
import 'core/audio/tv_audio_service.dart';
import 'core/config/firebase_status.dart';
import 'core/config/platform_features.dart';
import 'core/error/global_error_handler.dart';
import 'core/platform/device_form_factor.dart';
import 'core/providers/app_theme_provider.dart';
import 'core/providers/streaming_telemetry_consent_provider.dart';
import 'core/startup/app_startup_tasks.dart';
import 'core/startup/deferred_startup_task.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'features/iptv/iptv_cast_provider_override.dart';
import 'features/iptv/iptv_feature_module.dart';
import 'firebase_options.dart';

typedef TvDebugPlaylistLoader =
    Future<List<IPTVChannel>> Function(
      String playlistUrl,
      Dio dio,
      SharedPreferences prefs,
    );

const _debugDefaultPlaylistUrl = String.fromEnvironment(
  'DEBUG_IPTV_PLAYLIST_URL',
);
const _debugDefaultEpgUrl = String.fromEnvironment('DEBUG_IPTV_EPG_URL');
const _bundledPlaylistUrl = String.fromEnvironment('IPTV_DATA_PLAYLIST_URL');
const _bundledManifestUrl = String.fromEnvironment('IPTV_DATA_MANIFEST_URL');
const _bundledGuideCountry = String.fromEnvironment(
  'IPTV_DATA_COUNTRY',
  defaultValue: 'IN',
);

void main() {
  late SharedPreferences prefs;
  late ModuleRegistry moduleRegistry;
  late SnapshotBackedCompactEpgRepository compactEpgRepository;
  late MutableXmltvCompactEpgRepository mutableXmltvRepository;
  late bool shouldWarmDebugPlaylist;

  AiroBootstrap.run(
    shell: ShellId.tv,
    // Must run before anything else can allocate images (load-bearing
    // ordering, #1680).
    earlyPhase: () {
      AiroImageCacheBudget.configureAndroidTv();
      AiroMemoryPressureObserver();
    },
    errorHandler: ErrorHandlerPolicy.enabled(GlobalErrorHandler.initialize),
    // Deferred: a slow or unreachable Firebase backend must never delay a TV
    // boot straight to the guide.
    firebase: FirebasePolicy.deferred(
      options: DefaultFirebaseOptions.currentPlatform,
      isConfigured: DefaultFirebaseOptions.isCurrentPlatformConfigured,
      variantName: DefaultFirebaseOptions.currentVariant.name,
      onResult: (initialized) => isFirebaseInitialized = initialized,
    ),
    // Load-bearing ordering (#1680): image-cache budget (above, earlyPhase)
    // → system chrome → prefs → audio service → runApp. Preserved exactly by
    // keeping every step inside this one hook, in this order.
    composeApp: () async {
      await configureTvSystemChrome();

      debugPrint('🖥️ Starting Aika Stream (${PlatformFeatures.platformName})');
      debugPrint(
        '📺 Features: '
        '${PlatformFeatures.enabledFeatures.map((f) => f.name).join(', ')}',
      );

      // Initialize SharedPreferences for IPTV caching
      prefs = await SharedPreferences.getInstance();

      // Phase 1 streaming telemetry (F7.1/F7.5) -- opt-in only, nothing
      // recorded until the user grants it in Settings. Constructed with
      // whatever was last persisted (withheld on a fresh install) and wired
      // into PlatformMediaLogger before anything else can call
      // PlatformMediaLogger.analytics(); the settings toggle later calls
      // .updateConsent() on this exact instance via
      // streamingTelemetryServiceProvider's override below.
      final streamingTelemetryService = AiroLocalDiagnosticsAnalyticsService(
        consent: loadStreamingTelemetryConsent(prefs),
      );
      PlatformMediaLogger.setAnalyticsService(streamingTelemetryService);

      shouldWarmDebugPlaylist = await seedTvDebugDefaultPlaylist(prefs);
      mutableXmltvRepository = MutableXmltvCompactEpgRepository();
      compactEpgRepository = createTvCompactEpgRepository(
        fallback: mutableXmltvRepository,
      );

      // Compose the focused TV product through the shared shell contract.
      moduleRegistry = buildTvModuleRegistry();
      debugPrint(
        '📦 Registered features: ${moduleRegistry.moduleIds.join(', ')}',
      );

      // Initialize the OS media session (media notification + lock-screen
      // controls) on Android, where audio_service's foreground service is
      // what keeps live audio alive — and controllable — after a Home press
      // (#980). Skipped elsewhere: web has no audio_service host, and
      // desktop dev builds don't run the Android foreground service.
      //
      // Bounded: a misbehaving OS media service must never block app
      // startup — on a timeout/failure the app boots normally without
      // media-session controls (the pre-#980 behavior).
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

      return ProviderScope(
        overrides: buildTvProviderOverrides(
          prefs: prefs,
          compactEpgRepository: compactEpgRepository,
          mutableXmltvRepository: mutableXmltvRepository,
          tvAudioHandler: tvAudioHandler,
          moduleRegistry: moduleRegistry,
          streamingTelemetryService: streamingTelemetryService,
        ),
        child: const AiroTvApp(),
      );
    },
    afterRunApp: () {
      scheduleTvFeatureInitialization(moduleRegistry: moduleRegistry);
      scheduleDeferredProBootstrap();
      if (shouldWarmDebugPlaylist) {
        scheduleTvDebugDefaultPlaylistWarmup(prefs);
      }
      scheduleTvDebugDefaultEpgWarmup(
        prefs,
        repository: compactEpgRepository,
        windowRepository: mutableXmltvRepository,
      );
      if (_bundledPlaylistUrl.isNotEmpty && _bundledManifestUrl.isNotEmpty) {
        scheduleTvBundledSystemGuideRefresh(
          prefs,
          repository: mutableXmltvRepository,
        );
      } else {
        scheduleTvXmltvSourceRefresh(prefs, repository: mutableXmltvRepository);
      }
    },
  );
}

/// Builds the exact module composition shipped by the focused TV entrypoint.
///
/// A fresh registry is returned for each bootstrap/test so product composition
/// cannot leak through static state.
@visibleForTesting
ModuleRegistry buildTvModuleRegistry() {
  return ModuleRegistry(shell: ShellId.tv)..register(IptvFeatureModule());
}

@visibleForTesting
List<Override> buildTvProviderOverrides({
  required SharedPreferences prefs,
  required CompactEpgRepository compactEpgRepository,
  required MutableXmltvCompactEpgRepository mutableXmltvRepository,
  TvAudioHandler? tvAudioHandler,
  ModuleRegistry? moduleRegistry,
  List<Override>? proProviderOverrides,
  String debugPlaylistUrl = _debugDefaultPlaylistUrl,
  TvDebugPlaylistLoader? debugPlaylistLoader,
  AiroLocalDiagnosticsAnalyticsService? streamingTelemetryService,
}) {
  final registry = moduleRegistry ?? buildTvModuleRegistry();
  final handler = tvAudioHandler;
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    if (streamingTelemetryService != null)
      streamingTelemetryServiceProvider.overrideWithValue(
        streamingTelemetryService,
      ),
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
    if (debugPlaylistUrl.isNotEmpty)
      iptvChannelsProvider.overrideWith((ref) {
        return (debugPlaylistLoader ?? loadTvDebugPlaylistForWeb)(
          debugPlaylistUrl,
          ref.watch(dioProvider),
          prefs,
        );
      }),
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
    ...registry.allProviderOverrides,
    ...(proProviderOverrides ?? pro_bootstrap.createProviderOverrides()),
  ];
}

/// Loads the controlled browser-validation playlist without native file I/O.
///
/// Production builds never set [DEBUG_IPTV_PLAYLIST_URL], so this override is
/// absent there. The checked-in fixture is capped below the repository's
/// 50-KB worker threshold, so the deterministic synchronous test helper is
/// valid here; larger content is rejected instead of reaching the main
/// isolate.
@visibleForTesting
Future<List<IPTVChannel>> loadTvDebugPlaylistForWeb(
  String playlistUrl,
  Dio dio,
  SharedPreferences prefs,
) async {
  final response = await dio.get<String>(
    playlistUrl,
    options: Options(responseType: ResponseType.plain),
  );
  final content = response.data;
  if (content == null || content.trim().isEmpty) return const [];
  if (content.length > 50 * 1024) {
    throw StateError('TV browser validation playlist exceeds 50 KB.');
  }
  final playlistUri = Uri.parse(playlistUrl);
  final localOrigin = '${playlistUri.origin}/';
  const parserSafeOrigin = 'https://store-fixture.example/';
  final usesLocalFixture =
      playlistUri.host == '127.0.0.1' ||
      playlistUri.host == '::1' ||
      playlistUri.host == 'localhost';
  final parserInput = usesLocalFixture
      ? content.replaceAll(localOrigin, parserSafeOrigin)
      : content;
  var channels = M3UParserService(dio: dio, prefs: prefs).parseM3U(parserInput);
  if (usesLocalFixture) {
    channels = channels
        .map((channel) {
          final streamUrl = channel.streamUrl.replaceFirst(
            parserSafeOrigin,
            localOrigin,
          );
          return channel.copyWith(
            streamUrl: streamUrl,
            sources: [streamUrl],
            streamSources: [ChannelStreamSource(url: streamUrl)],
          );
        })
        .toList(growable: false);
  }
  debugPrint(
    '📺 Loaded ${channels.length} controlled browser-validation channels',
  );
  return channels;
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
void scheduleTvFeatureInitialization({
  required ModuleRegistry moduleRegistry,
  void Function(DeferredStartupFrameCallback callback)? addPostFrameCallback,
  void Function(String message)? log,
}) {
  scheduleDeferredStartupTask(
    debugName: 'tv_feature_initialization',
    addPostFrameCallback: addPostFrameCallback,
    log: log,
    task: () async {
      await moduleRegistry.initializeAll();
      (log ?? debugPrint)(
        '📦 Initialized features: ${moduleRegistry.moduleIds.join(', ')}',
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

@visibleForTesting
void scheduleTvBundledSystemGuideRefresh(
  SharedPreferences prefs, {
  required MutableXmltvCompactEpgRepository repository,
  String bundledPlaylistUrl = _bundledPlaylistUrl,
  String manifestUrl = _bundledManifestUrl,
  String country = _bundledGuideCountry,
  M3UParserService? parser,
  Dio? dio,
  XmltvSourceStore? sourceStore,
  Future<Directory> Function()? downloadDirectoryProvider,
  WidgetsBinding? binding,
  void Function(DeferredStartupFrameCallback callback)? addPostFrameCallback,
  void Function(String message)? log,
}) {
  if (bundledPlaylistUrl.isEmpty || manifestUrl.isEmpty) return;
  scheduleDeferredStartupTask(
    debugName: 'xmltv_bundled_system_guide_refresh',
    binding: binding,
    addPostFrameCallback: addPostFrameCallback,
    log: log,
    task: () async {
      await refreshTvConfiguredXmltvSource(
        prefs,
        repository: repository,
        dio: dio,
        sourceStore: sourceStore,
        downloadDirectoryProvider: downloadDirectoryProvider,
      );
      await refreshAiroTvBundledSystemGuide(
        prefs,
        repository: repository,
        bundledPlaylistUrl: bundledPlaylistUrl,
        manifestUrl: manifestUrl,
        country: country,
        parser: parser,
        dio: dio,
        sourceStore: sourceStore,
        downloadDirectoryProvider: downloadDirectoryProvider,
      );
    },
  );
}
