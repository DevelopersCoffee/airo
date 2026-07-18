import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to an empty list of extra sections', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(playbackSettingsExtraSectionsProvider), isEmpty);
  });

  test('can be overridden to inject additional widgets', () {
    const extra = SizedBox(key: ValueKey('pip-toggle'));
    final container = ProviderContainer(
      overrides: [
        playbackSettingsExtraSectionsProvider.overrideWithValue(const [extra]),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(playbackSettingsExtraSectionsProvider), [extra]);
  });
}
