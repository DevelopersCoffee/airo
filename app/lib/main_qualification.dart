/// Qualification entrypoint for iPad Air QA UI/UX validation testing.
///
/// Build and run command:
/// ```bash
/// flutter run --target=lib/main_qualification.dart
/// ```
library;

import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:platform_device_qualification/platform_device_qualification.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/platform/device_form_factor.dart';
import 'features/iptv/iptv_cast_provider_override.dart';

const _defaultPlaylistUrl = 'https://iptv-org.github.io/iptv/index.m3u';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await _seedDefaultPlaylist(prefs);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        realIptvCastControllerOverride(),
      ],
      child: const AiroIptvQualificationApp(),
    ),
  );
}

class AiroIptvQualificationApp extends StatelessWidget {
  const AiroIptvQualificationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Airo TV QA Qualification',
      theme: AppTheme.defaultLight,
      darkTheme: AppTheme.defaultDark,
      themeMode: AppTheme.defaultThemeMode,
      debugShowCheckedModeBanner: false,
      home: DeviceQualificationOverlay(
        defaultPlaylistUrl: _defaultPlaylistUrl,
        onFormFactorOverride: (formFactor, tvPlatform) {
          if (formFactor == 'tv') {
            DeviceFormFactorDetector.debugFormFactorOverride = DeviceFormFactor.tv;
          } else if (formFactor == 'tablet') {
            DeviceFormFactorDetector.debugFormFactorOverride = DeviceFormFactor.tablet;
          } else {
            DeviceFormFactorDetector.debugFormFactorOverride = DeviceFormFactor.mobile;
          }

          if (tvPlatform == 'fire_tv') {
            DeviceFormFactorDetector.debugTvPlatformOverride = TvPlatform.fireTv;
          } else if (tvPlatform == 'android_tv') {
            DeviceFormFactorDetector.debugTvPlatformOverride = TvPlatform.androidTv;
          } else {
            DeviceFormFactorDetector.debugTvPlatformOverride = null;
          }
        },
        child: const IPTVScreen(),
      ),
    );
  }
}

Future<void> _seedDefaultPlaylist(SharedPreferences prefs) async {
  final parser = M3UParserService(dio: Dio(), prefs: prefs);
  // Always overwrite or seed default playlist URL for testing
  await parser.setPlaylistUrl(_defaultPlaylistUrl);
}
