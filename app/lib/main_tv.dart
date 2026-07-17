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
import 'dart:isolate';

import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app/airo_tv_app.dart';
import 'core/config/platform_features.dart';
import 'core/error/global_error_handler.dart';
import 'core/features/feature_registry.dart';
import 'core/platform/device_form_factor.dart';
import 'core/providers/app_theme_provider.dart';
import 'core/startup/deferred_startup_task.dart';
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

  runApp(
    ProviderScope(
      overrides: [
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
        realIptvCastControllerOverride(),
        ...FeatureRegistry.allProviderOverrides,
      ],
      child: const AiroTvApp(),
    ),
  );

  scheduleTvFirebaseInitialization();
  scheduleTvFeatureInitialization();
  if (shouldWarmDebugPlaylist) {
    scheduleTvDebugDefaultPlaylistWarmup(prefs);
  }
  scheduleTvDebugDefaultEpgWarmup(prefs, repository: compactEpgRepository);
  scheduleTvXmltvSourceRefresh(prefs, repository: mutableXmltvRepository);
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

@visibleForTesting
SnapshotBackedCompactEpgRepository createTvCompactEpgRepository({
  Future<Directory> Function()? supportDirectoryProvider,
  CompactEpgRepository? fallback,
}) {
  final directoryProvider =
      supportDirectoryProvider ?? getApplicationSupportDirectory;
  return SnapshotBackedCompactEpgRepository(
    store: FileCompactEpgSnapshotStore(
      fileProvider: () async {
        final supportDir = await directoryProvider();
        return File('${supportDir.path}/epg/compact_epg_snapshot.json');
      },
    ),
    fallback: fallback ?? const EmptyCompactEpgRepository(),
  );
}

@visibleForTesting
void scheduleTvDebugDefaultEpgWarmup(
  SharedPreferences prefs, {
  required SnapshotBackedCompactEpgRepository repository,
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
  String epgUrl = _debugDefaultEpgUrl,
  M3UParserService? parser,
  Dio? dio,
  Future<Directory> Function()? epgDownloadDirectoryProvider,
  DateTime Function()? clock,
}) async {
  final normalizedEpgUrl = epgUrl.trim();
  if (normalizedEpgUrl.isEmpty) return null;

  final uri = Uri.tryParse(normalizedEpgUrl);
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    throw ArgumentError.value(
      epgUrl,
      'epgUrl',
      'Enter a valid HTTP(S) XMLTV EPG URL.',
    );
  }

  final http = dio ?? Dio();
  final parserService = parser ?? M3UParserService(dio: http, prefs: prefs);
  final channels = await parserService.fetchPlaylist();
  if (channels.isEmpty) return null;

  final downloadDirectory =
      await (epgDownloadDirectoryProvider ?? getTemporaryDirectory)();
  await downloadDirectory.create(recursive: true);
  final guideFile = File(
    '${downloadDirectory.path}/airo_tv_debug_epg_${DateTime.now().microsecondsSinceEpoch}.xml',
  );

  try {
    await http.download(
      normalizedEpgUrl,
      guideFile.path,
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    if (!await guideFile.exists() || await guideFile.length() == 0) {
      return null;
    }

    final stopwatch = Stopwatch()..start();
    final now = (clock ?? DateTime.now)().toUtc();
    final snapshot = await Isolate.run<CompactEpgSlice>(
      () async => _buildTvCompactEpgSnapshot(
        xmltvPath: guideFile.path,
        now: now,
        channels: channels,
      ),
      debugName: 'tv_debug_epg_warmup',
    );
    await repository.saveSnapshot(snapshot);
    stopwatch.stop();
    return stopwatch.elapsed;
  } finally {
    if (await guideFile.exists()) {
      await guideFile.delete();
    }
  }
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
  final refreshService = XmltvSourceRefreshService(
    dio: dio ?? Dio(),
    sourceStore: sourceStore ?? XmltvSourceStore(PreferencesStore(prefs)),
    repository: repository,
    downloadDirectoryProvider:
        downloadDirectoryProvider ?? getTemporaryDirectory,
  );
  await refreshService.refreshConfiguredSource();
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

Future<CompactEpgSlice> _buildTvCompactEpgSnapshot({
  required String xmltvPath,
  required DateTime now,
  required List<IPTVChannel> channels,
}) async {
  final aliasesByChannel = {
    for (final channel in channels) channel.id: _xmltvGuideAliasesFor(channel),
  };
  final guideChannelIds = aliasesByChannel.values
      .expand((aliases) => aliases)
      .toSet()
      .toList(growable: false);
  final channelNamesByGuideId = {
    for (final channel in channels)
      for (final alias in aliasesByChannel[channel.id]!) alias: channel.name,
  };
  final guideRepository =
      await XmltvCompactEpgRepository.fromXmltvCurrentNextFileNative(
        path: xmltvPath,
        ingestedAt: now,
        channelIds: guideChannelIds,
        now: now,
        sourceRef: CompactEpgSourceRef.redacted('debug-tv-epg'),
        channelNamesById: channelNamesByGuideId,
      );
  final guideSlice = await guideRepository.loadCurrentNext(
    channelIds: guideChannelIds,
    now: now,
  );
  final entries = <CompactEpgEntry>[];

  for (final channel in channels) {
    for (final alias in aliasesByChannel[channel.id]!) {
      final guideEntry = guideSlice.entryForChannel(alias);
      if (guideEntry == null || !guideEntry.hasPrograms) {
        continue;
      }
      entries.add(
        CompactEpgEntry(
          channelId: channel.id,
          channelName: channel.name,
          channelNumber: channel.tvgId?.toString(),
          current: guideEntry.current,
          next: guideEntry.next,
          sourceRef: guideEntry.sourceRef,
        ),
      );
      break;
    }
  }

  return CompactEpgSlice(
    entries: entries,
    generatedAt: guideSlice.generatedAt,
    expiresAt: guideSlice.expiresAt,
    source: entries.isEmpty
        ? CompactEpgSliceSource.unavailable
        : CompactEpgSliceSource.localCache,
  );
}

List<String> _xmltvGuideAliasesFor(IPTVChannel channel) {
  final aliases = <String>{
    channel.id,
    if (channel.tvgId != null) channel.tvgId.toString(),
    if (channel.tvgName != null) channel.tvgName!,
    channel.name,
    ...channel.altNames,
  };
  return aliases
      .map((alias) => alias.trim())
      .where((alias) => alias.isNotEmpty)
      .toList(growable: false);
}
