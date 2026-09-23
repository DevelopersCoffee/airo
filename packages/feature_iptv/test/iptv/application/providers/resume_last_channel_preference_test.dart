import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/resume_last_channel_preference.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to enabled when nothing is persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(resumeLastChannelEnabledProvider), isTrue);
  });

  test('loads a persisted false through the shared store', () async {
    SharedPreferences.setMockInitialValues({
      iptvResumeLastChannelEnabledKey: false,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(resumeLastChannelEnabledProvider), isFalse);
  });

  test('setEnabled persists and a new container reads it back', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container
        .read(resumeLastChannelEnabledProvider.notifier)
        .setEnabled(false);

    expect(prefs.getBool(iptvResumeLastChannelEnabledKey), isFalse);

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);
    expect(restarted.read(resumeLastChannelEnabledProvider), isFalse);
  });
}
