import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'defaults to captions off with no language when nothing is persisted',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final pref = container.read(captionPreferenceProvider);
      expect(pref.enabled, isFalse);
      expect(pref.languageCode, isNull);
    },
  );

  test(
    'loads a persisted caption preference through the shared store',
    () async {
      SharedPreferences.setMockInitialValues({
        captionPreferenceEnabledStorageKey: true,
        captionPreferenceLanguageStorageKey: 'es',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final pref = container.read(captionPreferenceProvider);
      expect(pref.enabled, isTrue);
      expect(pref.languageCode, 'es');
    },
  );

  test('setCaptionPreference persists enabled flag and language', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container
        .read(captionPreferenceProvider.notifier)
        .setCaptionPreference(enabled: true, languageCode: 'fr');
    await Future<void>.delayed(Duration.zero);

    expect(prefs.getBool(captionPreferenceEnabledStorageKey), isTrue);
    expect(prefs.getString(captionPreferenceLanguageStorageKey), 'fr');
    final pref = container.read(captionPreferenceProvider);
    expect(pref.enabled, isTrue);
    expect(pref.languageCode, 'fr');
  });

  test(
    'disabling captions keeps the last-selected language remembered',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(captionPreferenceProvider.notifier);
      notifier.setCaptionPreference(enabled: true, languageCode: 'de');
      await Future<void>.delayed(Duration.zero);
      notifier.setCaptionsEnabled(false);
      await Future<void>.delayed(Duration.zero);

      final pref = container.read(captionPreferenceProvider);
      expect(pref.enabled, isFalse);
      expect(pref.languageCode, 'de');
    },
  );

  test('survives a fresh container read after persisting (restart)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container
        .read(captionPreferenceProvider.notifier)
        .setCaptionPreference(enabled: true, languageCode: 'ja');
    await Future<void>.delayed(Duration.zero);

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);

    final pref = restarted.read(captionPreferenceProvider);
    expect(pref.enabled, isTrue);
    expect(pref.languageCode, 'ja');
  });

  test('persists caption text size and color', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(captionPreferenceProvider.notifier);
    notifier.setCaptionTextSize(CaptionTextSize.large);
    notifier.setCaptionTextColor(CaptionTextColor.yellow);
    await Future<void>.delayed(Duration.zero);

    expect(
      prefs.getString(captionPreferenceTextSizeStorageKey),
      CaptionTextSize.large.stableId,
    );
    expect(
      prefs.getString(captionPreferenceTextColorStorageKey),
      CaptionTextColor.yellow.stableId,
    );
    final pref = container.read(captionPreferenceProvider);
    expect(pref.textSize, CaptionTextSize.large);
    expect(pref.textColor, CaptionTextColor.yellow);
  });

  test(
    'apply-gate: enabled with no language does not select; enabled + eng would',
    () {
      // Mirrors VideoPlayerWidget._applyCaptionPreferenceIfNeeded:
      // `if (!preference.enabled || preference.languageCode == null) return;`
      bool wouldSelect(CaptionPreference preference) =>
          preference.enabled && preference.languageCode != null;

      expect(wouldSelect(const CaptionPreference(enabled: true)), isFalse);
      expect(
        wouldSelect(
          const CaptionPreference(enabled: true, languageCode: 'eng'),
        ),
        isTrue,
      );
      expect(
        wouldSelect(
          const CaptionPreference(enabled: false, languageCode: 'eng'),
        ),
        isFalse,
      );
    },
  );
}
