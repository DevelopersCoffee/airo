import 'package:airo_app/aika_ads/aika_ad_personalization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AikaAdPersonalization.instance.enabled = true;
  });

  test('buildAikaAdRequest uses NPA when personalization is disabled', () {
    AikaAdPersonalization.instance.enabled = false;

    final request = buildAikaAdRequest();

    expect(request.nonPersonalizedAds, isTrue);
    expect(request.extras, containsPair('npa', '1'));
  });

  test('buildAikaAdRequest stays personalized when enabled', () {
    AikaAdPersonalization.instance.enabled = true;

    final request = buildAikaAdRequest();

    expect(request.nonPersonalizedAds, isNull);
    expect(request.extras, isNull);
  });
}
