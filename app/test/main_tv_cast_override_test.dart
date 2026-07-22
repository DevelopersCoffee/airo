import 'package:airo_app/main_tv.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'TV entrypoint wires a real cast controller — phones running the TV build '
    'render the mobile IPTV screen whose cast UI needs it',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mutableRepo = MutableXmltvCompactEpgRepository();

      final container = ProviderContainer(
        overrides: buildTvProviderOverrides(
          prefs: prefs,
          compactEpgRepository: createTvCompactEpgRepository(
            fallback: mutableRepo,
          ),
          mutableXmltvRepository: mutableRepo,
        ),
      );
      addTearDown(container.dispose);

      expect(
        container.read(airoCastControllerProvider),
        isA<FlutterChromeCastController>(),
      );
    },
  );

  test(
    'TV entrypoint keeps Cast no-op on macOS per release contract',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mutableRepo = MutableXmltvCompactEpgRepository();

      final container = ProviderContainer(
        overrides: buildTvProviderOverrides(
          prefs: prefs,
          compactEpgRepository: createTvCompactEpgRepository(
            fallback: mutableRepo,
          ),
          mutableXmltvRepository: mutableRepo,
        ),
      );
      addTearDown(container.dispose);

      expect(
        container.read(airoCastControllerProvider),
        isA<UnavailableAiroCastController>(),
      );
    },
  );
}
