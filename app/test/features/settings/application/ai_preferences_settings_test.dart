import 'package:airo_app/features/settings/application/ai_preferences_settings.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists AI preferences updates', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(aiPreferencesSettingsProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    await notifier.update(
      const AIPreferencesSettings(
        routingStrategy: AIRoutingStrategy.cloudPreferred,
        autoFallback: false,
        accelerationPreference: AIAccelerationPreference.cpuOnly,
        threadCount: 6,
        contextLength: 4096,
        memoryBudgetPercent: 70,
        debugLogging: true,
        downloadLocation: AIDownloadLocationPreference.appManaged,
      ),
    );

    final state = container.read(aiPreferencesSettingsProvider);
    expect(state.routingStrategy, AIRoutingStrategy.cloudPreferred);
    expect(state.autoFallback, isFalse);
    expect(state.accelerationPreference, AIAccelerationPreference.cpuOnly);
    expect(state.threadCount, 6);
    expect(state.contextLength, 4096);
    expect(state.memoryBudgetPercent, 70);
    expect(state.debugLogging, isTrue);
    expect(state.downloadLocation, AIDownloadLocationPreference.appManaged);

    expect(
      prefs.getString(AIPreferencesSettingsNotifier.routingStrategyKey),
      AIRoutingStrategy.cloudPreferred.name,
    );
    expect(
      prefs.getBool(AIPreferencesSettingsNotifier.autoFallbackKey),
      isFalse,
    );
    expect(
      prefs.getString(AIPreferencesSettingsNotifier.accelerationKey),
      AIAccelerationPreference.cpuOnly.name,
    );
    expect(prefs.getInt(AIPreferencesSettingsNotifier.threadCountKey), 6);
    expect(prefs.getInt(AIPreferencesSettingsNotifier.contextLengthKey), 4096);
    expect(prefs.getInt(AIPreferencesSettingsNotifier.memoryBudgetKey), 70);
    expect(
      prefs.getBool(AIPreferencesSettingsNotifier.debugLoggingKey),
      isTrue,
    );
    expect(
      prefs.getString(AIPreferencesSettingsNotifier.downloadLocationKey),
      AIDownloadLocationPreference.appManaged.name,
    );
  });
}
