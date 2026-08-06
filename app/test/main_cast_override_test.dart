import 'package:airo_app/core/app/main_provider_overrides.dart';
import 'package:airo_app/main.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mobile entrypoint installs the real Android Cast controller', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: buildMainProviderOverrides(
        prefs: prefs,
        epgReminderGateway: const UnavailableEpgReminderNotificationGateway(),
        moduleRegistry: buildMainModuleRegistry(),
      ),
    );
    addTearDown(container.dispose);

    expect(
      container.read(airoCastControllerProvider),
      isA<FlutterChromeCastController>(),
    );
  });

  test('mobile entrypoint keeps Cast unavailable on macOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: buildMainProviderOverrides(
        prefs: prefs,
        epgReminderGateway: const UnavailableEpgReminderNotificationGateway(),
        moduleRegistry: buildMainModuleRegistry(),
      ),
    );
    addTearDown(container.dispose);

    expect(
      container.read(airoCastControllerProvider),
      isA<UnavailableAiroCastController>(),
    );
  });
}
