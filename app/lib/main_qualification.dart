/// Qualification entrypoint for iPad Air QA UI/UX validation testing.
///
/// Build and run command:
/// ```bash
/// flutter run --target=lib/main_qualification.dart
/// ```
library;

import 'package:core_product_shell/core_product_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:platform_device_qualification/platform_device_qualification.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/error/global_error_handler.dart';
import 'core/platform/device_form_factor.dart';
import 'core/pro/pro_bootstrap_runner.dart';
import 'features/iptv/iptv_cast_provider_override.dart';

const _defaultPlaylistUrl = 'https://iptv-org.github.io/iptv/index.m3u';

void main() {
  late SharedPreferences prefs;
  late ModuleRegistry registry;

  AiroBootstrap.run(
    shell: ShellId.qualification,
    errorHandler: ErrorHandlerPolicy.enabled(GlobalErrorHandler.initialize),
    // The qualification harness drives device UI validation, not auth or
    // cloud-backed flows — nothing here reads Firebase state.
    firebase: const FirebasePolicy.skip(
      reason: 'QA/UX qualification harness has no auth or cloud surface',
    ),
    composeApp: () async {
      prefs = await SharedPreferences.getInstance();
      await _seedDefaultPlaylist(prefs);
      registry = buildQualificationModuleRegistry();

      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          realIptvCastControllerOverride(),
          ...registry.allProviderOverrides,
        ],
        child: const AiroIptvQualificationApp(),
      );
    },
    afterRunApp: () => scheduleDeferredProBootstrap(),
  );
}

/// Builds the qualification harness's module registry.
///
/// Empty today: the harness embeds [IPTVScreen] directly inside
/// [DeviceQualificationOverlay] rather than mounting `feature_iptv`'s module
/// routes through a router, so [IptvFeatureModule] (scoped to
/// [ShellId.mobile] and [ShellId.tv] only) has nothing to contribute here.
/// Kept as a real [ModuleRegistry] rather than omitted so this shell goes
/// through the same [AiroBootstrap] contract as every shippable shell
/// (#1680) and is ready for a module to register against
/// [ShellId.qualification] if this harness ever needs one.
@visibleForTesting
ModuleRegistry buildQualificationModuleRegistry() =>
    ModuleRegistry(shell: ShellId.qualification);

class AiroIptvQualificationApp extends StatelessWidget {
  const AiroIptvQualificationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Airo TV QA Qualification',
      theme: AiroTheme.defaultLight,
      darkTheme: AiroTheme.defaultDark,
      themeMode: AiroTheme.defaultThemeMode,
      debugShowCheckedModeBanner: false,
      home: DeviceQualificationOverlay(
        defaultPlaylistUrl: _defaultPlaylistUrl,
        autoCycle: true,
        onFormFactorOverride: (formFactor, tvPlatform) {
          if (formFactor == 'tv') {
            DeviceFormFactorDetector.debugFormFactorOverride =
                DeviceFormFactor.tv;
          } else if (formFactor == 'tablet') {
            DeviceFormFactorDetector.debugFormFactorOverride =
                DeviceFormFactor.tablet;
          } else {
            DeviceFormFactorDetector.debugFormFactorOverride =
                DeviceFormFactor.mobile;
          }

          if (tvPlatform == 'fire_tv') {
            DeviceFormFactorDetector.debugTvPlatformOverride =
                TvPlatform.fireTv;
          } else if (tvPlatform == 'android_tv') {
            DeviceFormFactorDetector.debugTvPlatformOverride =
                TvPlatform.androidTv;
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
