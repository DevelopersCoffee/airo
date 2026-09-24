import 'package:feature_iptv/application/providers/audio_preference_provider.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to no preferred language when nothing is persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(audioPreferenceProvider), isNull);
  });

  test('loads a persisted audio language through the shared store', () async {
    SharedPreferences.setMockInitialValues({
      audioPreferenceLanguageStorageKey: 'de',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(audioPreferenceProvider), 'de');
  });

  test('setPreferredLanguage persists language code', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container
        .read(audioPreferenceProvider.notifier)
        .setPreferredLanguage('spa');
    await Future<void>.delayed(Duration.zero);

    expect(prefs.getString(audioPreferenceLanguageStorageKey), 'spa');
    expect(container.read(audioPreferenceProvider), 'spa');
  });

  test('survives a fresh container read after persisting (restart)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container.read(audioPreferenceProvider.notifier).setPreferredLanguage('ja');
    await Future<void>.delayed(Duration.zero);

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);

    expect(restarted.read(audioPreferenceProvider), 'ja');
  });
}
