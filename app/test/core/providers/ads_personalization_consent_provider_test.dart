import 'package:airo_app/aika_ads/aika_ad_personalization.dart';
import 'package:airo_app/core/providers/ads_personalization_consent_provider.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AikaAdPersonalization.instance.enabled = true;
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to personalized ads when unset', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(loadAdsPersonalizationConsent(prefs), isTrue);
    expect(buildAikaAdRequest().nonPersonalizedAds, isNull);
  });

  test('provider persists opt-out and applies NPA to ad requests', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container
        .read(adsPersonalizationConsentProvider.notifier)
        .setEnabled(false);

    expect(container.read(adsPersonalizationConsentProvider), isFalse);
    expect(
      prefs.getBool(adsPersonalizationConsentStorageKey),
      isFalse,
    );
    expect(AikaAdPersonalization.instance.enabled, isFalse);
    expect(buildAikaAdRequest().nonPersonalizedAds, isTrue);
    expect(buildAikaAdRequest().extras, containsPair('npa', '1'));
  });
}
