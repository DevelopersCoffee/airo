import 'package:feature_mind/src/capture/domain/speech_language_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Auto is the product default and requests multilingual weights', () {
    expect(SpeechLanguageMode.fallback, SpeechLanguageMode.auto);
    expect(SpeechLanguageMode.auto.includesMultilingualModel, isTrue);
    expect(SpeechLanguageMode.auto.processLanguageCode, isNull);
    expect(SpeechLanguageMode.auto.badgeLabel, 'Multilingual · auto-detect');
  });

  test('English opt-in skips multilingual download and pins en', () {
    expect(SpeechLanguageMode.english.includesMultilingualModel, isFalse);
    expect(SpeechLanguageMode.english.processLanguageCode, 'en');
    expect(SpeechLanguageMode.english.badgeLabel, 'English');
  });
}
