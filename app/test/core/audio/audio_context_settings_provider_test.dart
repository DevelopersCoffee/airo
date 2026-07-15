import 'dart:convert';

import 'package:airo_app/core/audio/audio_context_settings.dart';
import 'package:airo_app/core/audio/audio_context_settings_provider.dart';
import 'package:core_data/core_data.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads audio context settings through guarded store', () async {
    SharedPreferences.setMockInitialValues({
      audioContextSettingsStorageKey: jsonEncode(
        const AudioContextSettings(
          enabled: false,
          duckingLevel: 0.2,
          duckDuringVoiceOutput: false,
        ).toJson(),
      ),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container.read(audioContextSettingsProvider);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(audioContextSettingsProvider);
    expect(state.enabled, isFalse);
    expect(state.duckingLevel, 0.2);
    expect(state.duckDuringVoiceOutput, isFalse);
  });

  test('persists audio context settings through guarded store', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(audioContextSettingsProvider.notifier);
    notifier.setDuckingLevel(0.4);
    await Future<void>.delayed(Duration.zero);

    final raw = prefs.getString(audioContextSettingsStorageKey);
    expect(raw, isNotNull);
    final stored = AudioContextSettings.fromJson(
      jsonDecode(raw!) as Map<String, dynamic>,
    );
    expect(stored.duckingLevel, 0.4);
  });

  test(
    'drops oversized audio context settings before raw persistence',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          audioContextSettingsStoreProvider.overrideWithValue(
            PreferencesStore(prefs, maxValueBytes: 32),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(audioContextSettingsProvider.notifier);
      notifier.setDuckDuringVoiceOutput(false);
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getString(audioContextSettingsStorageKey), isNull);
    },
  );
}
