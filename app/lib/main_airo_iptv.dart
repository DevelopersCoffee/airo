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

import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/iptv/iptv_cast_provider_override.dart';

const _debugDefaultPlaylistUrl = String.fromEnvironment(
  'DEBUG_IPTV_PLAYLIST_URL',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await _seedDebugDefaultPlaylist(prefs);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        realIptvCastControllerOverride(),
      ],
      child: const AiroIptvApp(),
    ),
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

Future<void> _seedDebugDefaultPlaylist(SharedPreferences prefs) async {
  if (_debugDefaultPlaylistUrl.isEmpty) return;

  final parser = M3UParserService(dio: Dio(), prefs: prefs);
  if (parser.getPlaylistUrl() != null) return;

  await parser.setPlaylistUrl(_debugDefaultPlaylistUrl);
}
