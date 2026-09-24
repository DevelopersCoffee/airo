import 'package:airo_app/aika_ads/aika_ad_personalization.dart';
import 'package:feature_iptv/feature_iptv.dart' show sharedPreferencesProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// When true, AdMob may use the advertising ID for personalized ads. When
/// false, ad requests use the NPA flag only.
const adsPersonalizationConsentStorageKey = 'ads_personalization_enabled';

bool loadAdsPersonalizationConsent(SharedPreferences prefs) {
  return prefs.getBool(adsPersonalizationConsentStorageKey) ?? true;
}

void applyAdsPersonalizationConsent(bool enabled) {
  AikaAdPersonalization.instance.enabled = enabled;
}

class AdsPersonalizationConsentNotifier extends StateNotifier<bool> {
  AdsPersonalizationConsentNotifier(this._ref) : super(true) {
    _loadFromStorage();
  }

  final Ref _ref;

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    applyAdsPersonalizationConsent(enabled);
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      await prefs.setBool(adsPersonalizationConsentStorageKey, enabled);
    } catch (_) {
      // Best-effort persistence -- consent still applies for this session.
    }
  }

  void _loadFromStorage() {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final enabled = loadAdsPersonalizationConsent(prefs);
      state = enabled;
      applyAdsPersonalizationConsent(enabled);
    } catch (_) {
      applyAdsPersonalizationConsent(true);
    }
  }
}

final adsPersonalizationConsentProvider =
    StateNotifierProvider<AdsPersonalizationConsentNotifier, bool>(
      (ref) => AdsPersonalizationConsentNotifier(ref),
    );
