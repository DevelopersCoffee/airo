import 'package:airo_app/aika_ads/aika_ad_manager_binding.dart';
import 'package:airo_app/aika_ads/aika_ad_personalization.dart';
import 'package:airo_app/aika_ads/aika_ads.dart';
import 'package:airo_app/aika_ads/aika_ads_gate.dart';
import 'package:airo_app/aika_ads/aika_ads_runtime.dart';
import 'package:airo_app/core/providers/ads_personalization_consent_provider.dart';
import 'package:core_app_shell/core_app_shell.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AikaAdPersonalization.instance.enabled = true;
    final manager = AikaAdManager.test(
      sdk: AikaAdSdk(initializeFn: () async => true),
    );
    await manager.initialize(formFactor: AiroDeviceFormFactor.mobile);
    allowImmediateAikaPhoneAds(manager);
    bindAikaAdManagerForTests(manager);
    DeviceFormFactorDetector.debugFormFactorOverride = DeviceFormFactor.mobile;
  });

  tearDown(() {
    bindAikaAdManagerForTests(null);
    DeviceFormFactorDetector.debugFormFactorOverride = null;
    DeviceFormFactorDetector.clearCache();
    AikaAdPersonalization.instance.enabled = true;
  });

  testWidgets('arms browse and pause placements on phone after SDK init', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    late IptvAdPlacements placements;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              placements = ref.watch(aikaIptvAdPlacementsStateProvider);
              return const AikaAdsGate(child: Text('child'));
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('child'), findsOneWidget);
    expect(placements.browseCard, isNotNull);
    expect(placements.pauseCard, isNotNull);
  });

  testWidgets('reads ads personalization consent while arming', (tester) async {
    expect(AikaAdPersonalization.instance.enabled, isTrue);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(adsPersonalizationConsentStorageKey, false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: AikaAdsGate(child: SizedBox())),
      ),
    );
    await tester.pumpAndSettle();

    expect(AikaAdPersonalization.instance.enabled, isFalse);
  });
}
