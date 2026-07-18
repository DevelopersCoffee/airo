import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to standard when nothing is persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(tvFontModeProvider), TvFontMode.standard);
  });

  test('loads a persisted font mode through the shared store', () async {
    SharedPreferences.setMockInitialValues({
      tvFontModeStorageKey: TvFontMode.extraLarge.stableId,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(tvFontModeProvider), TvFontMode.extraLarge);
  });

  test('setTvFontMode persists the new value', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container.read(tvFontModeProvider.notifier).setTvFontMode(TvFontMode.large);
    await Future<void>.delayed(Duration.zero);

    expect(prefs.getString(tvFontModeStorageKey), TvFontMode.large.stableId);
    expect(container.read(tvFontModeProvider), TvFontMode.large);
  });

  test('scale factors increase monotonically with mode', () {
    expect(TvFontMode.standard.scale, lessThan(TvFontMode.large.scale));
    expect(TvFontMode.large.scale, lessThan(TvFontMode.extraLarge.scale));
  });

  test('survives a fresh container read after persisting (restart)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container
        .read(tvFontModeProvider.notifier)
        .setTvFontMode(TvFontMode.extraLarge);
    await Future<void>.delayed(Duration.zero);

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);

    expect(restarted.read(tvFontModeProvider), TvFontMode.extraLarge);
  });
}
