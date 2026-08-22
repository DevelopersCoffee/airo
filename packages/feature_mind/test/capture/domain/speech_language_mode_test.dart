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

  test('pinned languages load multilingual weights and pin whisper codes', () {
    expect(SpeechLanguageMode.hindi.includesMultilingualModel, isTrue);
    expect(SpeechLanguageMode.hindi.processLanguageCode, 'hi');
    expect(SpeechLanguageMode.marathi.processLanguageCode, 'mr');
    expect(SpeechLanguageMode.spanish.processLanguageCode, 'es');
    expect(SpeechLanguageMode.japanese.processLanguageCode, 'ja');
    expect(SpeechLanguageMode.arabic.processLanguageCode, 'ar');
  });

  test('fromStorageValue and fromWhisperCode round-trip the catalog', () {
    expect(
      SpeechLanguageMode.fromStorageValue('hindi'),
      SpeechLanguageMode.hindi,
    );
    expect(
      SpeechLanguageMode.fromWhisperCode('pt'),
      SpeechLanguageMode.portuguese,
    );
    expect(
      SpeechLanguageMode.fromStorageValue('not-a-language'),
      SpeechLanguageMode.auto,
    );
    expect(SpeechLanguageMode.fromWhisperCode(null), SpeechLanguageMode.auto);
  });

  test('the catalog covers Indic and major world languages', () {
    expect(SpeechLanguageMode.values.length, greaterThanOrEqualTo(40));
    expect(
      SpeechLanguageMode.values.map((mode) => mode.whisperCode),
      containsAll(['hi', 'mr', 'ta', 'es', 'fr', 'de', 'zh', 'ar']),
    );
  });
}
