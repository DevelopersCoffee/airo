import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  test('railsProvider builds rails from channels + favorites', () async {
    const ch = IPTVChannel(id: 'x', name: 'X', streamUrl: 'u');
    final container = ProviderContainer(
      overrides: [
        iptvChannelsProvider.overrideWith((ref) async => [ch]),
        favoriteChannelsProvider.overrideWith(
          (ref) async => <IPTVChannel>[],
        ),
      ],
    );
    addTearDown(container.dispose);
    final rails = await container.read(railsProvider.future);
    expect(rails, isNotEmpty);
    expect(rails.first.definition.id, 'top-india');
    expect(rails.first.channels, contains(ch));
  });

  test('rails still build when favorites provider throws', () async {
    const ch = IPTVChannel(id: 'x', name: 'X', streamUrl: 'u');
    final container = ProviderContainer(
      overrides: [
        iptvChannelsProvider.overrideWith((ref) async => [ch]),
        favoriteChannelsProvider.overrideWith(
          (ref) async => throw StateError('storage corrupt'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final rails = await container.read(railsProvider.future);
    expect(rails, isNotEmpty);
  });
}
