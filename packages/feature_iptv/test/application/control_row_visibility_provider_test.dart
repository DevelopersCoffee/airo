import 'package:feature_iptv/application/providers/control_row_visibility_provider.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every row but stats defaults visible, and toggles persist with '
      'approved keys', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    final initial = container.read(controlRowVisibilityProvider);
    for (final row in AiroTvControlRow.values) {
      // Stats (codec/resolution/bitrate) is diagnostic detail off by
      // default so it doesn't cost a permanent row for viewers who never
      // open settings to turn it on.
      expect(initial.isVisible(row), row != AiroTvControlRow.stats);
    }

    await container
        .read(controlRowVisibilityProvider.notifier)
        .setVisible(AiroTvControlRow.stats, true);

    expect(preferences.getBool('iptv_row_stats_visible'), isTrue);
  });

  test('stored row values hydrate on provider construction', () async {
    SharedPreferences.setMockInitialValues({
      'iptv_row_channel_visible': false,
      'iptv_row_filter_visible': false,
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    final visibility = container.read(controlRowVisibilityProvider);
    expect(visibility.isVisible(AiroTvControlRow.channel), isFalse);
    expect(visibility.isVisible(AiroTvControlRow.filter), isFalse);
    expect(visibility.isVisible(AiroTvControlRow.playlist), isTrue);
  });
}
