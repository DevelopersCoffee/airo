import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Phone-only ads personalization gate for Aika Stream.
///
/// When disabled, ad loads request non-personalized ads (NPA) from AdMob.
class AikaAdPersonalization {
  AikaAdPersonalization._();

  static final AikaAdPersonalization instance = AikaAdPersonalization._();

  bool enabled = true;
}

AdRequest buildAikaAdRequest() {
  if (AikaAdPersonalization.instance.enabled) {
    return const AdRequest();
  }
  return const AdRequest(
    nonPersonalizedAds: true,
    extras: {'npa': '1'},
  );
}
