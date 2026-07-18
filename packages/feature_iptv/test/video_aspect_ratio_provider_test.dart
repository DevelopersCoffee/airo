import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to contain when nothing is persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(videoAspectRatioProvider),
      AiroPlaybackViewFit.contain,
    );
  });

  test('loads a persisted aspect ratio through the shared store', () async {
    SharedPreferences.setMockInitialValues({
      videoAspectRatioStorageKey: AiroPlaybackViewFit.cover.stableId,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(videoAspectRatioProvider), AiroPlaybackViewFit.cover);
  });

  test('setAspectRatio persists the new value', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container
        .read(videoAspectRatioProvider.notifier)
        .setAspectRatio(AiroPlaybackViewFit.stretch);
    await Future<void>.delayed(Duration.zero);

    expect(
      prefs.getString(videoAspectRatioStorageKey),
      AiroPlaybackViewFit.stretch.stableId,
    );
    expect(
      container.read(videoAspectRatioProvider),
      AiroPlaybackViewFit.stretch,
    );
  });

  test('cycleToNext advances through all fits and wraps around', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(videoAspectRatioProvider.notifier);
    final seen = <AiroPlaybackViewFit>[
      container.read(videoAspectRatioProvider),
    ];
    for (var i = 0; i < AiroPlaybackViewFit.values.length; i++) {
      notifier.cycleToNext();
      seen.add(container.read(videoAspectRatioProvider));
    }

    expect(seen.first, seen.last, reason: 'must wrap back to the start');
    expect(seen.toSet(), AiroPlaybackViewFit.values.toSet());
  });

  test('survives a fresh container read after persisting (restart)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container
        .read(videoAspectRatioProvider.notifier)
        .setAspectRatio(AiroPlaybackViewFit.fill);
    await Future<void>.delayed(Duration.zero);

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);

    expect(restarted.read(videoAspectRatioProvider), AiroPlaybackViewFit.fill);
  });
}
