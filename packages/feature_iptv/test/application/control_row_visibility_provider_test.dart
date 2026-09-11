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
      'iptv_row_filter_visible': false,
      'iptv_row_hotbar_visible': false,
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    final visibility = container.read(controlRowVisibilityProvider);
    expect(visibility.isVisible(AiroTvControlRow.filter), isFalse);
    expect(visibility.isVisible(AiroTvControlRow.hotbar), isFalse);
    expect(visibility.isVisible(AiroTvControlRow.playlist), isTrue);
  });

  test('the retired channel row leaves no enum value or stored key behind', () {
    // The LIVE strip became ChannelNameOverlay (a transient badge on the
    // video stage), so there is no row left for a toggle to hide. A stale
    // `iptv_row_channel_visible` from an older install is ignored rather
    // than migrated: _load only reads keys derived from live enum values.
    expect(
      AiroTvControlRow.values.map((row) => row.storageName),
      isNot(contains('channel')),
    );
    expect(
      AiroTvControlRow.values.map((row) => row.label),
      isNot(contains('Channel')),
    );
  });
}
