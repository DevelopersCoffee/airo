/// Entrypoint for the standalone Airo IPTV mobile APK.
///
/// Build command:
/// ```bash
/// flutter build apk --debug \
///   --target=lib/main_airo_iptv.dart \
///   --dart-define=APP_VARIANT=iptv \
///   --dart-define=APP_PLATFORM=mobileIptv \
///   --dart-define=DEBUG_IPTV_PLAYLIST_URL=https://example.com/iptv_channels.m3u
/// ```
library;

import 'dart:async';

import 'package:airo_pro_bootstrap/airo_pro_bootstrap.dart'
    as airo_pro_bootstrap;
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/application/airo_tv_bootstrap.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/iptv/iptv_cast_provider_override.dart';

const _debugDefaultPlaylistUrl = String.fromEnvironment(
  'DEBUG_IPTV_PLAYLIST_URL',
);
const _debugDefaultEpgUrl = String.fromEnvironment('DEBUG_IPTV_EPG_URL');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final shouldWarmDebugPlaylist = await seedAiroTvDebugDefaultPlaylist(
    prefs,
    playlistUrl: _debugDefaultPlaylistUrl,
  );
  final mutableXmltvRepository = MutableXmltvCompactEpgRepository();
  final compactEpgRepository = createAiroTvCompactEpgRepository(
    fallback: mutableXmltvRepository,
  );

  runApp(
    ProviderScope(
      overrides: buildStandaloneIptvProviderOverrides(
        prefs: prefs,
        compactEpgRepository: compactEpgRepository,
        mutableXmltvRepository: mutableXmltvRepository,
      ),
      child: const AiroIptvApp(),
    ),
  );

  scheduleStandaloneIptvWarmups(
    prefs,
    compactEpgRepository: compactEpgRepository,
    mutableXmltvRepository: mutableXmltvRepository,
    shouldWarmDebugPlaylist: shouldWarmDebugPlaylist,
  );
}

@visibleForTesting
List<Override> buildStandaloneIptvProviderOverrides({
  required SharedPreferences prefs,
  required CompactEpgRepository compactEpgRepository,
  required MutableXmltvCompactEpgRepository mutableXmltvRepository,
}) {
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    compactEpgRepositoryProvider.overrideWithValue(compactEpgRepository),
    mutableXmltvCompactEpgRepositoryProvider.overrideWithValue(
      mutableXmltvRepository,
    ),
    realIptvCastControllerOverride(),
  ];
}

@visibleForTesting
void scheduleStandaloneIptvWarmups(
  SharedPreferences prefs, {
  required CompactEpgRepository compactEpgRepository,
  required MutableXmltvCompactEpgRepository mutableXmltvRepository,
  required bool shouldWarmDebugPlaylist,
  String playlistUrl = _debugDefaultPlaylistUrl,
  String epgUrl = _debugDefaultEpgUrl,
  void Function(FrameCallback callback)? addPostFrameCallback,
  void Function(String message)? log,
  Future<List<String>> Function()? initializeProModules,
}) {
  final schedule =
      addPostFrameCallback ?? WidgetsBinding.instance.addPostFrameCallback;
  final logger = log ?? debugPrint;
  final initializePro =
      initializeProModules ?? airo_pro_bootstrap.initializeProModules;
  schedule((_) {
    _runStandaloneWarmup(
      () async {
        await initializePro();
      },
      logger: logger,
      failureMessage: 'Standalone IPTV pro bootstrap skipped',
    );

    if (shouldWarmDebugPlaylist) {
      _runStandaloneWarmup(
        () => warmAiroTvDebugDefaultPlaylistCache(
          prefs,
          playlistUrl: playlistUrl,
        ),
        logger: logger,
        failureMessage: 'Standalone IPTV playlist warmup skipped',
      );
    }

    if (epgUrl.isNotEmpty) {
      _runStandaloneWarmup(
        () async {
          await warmAiroTvDebugDefaultEpgCache(
            prefs,
            repository: compactEpgRepository,
            windowRepository: mutableXmltvRepository,
            epgUrl: epgUrl,
          );
        },
        logger: logger,
        failureMessage: 'Standalone IPTV debug EPG warmup skipped',
      );
    }

    _runStandaloneWarmup(
      () => refreshAiroTvConfiguredXmltvSource(
        prefs,
        repository: mutableXmltvRepository,
      ),
      logger: logger,
      failureMessage: 'Standalone IPTV XMLTV refresh skipped',
    );
  });
}

void _runStandaloneWarmup(
  Future<void> Function() task, {
  required void Function(String message) logger,
  required String failureMessage,
}) {
  unawaited(
    (() async {
      try {
        await task();
      } catch (error) {
        logger('$failureMessage: $error');
      }
    })(),
  );
}

class AiroIptvApp extends StatelessWidget {
  const AiroIptvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Airo IPTV',
      theme: AppTheme.defaultLight,
      darkTheme: AppTheme.defaultDark,
      themeMode: AppTheme.defaultThemeMode,
      debugShowCheckedModeBanner: false,
      home: const IPTVScreen(),
    );
  }
}
